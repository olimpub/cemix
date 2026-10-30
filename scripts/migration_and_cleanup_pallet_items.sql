-- ==============================================================================
-- Cemix - Raklap kód és Tétel Duplikáció Ellenőrző / Tisztító Script
-- Dátum: 2026-10-21
-- ==============================================================================

USE [Middleware_dev]; -- vagy az éles adatbázis neve
GO

-- 1. Új S/4HANA raklapkód felvétele az X-Ref táblába (ha még nem szerepel)
IF NOT EXISTS (SELECT 1 FROM tblXrefExceptions WHERE ExType = 'PalletItemCode' AND ExValue = '80000036')
BEGIN
    INSERT INTO tblXrefExceptions (ExType, ExValue) VALUES ('PalletItemCode', '80000036');
    PRINT 'PalletItemCode 80000036 hozzaadva a tblXrefExceptions tablahoz.';
END
ELSE
BEGIN
    PRINT 'PalletItemCode 80000036 mar letezik a tblXrefExceptions tablaban.';
END
GO

IF NOT EXISTS (SELECT 1 FROM tblXrefExceptions WHERE ExType = 'PalletItemCode' AND ExValue = 'K00890000')
BEGIN
    INSERT INTO tblXrefExceptions (ExType, ExValue) VALUES ('PalletItemCode', 'K00890000');
    PRINT 'PalletItemCode K00890000 hozzaadva a tblXrefExceptions tablahoz.';
END
GO

-- 2. DIAGNOSZTIKA: Nyitott / aktív fuvarmegbízások ellenőrzése tételduplikációra
SELECT 
    tci.TransportID, 
    tci.DeliveryNo, 
    tci.ItemCode, 
    COUNT(*) AS DuplicateCount,
    STRING_AGG(tci.ItemNo, ', ') AS ItemNumbers,
    STRING_AGG(
        CASE 
            WHEN LTRIM(RTRIM(ISNULL(tci.Comment, ''))) = '' THEN 'No Batch(' + FORMAT(tci.Qty, '0.###') + ')'
            ELSE LTRIM(RTRIM(tci.Comment)) + '(' + FORMAT(tci.Qty, '0.###') + ')'
        END, 
        ', '
    ) AS AggregatedBatches,
    STRING_AGG(ISNULL(tci.SourceGLABsID, 'NO_GLABS'), ', ') AS GLABsIDs,
    STRING_AGG(CAST(tci.SourceStatus AS VARCHAR(10)), ', ') AS SourceStatuses,
    SUM(tci.Qty) AS TotalSumQty
FROM tblCargoItem tci
INNER JOIN tblTransport tt ON tt.TransportNo = tci.TransportID
WHERE tt.Status < 3 -- Nyitott, folyamatban lévő szállítások
  AND ISNULL(tci.SourceStatus, 0) <> -1
GROUP BY tci.TransportID, tci.DeliveryNo, tci.ItemCode
HAVING COUNT(*) > 1;
GO

-- 3. OPCIONÁLIS KONSZOLIDÁCIÓ (ha a fenti lekérdezés duplikációkat talál nyitott fuvaroknál):
-- Figyelem: Csak akkor futtasd, ha a 2. pontban látsz aktív duplikációkat!
/*
BEGIN TRANSACTION;

-- A) A megtartandó (rn = 1) sor frissítése az összesített mennyiséggel, súllyal és összefűzött Batch(mennyiség) megjegyzéssel
;WITH Ranked AS (
    SELECT 
        id, TransportID, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
        ROW_NUMBER() OVER(
            PARTITION BY TransportID, DeliveryNo, ItemCode 
            ORDER BY 
                CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
                CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
                id ASC
        ) AS rn,
        COUNT(*) OVER(PARTITION BY TransportID, DeliveryNo, ItemCode) AS cnt
    FROM tblCargoItem
    WHERE TransportID IN (SELECT TransportNo FROM tblTransport WHERE Status < 3)
      AND ISNULL(SourceStatus, 0) <> -1
),
Agg AS (
    SELECT 
        tci.TransportID,
        tci.DeliveryNo,
        tci.ItemCode,
        SUM(tci.Qty) AS SumQty,
        SUM(ISNULL(tci.NetWeight, 0)) AS SumNetWeight,
        SUM(ISNULL(tci.GrossWeight, 0)) AS SumGrossWeight,
        MAX(CASE WHEN tci.BatchFlg = 1 OR LTRIM(RTRIM(ISNULL(tci.Comment, ''))) <> '' THEN 1 ELSE 0 END) AS MaxBatchFlg,
        CASE 
            WHEN MAX(CASE WHEN tci.BatchFlg = 1 OR LTRIM(RTRIM(ISNULL(tci.Comment, ''))) <> '' THEN 1 ELSE 0 END) = 1 THEN
                ISNULL(
                    STUFF((
                        SELECT ', ' + b.BatchName + '(' + FORMAT(b.BatchQty, '0.###') + ')'
                        FROM (
                            SELECT 
                                CASE 
                                    WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 'No Batch'
                                    ELSE LTRIM(RTRIM(c.Comment))
                                END AS BatchName,
                                SUM(c.Qty) AS BatchQty,
                                CASE WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 1 ELSE 0 END AS IsNoBatch,
                                MIN(c.ItemNo) AS MinSubItemNo
                            FROM tblCargoItem c
                            WHERE c.TransportID = tci.TransportID
                              AND c.DeliveryNo = tci.DeliveryNo
                              AND c.ItemCode = tci.ItemCode
                              AND ISNULL(c.SourceStatus, 0) <> -1
                              AND c.Qty > 0
                            GROUP BY 
                                CASE 
                                    WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 'No Batch'
                                    ELSE LTRIM(RTRIM(c.Comment))
                                END,
                                CASE WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 1 ELSE 0 END
                        ) b
                        ORDER BY b.IsNoBatch ASC, b.MinSubItemNo ASC
                        FOR XML PATH(''), TYPE
                    ).value('.', 'NVARCHAR(MAX)'), 1, 2, ''),
                    ''
                )
            ELSE ''
        END AS AggComment
    FROM tblCargoItem tci
    WHERE tci.TransportID IN (SELECT TransportNo FROM tblTransport WHERE Status < 3)
      AND ISNULL(tci.SourceStatus, 0) <> -1
    GROUP BY tci.TransportID, tci.DeliveryNo, tci.ItemCode
    HAVING COUNT(*) > 1
)
UPDATE tci
SET tci.Qty = a.SumQty,
    tci.NetWeight = a.SumNetWeight,
    tci.GrossWeight = a.SumGrossWeight,
    tci.BatchFlg = a.MaxBatchFlg,
    tci.Comment = a.AggComment,
    tci.SourceStatus = 0,
    tci.DestinationStatus = 0
FROM tblCargoItem tci
INNER JOIN Ranked r ON r.id = tci.id AND r.rn = 1 AND r.cnt > 1
INNER JOIN Agg a ON a.TransportID = tci.TransportID AND a.DeliveryNo = tci.DeliveryNo AND a.ItemCode = tci.ItemCode;

-- B) A GLABs-hez még fel nem küldött árva másodlagos rekordok törlése
;WITH Dups AS (
    SELECT 
        id, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
        ROW_NUMBER() OVER(
            PARTITION BY TransportID, DeliveryNo, ItemCode 
            ORDER BY 
                CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
                CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
                id ASC
        ) AS rn
    FROM tblCargoItem
    WHERE TransportID IN (SELECT TransportNo FROM tblTransport WHERE Status < 3)
      AND ISNULL(SourceStatus, 0) <> -1
)
DELETE FROM tblCargoItem
WHERE id IN (
    SELECT id FROM Dups WHERE rn > 1 AND SourceGLABsID IS NULL
);

-- C) A GLABs-ben már létező, de másodlagos/felesleges sorok törlésre jelölése
;WITH Dups AS (
    SELECT 
        id, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
        ROW_NUMBER() OVER(
            PARTITION BY TransportID, DeliveryNo, ItemCode 
            ORDER BY 
                CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
                CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
                id ASC
        ) AS rn
    FROM tblCargoItem
    WHERE TransportID IN (SELECT TransportNo FROM tblTransport WHERE Status < 3)
      AND ISNULL(SourceStatus, 0) <> -1
)
UPDATE tci
SET tci.SourceStatus = -1, tci.DestinationStatus = -1
FROM tblCargoItem tci
INNER JOIN Dups d ON d.id = tci.id
WHERE d.rn > 1 AND tci.SourceGLABsID IS NOT NULL AND tci.SourceStatus NOT IN (-1, 3);

COMMIT TRANSACTION;
*/
