/****** Object:  StoredProcedure [dbo].[spLoadTransportToMWv234]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








CREATE PROCEDURE [dbo].[spLoadTransportToMWv234](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
/*
Version 1.09

1.01	:		Changed by Daniel Bakos, add SAPTemplateID to tblShipment on 2023/02/19
1.02	:		Changed by Daniel Bakos, add PalletGrouping logic on 2023/12/12
1.03	:		Changed by Daniel Bakos, to fix PalletGrouping logic not use TOP 1 on 2024/02/23
1.04	:		Changed by Daniel Bakos, fix merge transport addition, if transport is not loaded tt GLABs yet on 2025/02/09
1.05	:		Changed by Daniel Bakos, same itemno but different item code fix yet on 2025/03/25
1.06	:		Changed by Daniel Bakos, new version of pallet grouping logic 2025/05/16
1.07	:		Changed by Daniel Bakos, intercompany unload sap write back logic implementation 2026/01/14
1.08	:		Changed by Daniel Bakos, add BatchNo 2026/04/28
1.09	:		Changed by Daniel Bakos, change intercompany shipment rule logic on 2026/05/05
1.10	:		Changed by Antigravity AI, aggregate items by DeliveryNo and ItemCode, reuse existing ItemNo on update or generate synthetic stepped ItemNo for new items, update pallet code to 80000036 on 2026/10/15
*/
AS
BEGIN

DECLARE @Msg NVARCHAR(MAX), @SourceFlg BIT, @TransportNo VARCHAR(30),@InterCompanyCnt INT
SET @SourceFlg=NULL

IF EXISTS(SELECT * FROM [dbo].[tblTransferTransport] ttd 
	WHERE ttd.TransferID=@TransferID)
BEGIN
	SET @SourceFlg=1
END
ELSE
BEGIN 
	IF EXISTS(SELECT * FROM [dbo].[tblTransferTransportArchive] ttd 
	WHERE ttd.TransferID=@TransferID)
	BEGIN
		SET @SourceFlg=0
	END
END



IF(@SourceFlg IS NULL)
BEGIN
	SET @SuccessFlg=0
	RETURN;
END



BEGIN TRY
 --Define Intercompany logic
DECLARE @Intercompany TABLE(
	PartnerCode VARCHAR(50),
	SiteCode VARCHAR(10)
)
IF(@SourceFlg=1)
BEGIN
	INSERT INTO @Intercompany(PartnerCode)
	SELECT ts.PartnerCodeFrom FROM tblTransferTransportStage ts
	WHERE ts.TransferID=@TransferID
	UNION
	SELECT ts.PartnerCodeTo FROM tblTransferTransportStage ts
	WHERE ts.TransferID=@TransferID
END
ELSE
BEGIN
	INSERT INTO @Intercompany(PartnerCode)
	SELECT ts.PartnerCodeFrom FROM tblTransferTransportStageArchive ts
	WHERE ts.TransferID=@TransferID
	UNION
	SELECT ts.PartnerCodeTo FROM tblTransferTransportStageArchive ts
	WHERE ts.TransferID=@TransferID
END


UPDATE s
SET s.SiteCode=cp.SiteCode
FROM @Intercompany s INNER JOIN tblClientParams cp
ON s.PartnerCode=cp.SiteCode

UPDATE s
SET s.SiteCode=cp.SiteCode
FROM @Intercompany s INNER JOIN tblClientParams cp
ON s.PartnerCode=cp.WHCode
WHERE s.SiteCode IS NULL

SELECT @InterCompanyCnt=COUNT(DISTINCT SiteCode) FROm @Intercompany

DECLARE @tblTransport TABLE(
	[TransportNo] [varchar](100) NOT NULL,
	[GLABsID] [varchar](50) NULL,
	[CarrierID] [varchar](50) NULL,
	[SelfOrganized] [bit] NULL,
	[SiteCode] [varchar](10) NULL,
	[LicensePlate1] [varchar](20) NULL,
	[LicensePlate2] [varchar](20) NULL,
	[DelegateFlg] [bit] NULL,
	[DriverName] [nvarchar](200) NULL,
	[DriverPhone] [varchar](60) NULL,
	[OrganizerID] [varchar](50) NULL,
	[MergeTransportNo] [varchar](100) NULL

)
	IF(@SourceFlg=1)
	BEGIN
		INSERT INTO @tblTransport(
				[TransportNo],
				[CarrierID], 
				[SelfOrganized],
				[SiteCode],
				[LicensePlate1],
				[LicensePlate2],
				[DelegateFlg],
				[DriverName],
				[DriverPhone],
				[OrganizerID],
				[MergeTransportNo]
		)
		SELECT 
				ttd.TransportNo, --TransportNo
				[dbo].[fnGetCarrierCode](ttd.CarrierCode,ttd.PlantCode), --CarrierID
				[dbo].[fnGetShipmentOrganizer](ttd.ShipmentType),  --SelfOrganized
				ttd.PlantCode, --SiteCode
				[dbo].[fnCleanLicensePlate](ttd.LicensePlate1),
				[dbo].[fnCleanLicensePlate](ttd.LicensePlate2),
				NULL, --DelegateFlg
				ttd.DriverName, --DriverName
				ttd.DriverPhone, --DriverPhone
				[dbo].[fnGetCarrierCode](ttd.OrganizerCode,ttd.PlantCode), --OrganizerID
				ttd.TransportNo2 --CASE WHEN LEFT(ttd.TransportNo2,2)='00' THEN ttd.TransportNo2 ELSE '00'+ttd.TransportNo2 END --MergeTransportNo
		FROM [dbo].[tblTransferTransport] ttd 
		WHERE ttd.TransferID=@TransferID
	END
	ELSE
	BEGIN
			INSERT INTO @tblTransport(
			[TransportNo],
			[CarrierID], 
			[SelfOrganized],
			[SiteCode],
			[LicensePlate1],
			[LicensePlate2],
			[DelegateFlg],
			[DriverPhone],
			[OrganizerID],
			[MergeTransportNo]
			)
			SELECT 
				ttd.TransportNo, --TransportNo
				[dbo].[fnGetCarrierCode](ttd.CarrierCode,ttd.PlantCode), --CarrierID
				[dbo].[fnGetShipmentOrganizer](ttd.ShipmentType),  --SelfOrganized
				ttd.PlantCode, --SiteCode
				[dbo].[fnCleanLicensePlate](ttd.LicensePlate1),
				[dbo].[fnCleanLicensePlate](ttd.LicensePlate2),
				NULL, --DelegateFlg
				NULL, --DriverPhone
				[dbo].[fnGetCarrierCode](ttd.OrganizerCode,ttd.PlantCode), --OrganizerID
				ttd.TransportNo2 --   CASE WHEN LEFT(ttd.TransportNo2,2)='00' THEN ttd.TransportNo2 ELSE '00'+ttd.TransportNo2 END --MergeTransportNo
			FROM [dbo].[tblTransferTransportArchive] ttd 
			WHERE ttd.TransferID=@TransferID
	END
	--Load to table variable
	DECLARE @tblShipment TABLE(
	[TransportID] [varchar](100) NOT NULL,
	[Priority] [varchar](50) NULL,
	[ShipmentRule] [varchar] (50) NULL,  --Needs for included
	[PickupDate] [varchar] (20) NULL,
	[SiteCode] [varchar] (10) NULL,
	[SAPTemplateID] [int] NULL
	) 

	DECLARE @Sites TABLE(
		SiteCode VARCHAR(10) 
	)
	IF(@SourceFlg=1)
	BEGIN
		INSERT INTO @Sites
		SELECT 
			DISTINCT ttd.SiteID	
		FROM [dbo].[tblTransferTransportDelivery] ttd 
			WHERE ttd.TransferID=@TransferID
		UNION
		SELECT 
			ISNULL(tc.SiteCode,tc2.SiteCode)
		FROm [dbo].[tblTransferTransportDelivery] ttd 
		LEFT OUTER JOIN tblClientParams tc ON tc.SiteCode=ttd.PartnerCode AND tc.ActiveFlg=1
		LEFT OUTER JOIN tblClientParams tc2 ON tc2.WHCode=ttd.PartnerCode AND  tc2.ActiveFlg=1
			WHERE ttd.TransferID=@TransferID

		INSERT INTO @tblShipment(
			TransportID,
			Priority,
			ShipmentRule,
			PickupDate,
			SiteCode,
			SAPTemplateID
		)
		SELECT 
			ttt.TransportNo,
			[dbo].[fnGetServiceLevel](ttt.[Priority],ss.SiteCode),
			CASE WHEN @InterCompanyCnt>1 THEN [dbo].[fnGetIntercompanyShipmentRule](ttt.ShipmentType,SiteCode) ELSE [dbo].[fnGetShipmentRule](ttt.ShipmentType,SiteCode) END,
			[dbo].[fnGetLatestPickupDate](@TransferID,SiteCode),
			ss.SiteCode,
			CASE WHEN @InterCompanyCnt>1 AND ttt.[PlantCode]= ss.SiteCode THEN  [dbo].[fnGetSAPTemplateID](ttt.ShipmentType,SiteCode)
				 WHEN @InterCompanyCnt>1 AND ttt.[PlantCode]<> ss.SiteCode THEN  (SELECT sst.id FROM [dbo].[tblShipmentStatusTemplate] sst WHERE sst.InterCompanyUnloadFlg=1)
				 ELSE [dbo].[fnGetSAPTemplateID](ttt.ShipmentType,SiteCode)
				 END
		FROM tblTransferTransport ttt 
		CROSS APPLY @Sites ss
		WHERE ttt.TransferID=@TransferID AND ss.SiteCode IS NOT NULL
	END
	ELSE
	BEGIN
		INSERT INTO @Sites
		SELECT 
			DISTINCT ttd.SiteID	
		FROM [dbo].[tblTransferTransportDeliveryArchive] ttd 
			WHERE ttd.TransferID=@TransferID
		UNION
		SELECT 
			ISNULL(tc.SiteCode,tc2.SiteCode)
		FROm [dbo].[tblTransferTransportDeliveryArchive] ttd 
		LEFT OUTER JOIN tblClientParams tc ON tc.SiteCode=ttd.PartnerCode AND tc.ActiveFlg=1
		LEFT OUTER JOIN tblClientParams tc2 ON tc2.WHCode=ttd.PartnerCode AND  tc2.ActiveFlg=1
			WHERE ttd.TransferID=@TransferID

		INSERT INTO @tblShipment(
			TransportID,
			Priority,
			ShipmentRule,
			PickupDate,
			SiteCode,
			SAPTemplateID
		)		
		SELECT 
			ttt.TransportNo,
			[dbo].[fnGetServiceLevel](ttt.[Priority],ss.SiteCode),
			CASE WHEN @InterCompanyCnt>1 THEN [dbo].[fnGetIntercompanyShipmentRule](ttt.ShipmentType,SiteCode) ELSE [dbo].[fnGetShipmentRule](ttt.ShipmentType,SiteCode) END,
			[dbo].[fnGetLatestPickupDate](@TransferID,SiteCode),
			ss.SiteCode,
			CASE WHEN @InterCompanyCnt>1 AND ttt.[PlantCode]= ss.SiteCode THEN  [dbo].[fnGetSAPTemplateID](ttt.ShipmentType,SiteCode)
				 WHEN @InterCompanyCnt>1 AND ttt.[PlantCode]<> ss.SiteCode THEN  (SELECT sst.id FROM [dbo].[tblShipmentStatusTemplate] sst WHERE sst.InterCompanyUnloadFlg=1)
				 ELSE [dbo].[fnGetSAPTemplateID](ttt.ShipmentType,SiteCode)
				 END
		FROM tblTransferTransportArchive ttt 
		CROSS APPLY @Sites ss
		WHERE ttt.TransferID=@TransferID AND ss.SiteCode IS NOT NULL
	END

		DECLARE @tblCargo TABLE(
		[DeliveryNo] [varchar](100) NOT NULL,
		[Weight] [numeric](12,2) NOT NULL,
		[Colli] [smallint] NOT NULL,
		[Comment] [nvarchar](500) NULL,
		[DeliveryDate] [varchar](20),
		[PickupDate] [varchar](20),
		[SourceSideCode] [varchar](15),
		[SourcePartnerID] [varchar](50),
		[DestinationSideCode] [varchar](15),
		[DestinationPartnerID] [varchar](50),
		[ContactInfo] [nvarchar](300) NULL,
		[ContactPhone] [varchar](500) NULL,
		[Direction] [bit] NULL,
		[StageNo] [nvarchar](300) NULL
		)
		/*
		SELECT
			ttd.DeliveryNo,
			ttd.Weight,
			0, --Caluclate later on
			ttd.Comment,
			[dbo].[fnConvertToDate](ttd.DeliveryDate),
			[dbo].[fnConvertToDatetime](ttd.PickupDate),
			CASE ttd.Direction WHEN 1 THEN ttd.SiteID ELSE [dbo].[fnGetSiteCode](ttd.PartnerCode) END,
			CASE ttd.Direction WHEN 1 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			CASE ttd.Direction WHEN 0 THEN ttd.SiteID ELSE [dbo].[fnGetSiteCode](ttd.PartnerCode) END,
			CASE ttd.Direction WHEN 0 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			ttd.ContactInfo,
			ttd.PartnerPhone,
			ttd.Direction,
			ttd.StageNo
		FROM tblTransferTransportDelivery ttd 
		INNER JOIN tblTransferTransport tt ON tt.TransferID=ttd.TransferID
		WHERE ttd.TransferID=@TransferID
		*/

	IF(@SourceFlg=1)
	BEGIN
		INSERT INTO @tblCargo(
			[DeliveryNo],
			[Weight],
			[Colli],
			[Comment],
			[DeliveryDate],
			[PickupDate],
			[SourceSideCode],
			[SourcePartnerID],
			[DestinationSideCode],
			[DestinationPartnerID],
			[ContactInfo],
			[ContactPhone],
			[Direction],
			[StageNo]
		)
		SELECT
			ttd.DeliveryNo,
			ttd.Weight,
			0, --Caluclate later on
			ttd.Comment,
			[dbo].[fnConvertToDate](ttd.DeliveryDate),
			[dbo].[fnConvertToDatetime](ttd.PickupDate),
			CASE ttd.Direction WHEN 1 THEN ttd.SiteID ELSE [dbo].[fnGetSiteCode](ttd.PartnerCode) END,
			CASE ttd.Direction WHEN 1 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			CASE ttd.Direction WHEN 0 THEN ttd.SiteID ELSE [dbo].[fnGetSiteCode](ttd.PartnerCode) END,
			CASE ttd.Direction WHEN 0 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			ttd.ContactInfo,
			ttd.PartnerPhone,
			ttd.Direction,
			ttd.StageNo
		FROM tblTransferTransportDelivery ttd 
		INNER JOIN tblTransferTransport tt ON tt.TransferID=ttd.TransferID
		WHERE ttd.TransferID=@TransferID
	END
	ELSE 
	BEGIN
		INSERT INTO @tblCargo(
			[DeliveryNo],
			[Weight],
			[Colli],
			[Comment],
			[DeliveryDate],
			[PickupDate],
			[SourceSideCode],
			[SourcePartnerID],
			[DestinationSideCode],
			[DestinationPartnerID],
			[ContactInfo],
			[ContactPhone],
			[Direction],
			[StageNo]
		)
		SELECT
			ttd.DeliveryNo,
			ttd.Weight,
			0, --Caluclate later on
			ttd.Comment,
			[dbo].[fnConvertToDate](ttd.DeliveryDate),
			[dbo].[fnConvertToDatetime](ttd.PickupDate),
			ttd.SiteID,
			CASE ttd.Direction WHEN 1 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			[dbo].[fnGetSiteCode](ttd.PartnerCode),
			CASE ttd.Direction WHEN 0 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			ttd.ContactInfo,
			ttd.PartnerPhone,
			ttd.Direction,
			ttd.StageNo
		FROM tblTransferTransportDeliveryArchive ttd 
		INNER JOIN tblTransferTransportArchive tt ON tt.TransferID=ttd.TransferID
		WHERE ttd.TransferID=@TransferID
	END

	--Just because of Pallet logic
	UPDATE @tblCargo
	SET DestinationSideCode=CASE Direction WHEN 0 THEN DestinationSideCode ELSE NULL END,
	SourceSideCode=CASE Direction WHEN 1 THEN SourceSideCode ELSE NULL END
	WHERE SourceSideCode=DestinationSideCode


	DECLARE @TransportID VARCHAR(50)
	SELECT TOP 1 @TransportID = TransportNo FROM @tblTransport

	-- Deduplicate existing tblCargoItem records if any duplicates exist for this transport
	;WITH Dups AS (
		SELECT 
			id, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
			ROW_NUMBER() OVER(
				PARTITION BY DeliveryNo, ItemCode 
				ORDER BY 
					CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
					CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
					id ASC
			) AS rn
		FROM tblCargoItem
		WHERE TransportID = @TransportID
	)
	DELETE FROM tblCargoItem
	WHERE id IN (
		SELECT id FROM Dups WHERE rn > 1 AND SourceGLABsID IS NULL
	);

	;WITH Dups AS (
		SELECT 
			id, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
			ROW_NUMBER() OVER(
				PARTITION BY DeliveryNo, ItemCode 
				ORDER BY 
					CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
					CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
					id ASC
			) AS rn
		FROM tblCargoItem
		WHERE TransportID = @TransportID
	)
	UPDATE tci
	SET tci.SourceStatus = -1, tci.DestinationStatus = -1
	FROM tblCargoItem tci
	INNER JOIN Dups d ON d.id = tci.id
	WHERE d.rn > 1 AND tci.SourceGLABsID IS NOT NULL AND tci.SourceStatus NOT IN (-1, 3);

	DECLARE @tblCargoItem TABLE(
		[DeliveryNo] [varchar](100) NOT NULL,
		[ItemNo] [varchar](10) NOT NULL,
		[ItemCode] [nvarchar](50) NOT NULL,
		[ItemName] [nvarchar](300) NOT NULL,
		[OrderNo] [varchar](100) NOT NULL,
		[Qty] [numeric](9,3) NOT NULL,
		[QtyUnit] [varchar](10) NOT NULL,
		[QtyUnitID] [varchar](50) NOT NULL,
		[PalletQty] [numeric](9,3) NULL,
		[PickingFlg] [bit] NULL,
		[Comment] [nvarchar](500)  NULL,
		[StockQty] [numeric](9,3) NULL,
		[NetWeight] [numeric](12,3) NULL,
		[GrossWeight] [numeric](12,3) NULL,
		[CopyFlg] [bit] NULL,
		[BatchFlg] [bit] NULL
	)

	DECLARE @tblCargoItemCopy TABLE(
		[DeliveryNo] [varchar](100) NOT NULL,
		[OldDeliveryNo] [varchar](100) NOT NULL,
		[ItemNo] [varchar](10) NOT NULL,
		[ItemCode] [nvarchar](50) NOT NULL,
		[ItemName] [nvarchar](300) NOT NULL,
		[OrderNo] [varchar](100) NOT NULL,
		[Qty] [numeric](9,3) NOT NULL,
		[QtyUnit] [varchar](10) NOT NULL,
		[QtyUnitID] [varchar](50) NOT NULL,
		[PalletQty] [numeric](9,3) NULL,
		[PickingFlg] [bit] NULL,
		[Comment] [nvarchar](500)  NULL,
		[StockQty] [numeric](9,3) NULL,
		[NetWeight] [numeric](12,3) NULL,
		[GrossWeight] [numeric](12,3) NULL,
		[CopyFlg] [bit] NULL,
		[BatchFlg] [bit] NULL
	)

	DECLARE @AggregatedDeliveryItems TABLE (
		[DeliveryNo] [varchar](100) NOT NULL,
		[ItemCode] [nvarchar](50) NOT NULL,
		[ItemName] [nvarchar](300) NOT NULL,
		[OrderNo] [varchar](100) NOT NULL,
		[Qty] [numeric](9,3) NOT NULL,
		[QtyUnit] [varchar](10) NOT NULL,
		[PalletQty] [numeric](9,3) NULL,
		[StockQty] [numeric](9,3) NULL,
		[NetWeight] [numeric](12,3) NULL,
		[GrossWeight] [numeric](12,3) NULL,
		[BatchFlg] [bit] NULL,
		[Comment] [nvarchar](500) NULL,
		[MinItemNo] [varchar](10) NULL
	)

	IF(@SourceFlg=1)
	BEGIN
		INSERT INTO @AggregatedDeliveryItems (
			DeliveryNo, ItemCode, ItemName, OrderNo, Qty, QtyUnit,
			PalletQty, StockQty, NetWeight, GrossWeight, BatchFlg, Comment, MinItemNo
		)
		SELECT 
			tdi.DeliveryNo,
			tdi.ItemCode,
			MAX(tdi.ItemName),
			MIN(tdi.OrderNo),
			SUM(tdi.Qty),
			MAX(tdi.QtyUnit),
			MAX(ISNULL(tdi.PalletQty, tdi.Qty)),
			MAX(ISNULL(tdi.StockQty, 0)),
			SUM(ISNULL(tdi.NetWeight, 0)),
			SUM(ISNULL(tdi.GrossWeight, 0)),
			MAX(CASE WHEN tdi.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(tdi.Comment, ''))) <> '' THEN 1 ELSE 0 END),
			CASE 
				WHEN MAX(CASE WHEN tdi.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(tdi.Comment, ''))) <> '' THEN 1 ELSE 0 END) = 1 THEN
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
								FROM tblTransferTransportDeliveryItem c
								WHERE c.TransferID = @TransferID 
								  AND c.DeliveryNo = tdi.DeliveryNo 
								  AND c.ItemCode = tdi.ItemCode 
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
			END,
			MIN(tdi.ItemNo)
		FROM tblTransferTransportDeliveryItem tdi
		WHERE tdi.TransferID = @TransferID
		  AND tdi.Qty > 0
		GROUP BY tdi.DeliveryNo, tdi.ItemCode
	END
	ELSE
	BEGIN
		INSERT INTO @AggregatedDeliveryItems (
			DeliveryNo, ItemCode, ItemName, OrderNo, Qty, QtyUnit,
			PalletQty, StockQty, NetWeight, GrossWeight, BatchFlg, Comment, MinItemNo
		)
		SELECT 
			tdi.DeliveryNo,
			tdi.ItemCode,
			MAX(tdi.ItemName),
			MIN(tdi.OrderNo),
			SUM(tdi.Qty),
			MAX(tdi.QtyUnit),
			MAX(ISNULL(tdi.PalletQty, tdi.Qty)),
			MAX(ISNULL(tdi.StockQty, 0)),
			SUM(ISNULL(tdi.NetWeight, 0)),
			SUM(ISNULL(tdi.GrossWeight, 0)),
			MAX(CASE WHEN tdi.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(tdi.Comment, ''))) <> '' THEN 1 ELSE 0 END),
			CASE 
				WHEN MAX(CASE WHEN tdi.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(tdi.Comment, ''))) <> '' THEN 1 ELSE 0 END) = 1 THEN
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
								FROM tblTransferTransportDeliveryItemArchive c
								WHERE c.TransferID = @TransferID 
								  AND c.DeliveryNo = tdi.DeliveryNo 
								  AND c.ItemCode = tdi.ItemCode 
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
			END,
			MIN(tdi.ItemNo)
		FROM tblTransferTransportDeliveryItemArchive tdi
		WHERE tdi.TransferID = @TransferID
		  AND tdi.Qty > 0
		GROUP BY tdi.DeliveryNo, tdi.ItemCode
	END

	;WITH ItemMapping AS (
		SELECT 
			adi.DeliveryNo,
			adi.ItemCode,
			adi.ItemName,
			adi.OrderNo,
			adi.Qty,
			adi.QtyUnit,
			adi.PalletQty,
			adi.StockQty,
			adi.NetWeight,
			adi.GrossWeight,
			adi.BatchFlg,
			adi.Comment,
			adi.MinItemNo,
			ExistingItemNo = (
				SELECT TOP 1 tci.ItemNo 
				FROM tblCargoItem tci 
				WHERE tci.DeliveryNo = adi.DeliveryNo 
				  AND tci.ItemCode = adi.ItemCode 
				  AND tci.TransportID = @TransportID
				ORDER BY 
					CASE WHEN tci.SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
					CASE WHEN ISNULL(tci.SourceStatus, 0) NOT IN (-1, 3) THEN 0 ELSE 1 END,
					tci.id ASC
			),
			BaseNo = ISNULL((
				SELECT MAX(TRY_CAST(tci.ItemNo AS INT))
				FROM tblCargoItem tci
				WHERE tci.DeliveryNo = adi.DeliveryNo 
				  AND tci.TransportID = @TransportID
			), 0),
			NewSeq = ROW_NUMBER() OVER(
				PARTITION BY adi.DeliveryNo, 
					CASE WHEN EXISTS (
						SELECT 1 FROM tblCargoItem tci 
						WHERE tci.DeliveryNo = adi.DeliveryNo 
						  AND tci.ItemCode = adi.ItemCode 
						  AND tci.TransportID = @TransportID
					) THEN 0 ELSE 1 END
				ORDER BY adi.MinItemNo
			)
		FROM @AggregatedDeliveryItems adi
	)
	INSERT INTO @tblCargoItem (
		[DeliveryNo], [ItemNo], [ItemCode], [ItemName], [OrderNo],
		[Qty], [QtyUnit], [QtyUnitID], [PalletQty], [PickingFlg],
		[Comment], [StockQty], [NetWeight], [GrossWeight], [CopyFlg], [BatchFlg]
	)
	SELECT 
		m.DeliveryNo,
		CASE 
			WHEN m.ExistingItemNo IS NOT NULL THEN m.ExistingItemNo
			ELSE RIGHT('000000' + CAST(m.BaseNo + (m.NewSeq * 10) AS VARCHAR(10)), 6)
		END AS ItemNo,
		m.ItemCode,
		m.ItemName,
		m.OrderNo,
		m.Qty,
		m.QtyUnit,
		[dbo].[fnGetQtyUnit](m.QtyUnit),
		m.PalletQty,
		CASE 
			WHEN ISNULL(m.PalletQty, 0) = 0 OR CAST(m.Qty AS INT) % CAST(m.PalletQty AS INT) = 0 THEN 0 
			ELSE 1 
		END AS PickingFlg,
		m.Comment,
		m.StockQty,
		m.NetWeight,
		m.GrossWeight,
		0 AS CopyFlg,
		m.BatchFlg
	FROM ItemMapping m;

	--Update Collidata
	UPDATE t
	SET t.Colli=ISNULL((SELECT SUM(CEILING(it.Qty/it.PalletQty)) FROM @tblCargoItem it WHERE it.DeliveryNo=t.DeliveryNo AND ISNULL(it.PalletQty,0)>0),0)
	FROM @tblCargo t

	UPDATE t
	SET t.Colli=1
	FROM @tblCargo t
	WHERE t.Colli=0
	/*
	SELECT * FROm @tblTransport
	SELECT * FROM @tblShipment
	SELECT * FROM @tblCargo
	SELECT * FROM @tblCargoItem
	*/
	SELECT * FROM @tblCargo

	--DECLARE Raklap logic
	DECLARE @PalletLogic TABLE(
		PartnerID VARCHAR(100),
		DeliveryCnt SMALLINT,
		DeliveryNo VARCHAR(50),
		PalletNo INT,
		SrcDeliveryNo VARCHAR(50)
	)

	DECLARE @tmpTransportNo VARCHAR(50)
	SELECT TOP 1 @tmpTransportNo= TransportNo FROM @tblTransport

	INSERT INTO @PalletLogic(PartnerID,DeliveryCnt,DeliveryNo,PalletNo,SrcDeliveryNo)
	SELECT tc.SourcePartnerID,COUNT(DISTINCT tci.DeliveryNo),@tmpTransportNo+LEFT(tc.SourcePartnerID,2)+RIGHT(tc.SourcePartnerID,2),SUM(tci.Qty), MIN(tc.DeliveryNo) 
	FROM @tblCargo tc 
	INNER JOIN @tblCargoItem tci ON tci.DeliveryNo=tc.DeliveryNo
	WHERE (tci.ItemCode IN ('80000036', 'K00890000') OR EXISTS (SELECT 1 FROM tblXrefExceptions xe WHERE xe.ExType = 'PalletItemCode' AND xe.ExValue = tci.ItemCode)) 
	  AND tc.Direction=0
	GROUP BY tc.SourcePartnerID

	DELETE FROM @PalletLogic WHERE DeliveryCnt=1

	--------------------------
	INSERT INTO @tblCargoItemCopy
		(
			[DeliveryNo],
			[OldDeliveryNo],
			[ItemNo],
			[ItemCode],
			[ItemName],
			[OrderNo],
			[Qty],
			[QtyUnit],
			[QtyUnitID],
			[PalletQty],
			[PickingFlg],
			[Comment],
			[StockQty],
			[NetWeight],
			[GrossWeight],
			[CopyFlg],
			[BatchFlg]
		)
	SELECT pl.DeliveryNo, '', '000001', tci.ItemCode, MAX(tci.ItemName), '', pl.PalletNo, MAX(tci.QtyUnit), MAX(tci.QtyUnitID), MAX(tci.PalletQty), MAX(CAST(tci.PickingFlg AS INT)), MAX(tci.Comment), MAX(tci.StockQty), SUM(tci.NetWeight), SUM(tci.GrossWeight), 1, MAX(CAST(tci.BatchFlg AS INT))
	FROM @tblCargo tc 
	INNER JOIN @tblCargoItem tci ON tci.DeliveryNo=tc.DeliveryNo
	INNER JOIN @PalletLogic pl ON pl.PartnerID=tc.SourcePartnerID
	WHERE (tci.ItemCode IN ('80000036', 'K00890000') OR EXISTS (SELECT 1 FROM tblXrefExceptions xe WHERE xe.ExType = 'PalletItemCode' AND xe.ExValue = tci.ItemCode))
	GROUP BY pl.DeliveryNo, tci.ItemCode, pl.PalletNo

	--DELETE All Items(singel Items)
	DELETE tci FROM @tblCargoItem tci 
	INNER JOIN @tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo 
	INNER JOIN @PalletLogic pl ON pl.PartnerID=tc.SourcePartnerID
	WHERE (tci.ItemCode IN ('80000036', 'K00890000') OR EXISTS (SELECT 1 FROM tblXrefExceptions xe WHERE xe.ExType = 'PalletItemCode' AND xe.ExValue = tci.ItemCode))

	INSERT INTO @tblCargoItem
		(
			[DeliveryNo],
			[ItemNo],
			[ItemCode],
			[ItemName],
			[OrderNo],
			[Qty],
			[QtyUnit],
			[QtyUnitID],
			[PalletQty],
			[PickingFlg],
			[Comment],
			[StockQty],
			[NetWeight],
			[GrossWeight],
			[CopyFlg],
			[BatchFlg]
		)
		SELECT 
			[DeliveryNo],
			[ItemNo],
			[ItemCode],
			[ItemName],
			[OrderNo],
			[Qty],
			[QtyUnit],
			[QtyUnitID],
			[PalletQty],
			[PickingFlg],
			[Comment],
			[StockQty],
			[NetWeight],
			[GrossWeight],
			[CopyFlg],
			[BatchFlg]
		FROM @tblCargoItemCopy
		WHERE CopyFlg=1
	
	
	INSERT INTO @tblCargo(
			[DeliveryNo],
			[Weight],
			[Colli],
			[Comment],
			[DeliveryDate],
			[PickupDate],
			[SourceSideCode],
			[SourcePartnerID],
			[DestinationSideCode],
			[DestinationPartnerID],
			[ContactInfo],
			[ContactPhone],
			[Direction],
			[StageNo]
		)
	SELECT 
		tci.DeliveryNo,
		tci.NetWeight,
		tci.Qty,
		'',--Comment
		tcc.DeliveryDate,
		tcc.PickupDate,
		tcc.SourceSideCode, 
		tcc.SourcePartnerID,
		tcc.DestinationSideCode,
		tcc.DestinationPartnerID,
		tcc.ContactInfo,
		tcc.ContactPhone,
		tcc.Direction,
		tcc.StageNo
	FROM @tblCargoItem tci 
		INNER JOIN @PalletLogic pl ON pl.DeliveryNo=tci.DeliveryNo
		INNER JOIN @tblCargo tcc ON tcc.DeliveryNo=pl.SrcDeliveryNo   WHERE NOT EXISTS(
		SELECT * FROM @tblCargo tc WHERE tc.DeliveryNo=tci.DeliveryNo
	)


	------EXCLUD BECAUSE OF S4  UPGRADE!!!
	/*
	DELETE tc FROM @tblCargo tc WHERE NOT EXISTS(
		SELECT * FROM @tblCargoItem tci WHERE tci.DeliveryNo=tc.DeliveryNo)
	*/
	/*
	SELECT * FROM @PalletLogic
	SELECT * FROM @tblCargoItemCopy
	SELECT * FROM @tblCargo
	SELECT * FROM @tblCargoItem
	*/


	--Define Exit points
	SELECT @TransportNo=TransportNo FROm @tblTransport

	--No stage No
	IF EXISTS(SELECT * FROm @tblCargo WHERE StageNo IS NULL)
	BEGIN
		SELECT TOP 1 @Msg='Missing Stage Data ('+DeliveryNo+')' FROm @tblCargo WHERE StageNo IS NULL
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID		
		
		RETURN
	END

	--No Carrier Data
	IF EXISTS(SELECT * FROm @tblTransport WHERE ISNULL(CarrierID,'')='')
	BEGIN
		SET @Msg='Missing Carrier Data'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID

		RETURN
	END

	--No Organizer id SelfOrganized=0
	IF EXISTS(SELECT * FROm @tblTransport WHERE ISNULL(OrganizerID,'')='' AND SelfOrganized=0)
	BEGIN
		SET @Msg='Missing Organizer Data'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID

		RETURN
	END

	DECLARE @MergeTransportNo VARCHAR(30)
	SELECT @MergeTransportNo=ISNULL(MergeTransportNo,'') FROM @tblTransport
	IF(@MergeTransportNo<>'')
	BEGIN
		--Merge Transport No not exists in GLABs
		IF NOT EXISTS(SELECT * FROM tblTransport tt2 WHERE tt2.TransportNo=@MergeTransportNo AND tt2.GLABsID IS NOT NULL)
		BEGIN
			SELECT @Msg='No Active Transport to Merge:'+@MergeTransportNo
			INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
			SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
			SET @SuccessFlg=0
			--SELECT @SuccessFlg,@Msg --Just for testing
			UPDATE tblTransferIn
			SET TransformFlg=0
			WHERE id=@TransferID

			RETURN
		END


		--Check if merge is possible
		IF EXISTS(SELECT * FROm @tblTransport tt WHERE ISNULL(MergeTransportNo,'')<>'' AND EXISTS(SELECT * FROM tblTransport tt2 WHERE tt2.TransportNo=ISNULL(MergeTransportNo,'') AND tt2.GLABsID IS NOT NULL))
		BEGIN
			DECLARE @SiteCodesFrom TABLE(
				SiteCode VARCHAR(15)
			)

			DECLARE @SiteCodesTo TABLE(
				SiteCode VARCHAR(15)
			)

			INSERT INTO @SiteCodesFrom
			SELECT ts.SiteCode FROM @tblShipment ts

			INSERT INTO @SiteCodesTo
			SELECT ts.SiteCode FROM tblShipment ts WHERE ts.TransportID=@MergeTransportNo

			IF EXISTS(SELECT * FROM @SiteCodesFrom sf LEFT OUTER JOIN @SiteCodesTo st ON st.SiteCode=sf.SiteCode WHERE st.SiteCode IS NULL)
			BEGIN
				SELECT TOP 1 @Msg='No Site Code found in Merged transport:'+ sf.SiteCode FROM @SiteCodesFrom sf LEFT OUTER JOIN @SiteCodesTo st ON st.SiteCode=sf.SiteCode WHERE st.SiteCode IS NULL
				INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
				SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
				SET @SuccessFlg=0
				--SELECT @SuccessFlg,@Msg --Just for testing
				UPDATE tblTransferIn
				SET TransformFlg=0
				WHERE id=@TransferID				
				
				RETURN
			END
		END
	END
	--Merge Transport No different, but picking not completed!!!! LATER
	
	--No shipment Rule found
	IF EXISTS(SELECT * FROm @tblShipment WHERE ISNULL(ShipmentRule,'')='')
	BEGIN
		SELECT TOP 1 @Msg='Missing Shipment Rule('+SiteCode+')' FROM @tblShipment WHERE ISNULL(ShipmentRule,'')=''
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		RETURN
	END
	
	--Missing partner id
	IF EXISTS(SELECT * FROm @tblCargo WHERE ISNULL(SourcePartnerID,'')='')
	BEGIN
		SELECT TOP 1 @Msg='Missing Source PartnerID('+DeliveryNo+')' FROm @tblCargo  WHERE ISNULL(SourcePartnerID,'')=''
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID		
		
		RETURN
	END
	
	IF EXISTS(SELECT * FROm @tblCargo WHERE ISNULL(DestinationPartnerID,'')='')
	BEGIN
		SELECT TOP 1 @Msg='Missing Destination PartnerID('+DeliveryNo+')' FROm @tblCargo  WHERE ISNULL(DestinationPartnerID,'')=''
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID		
		
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		RETURN
	END
	
	--No Qty Unit ID
	IF EXISTS(SELECT * FROm @tblCargoItem WHERE ISNULL(QtyUnitID,'')='')
	BEGIN
		SELECT TOP 1 @Msg='Missing Qty Unit Reference('+QtyUnit+')' FROm @tblCargoItem WHERE ISNULL(QtyUnitID,'')=''
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID
		
		RETURN
	END
	
	--Any item level change but locked LATER




	--SELECT @SuccessFlg,@Msg

	
	----LOAD TO DB
	IF EXISTS(SELECT * FROM tblTransport tr INNER JOIN @tblTransport trr ON trr.TransportNo=tr.TransportNo)
	BEGIN
		UPDATE tr
		SET tr.CarrierID=trr.CarrierID, tr.OrganizerID=trr.OrganizerID, tr.DelegateFlg=0
		FROM tblTransport tr INNER JOIN @tblTransport trr ON trr.TransportNo=tr.TransportNo
		AND (tr.OrganizerID<>trr.OrganizerID OR tr.CarrierID<>trr.CarrierID)

		UPDATE tr
		SET tr.Status=CASE WHEN tr.Status=0 THEN 0 ELSE -1 END, tr.MergeTransportNo=trr.MergeTransportNo
		FROM tblTransport tr INNER JOIN @tblTransport trr ON trr.TransportNo=tr.TransportNo
		AND (ISNULL(tr.MergeTransportNo,'')<>ISNULL(trr.MergeTransportNo,''))
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[tblTransport]
				   ([TransportNo]
				   ,[GLABsID]
				   ,[CarrierID]
				   ,[SelfOrganized]
				   ,[SiteCode]
				   ,[LicensePlate1]
				   ,[LicensePlate2]
				   ,[DelegateFlg]
				   ,[DriverName]
				   ,[DriverPhone]
				   ,[OrganizerID]
				   ,[MergeTransportNo]
				   ,[Status])
		SELECT 
			tr.TransportNo,
			NULL,
			tr.CarrierID,
			tr.SelfOrganized,
			tr.SiteCode,
			tr.LicensePlate1,
			tr.LicensePlate2,
			tr.DelegateFlg,
			tr.DriverName,
			tr.DriverPhone,
			tr.OrganizerID,
			tr.MergeTransportNo,
			CASE WHEN tr.MergeTransportNo IS NULL THEN 0 ELSE NULL END --Merge transports should not be transferred
		FROM @tblTransport tr
	END

		--Compare Stations!!!!
	IF EXISTS(SELECT ts.TransportID FROm tblShipment ts INNER JOIN @tblShipment tts ON tts.TransportID=ts.TransportID)
	BEGIN
		UPDATE ts
		SET ts.Priority=ISNULL(tts.Priority,''), ts.Status=0
		FROM tblShipment ts INNER JOIN @tblShipment tts ON tts.TransportID=ts.TransportID
		AND (ISNULL(tts.Priority,'')<>ts.Priority)

		UPDATE ts
		SET ts.PickupDate=tts.PickupDate, ts.Status=0
		FROM tblShipment ts INNER JOIN @tblShipment tts ON tts.TransportID=ts.TransportID
		AND ( ISNULL(tts.PickupDate,GETDATE())<>ISNULL(ts.PickupDate,GETDATE()))
	END
	
	IF EXISTS(SELECT * FROm @tblShipment ts WHERE NOT EXISTS(SELECT * FROm tblShipment tss WHERE tss.TransportID=ts.TransportID AND tss.SiteCode=ts.SiteCode))
	BEGIN
		INSERT INTO [dbo].[tblShipment]
           ([TransportID]
           ,[Priority]
           ,[ShipmentRule]
           ,[PickupDate]
           ,[Status]
           ,[SiteCode]
           ,[DelegateFlg]
		   ,[CheckOutBlock]
		   ,[SAPTemplateID]
		   )
		  SELECT 
			ts.TransportID,
			ISNULL(ts.Priority,''),
			ts.ShipmentRule,
			ts.PickupDate,
			0,---Status
			ts.SiteCode,
			0,--DelegateFlg
			CASE WHEN ISNULL((SELECT TOP 1 txs.AutoBlockFlg FROM tblXrefShipmentRule txs WHERE txs.GLABsID=ts.ShipmentRule),(SELECT TOP 1 txs.AutoBlockFlg FROM tblXrefShipmentRule txs WHERE txs.IntercompanyGLABsID=ts.ShipmentRule))=1 THEN 1 ELSE NULL END,
			ISNULL(ts.SAPTemplateID,(SELECT tst.id FROm tblShipmentStatusTemplate tst WHERE tst.DefaultFlg=1))
		  FROm @tblShipment ts 
		  WHERE NOT EXISTS(SELECT * FROm tblShipment tss WHERE tss.TransportID=ts.TransportID AND tss.SiteCode=ts.SiteCode)
	END

	IF (@TransportID IS NULL)
	BEGIN
		SELECT @TransportID=ts.TransportID FROM @tblShipment ts
	END

	--Update Cargos
	UPDATE tc
	SET tc.Comment=tcc.Comment, tc.ContactInfo=tcc.ContactInfo,/*tc.PickupDate=tcc.PickupDate,*/tc.DeliveryDate=tcc.DeliveryDate,tc.Status=0,tc.Colli=tcc.Colli, tc.StageNo=tcc.StageNo, tc.Weight=tcc.Weight, tc.ContactPhone=tcc.ContactPhone, tc.SourcePartnerID=tcc.SourcePartnerID, tc.DestinationPartnerID=tcc.DestinationPartnerID
	FROM tblCargo tc INNER JOIN @tblCargo tcc ON tcc.DeliveryNo=tc.DeliveryNo AND tc.TransportID=@TransportID
	AND ((tc.Comment<>tcc.Comment OR tc.ContactInfo<>tcc.ContactInfo /*OR tc.PickupDate<>tcc.PickupDate*/ OR tc.Colli<>tcc.Colli OR tc.Weight<>tcc.Weight OR tc.ContactPhone<>tcc.ContactPhone OR tc.SourcePartnerID<>tcc.SourcePartnerID OR tc.DestinationPartnerID<>tcc.DestinationPartnerID) 
	OR (tc.Status=2)
	)--OR tc.DeliveryDate<>tcc.DeliveryDate)
	   
	--Insert Cargo
	 INSERT INTO [dbo].[tblCargo]
			   ([TransportID]
			   ,[DeliveryNo]
			   ,[Weight]
			   ,[Colli]
			   ,[Comment]
			   ,[DeliveryDate]
			   ,[PickupDate]
			   ,[SourceSiteCode]
			   ,[SourcePartnerID]
			   ,[DestinationSiteCode]
			   ,[DestinationPartnerID]
			   ,[ContactInfo]
			   ,[GLABsID]
			   ,[Status]
			   ,[Direction]
			   ,[StageNo]
			   ,[ContactPhone])
	SELECT	
		@TransportID,
		tcc.DeliveryNo,
		tcc.Weight,
		tcc.Colli,
		tcc.Comment,
		tcc.DeliveryDate,
		tcc.PickupDate,
		tcc.SourceSideCode,
		tcc.SourcePartnerID,
		tcc.DestinationSideCode,
		tcc.DestinationPartnerID,
		tcc.ContactInfo,
		NULL,
		0,
		tcc.Direction,
		tcc.StageNo,
		tcc.ContactPhone
	FROM @tblCargo tcc 
	WHERE NOT EXISTS(SELECT * FROM tblCargo tc WHERE tc.DeliveryNo=tcc.DeliveryNo AND tc.TransportID=@TransportID)

	--Delete Cargo
	UPDATE tc
	SET tc.Status=-1
	FROM tblCargo tc 
	WHERE tc.TransportID=@TransportID
	AND NOT EXISTS(SELECT * FROM @tblCargo tcc WHERE tcc.DeliveryNo=tc.DeliveryNo)
	
	
	--Items: Match on DeliveryNo and ItemCode to prevent duplicate rows and picking lock delete failures
	UPDATE tci
	SET tci.Qty=tcci.Qty, 
	    tci.PalletQty=tcci.PalletQty, 
	    tci.QtyUnitID=tcci.QtyUnitID,
	    tci.SourceStatus=0,
	    tci.DestinationStatus=0, 
	    tci.PickingFlg=tcci.PickingFlg, 
	    tci.StockQty=tcci.StockQty, 
	    tci.OrderNo=tcci.OrderNo, 
	    tci.NetWeight=tcci.NetWeight, 
	    tci.GrossWeight=tcci.GrossWeight, 
	    tci.BatchFlg=tcci.BatchFlg, 
	    tci.Comment=tcci.Comment,
	    tci.ItemName=tcci.ItemName
	FROM tblCargoItem tci 
	INNER JOIN @tblCargoItem tcci 
	    ON tcci.DeliveryNo=tci.DeliveryNo 
	   AND tcci.ItemCode=tci.ItemCode 
	   AND tcci.ItemNo=tci.ItemNo 
	   AND tci.TransportID=@TransportID 
	WHERE ISNULL(tci.SourceStatus, 0) NOT IN (-1, 3)
	  AND ((ISNULL(tci.Qty,0)<>ISNULL(tcci.Qty,0) OR ISNULL(tci.PalletQty,0)<>ISNULL(tcci.PalletQty,0) OR ISNULL(tci.QtyUnitID,'')<>ISNULL(tcci.QtyUnitID,'') OR ISNULL(tci.PickingFlg,0)<>ISNULL(tcci.PickingFlg,0) OR ISNULL(tci.StockQty,0)<>ISNULL(tcci.StockQty,0) OR ISNULL(tci.BatchFlg,0)<>ISNULL(tcci.BatchFlg,0) OR ISNULL(tci.Comment,'')<>ISNULL(tcci.Comment,'') OR ISNULL(tci.NetWeight,0)<>ISNULL(tcci.NetWeight,0) OR ISNULL(tci.GrossWeight,0)<>ISNULL(tcci.GrossWeight,0)) 
	   OR (tci.DestinationStatus=2 OR tci.SourceStatus=2))

	INSERT INTO [dbo].[tblCargoItem]
			   ([DeliveryNo]
			   ,[ItemNo]
			   ,[ItemCode]
			   ,[ItemName]
			   ,[OrderNo]
			   ,[Qty]
			   ,[QtyUnit]
			   ,[QtyUnitID]
			   ,[PalletQty]
			   ,[PickingFlg]
			   ,[Comment]
			   ,[SourceGLABsID]
			   ,[SourceStatus]
			   ,[DestinationGLABsID]
			   ,[DestinationStatus]
			   ,[StockQty]
			   ,TransportID
			   ,NetWeight
			   ,GrossWeight
			   ,BatchFlg)
	SELECT 
		tci.DeliveryNo,
		tci.ItemNo,
		tci.ItemCode,
		tci.ItemName,
		tci.OrderNo,
		tci.Qty,
		tci.QtyUnit,
		tci.QtyUnitID,
		tci.PalletQty,
		tci.PickingFlg,
		tci.Comment,
		NULL,
		0,
		NULL,
		0,
		tci.StockQty,
		@TransportID,
		tci.NetWeight,
		tci.GrossWeight,
		tci.BatchFlg
	FROM @tblCargoItem tci 
	WHERE NOT EXISTS(
		SELECT * FROM tblCargoItem tcci 
		WHERE tcci.DeliveryNo=tci.DeliveryNo 
		  AND tcci.ItemCode=tci.ItemCode 
		  AND tcci.TransportID=@TransportID
		  AND ISNULL(tcci.SourceStatus, 0) NOT IN (-1, 3)
	)

	UPDATE tci
	SET tci.SourceStatus=-1, tci.DestinationStatus=-1
	FROM tblCargoItem tci 
	WHERE tci.DeliveryNo IN(SELECT tca.DeliveryNo FROM @tblCargo tca)
	  AND tci.TransportID=@TransportID
	  AND NOT EXISTS(
		SELECT * FROM @tblCargoItem tcci 
		WHERE tcci.DeliveryNo=tci.DeliveryNo 
		  AND tcci.ItemCode=tci.ItemCode
	  )
	-----------

	--Archive
	INSERT INTO [dbo].[tblTransferTransportArchive]
			   (
			   [id]
			   ,[TransferID]
			   ,[TransportNo]
			   ,[Priority]
			   ,[CarrierCode]
			   ,[CarrierName]
			   ,[CountryCode]
			   ,[CarrierCity]
			   ,[CarrierAddress]
			   ,[CarrierPhone]
			   ,[CarrierMail]
			   ,[CarrierZIP]
			   ,[CarrierTaxID]
			   ,[TruckType]
			   ,[PlantCode]
			   ,[PlantName]
			   ,[TransportDate]
			   ,[PrintCMR]
			   ,[ShipmentType]
			   ,[OrganizerCode]
			   ,[OrganizerName]
			   ,[OrganizerCountryCode]
			   ,[OrganizerCity]
			   ,[OrganizerAddress]
			   ,[OrganizerPhone]
			   ,[OrganizerMail]
			   ,[OrganizerZIP]
			   ,[OrganizerTaxID]
			   ,[LicensePlate1]
			   ,[LicensePlate2]
			   ,[TransportNo2]
			   ,[DriverName]
			   ,[DriverPhone]
			   )
	SELECT
			[id]
			,[TransferID]
			,[TransportNo]
			,[Priority]
			,[CarrierCode]
			,[CarrierName]
			,[CountryCode]
			,[CarrierCity]
			,[CarrierAddress]
			,[CarrierPhone]
			,[CarrierMail]
			,[CarrierZIP]
			,[CarrierTaxID]
			,[TruckType]
			,[PlantCode]
			,[PlantName]
			,[TransportDate]
			,[PrintCMR]
			,[ShipmentType]
			,[OrganizerCode]
			,[OrganizerName]
			,[OrganizerCountryCode]
			,[OrganizerCity]
			,[OrganizerAddress]
			,[OrganizerPhone]
			,[OrganizerMail]
			,[OrganizerZIP]
			,[OrganizerTaxID]
			,[LicensePlate1]
			,[LicensePlate2]
			,[TransportNo2]
			,[DriverName]
			,[DriverPhone]
	FROM [dbo].[tblTransferTransport]
	WHERE TransferID=@TransferID

	INSERT INTO [dbo].[tblTransferTransportDeliveryArchive]
			   ([id]
			   ,[TransferID]
			   ,[TransportID]
			   ,[DeliveryNo]
			   ,[Direction]
			   ,[IncoTerms]
			   ,[Weight]
			   ,[Comment]
			   ,[DeliveryDate]
			   ,[PickupDate]
			   ,[PartnerCode]
			   ,[PartnerName]
			   ,[PartnerCountry]
			   ,[PartnerCity]
			   ,[PartnerAddress]
			   ,[PartnerPhone]
			   ,[PartnerMail]
			   ,[PartnerZIP]
			   ,[PartnerTaxID]
			   ,[ContactInfo]
				,[StageNo]
				,[OrganizerCode]
				,[OrganizerName]
				,[OrganizerCountryCode]
				,[OrganizerCity]
				,[OrganizerAddress]
				,[OrganizerPhone]
				,[OrganizerMail]
				,[OrganizerZIP]
				,[OrganizerTaxID]
				,[SiteID]
				)
	SELECT 
			[id]
			,[TransferID]
			,[TransportID]
			,[DeliveryNo]
			,[Direction]
			,[IncoTerms]
			,[Weight]
			,[Comment]
			,[DeliveryDate]
			,[PickupDate]
			,[PartnerCode]
			,[PartnerName]
			,[PartnerCountry]
			,[PartnerCity]
			,[PartnerAddress]
			,[PartnerPhone]
			,[PartnerMail]
			,[PartnerZIP]
			,[PartnerTaxID]
			,[ContactInfo]
			,[StageNo]
			,[OrganizerCode]
			,[OrganizerName]
			,[OrganizerCountryCode]
			,[OrganizerCity]
			,[OrganizerAddress]
			,[OrganizerPhone]
			,[OrganizerMail]
			,[OrganizerZIP]
			,[OrganizerTaxID]
			,[SiteID]
	FROM [dbo].[tblTransferTransportDelivery]
	WHERE TransferID=@TransferID

	INSERT INTO [dbo].[tblTransferTransportDeliveryItemArchive]
			   ([id]
			   ,[TransferID]
			   ,[TransportID]
			   ,[DeliveryNo]
			   ,[ItemNo]
			   ,[ItemCode]
			   ,[ItemName]
			   ,[OrderNo]
			   ,[Qty]
			   ,[QtyUnit]
			   ,[PalletQty]
			   ,[TaxCode]
			   ,[Comment]
			   ,[StockQty]
			   ,[NetWeight]
			   ,[GrossWeight]
			   ,[BatchFlg]
			   )
	SELECT 
			[id]
			,[TransferID]
			,[TransportID]
			,[DeliveryNo]
			,[ItemNo]
			,[ItemCode]
			,[ItemName]
			,[OrderNo]
			,[Qty]
			,[QtyUnit]
			,[PalletQty]
			,[TaxCode]
			,[Comment]
			,[StockQty]
			,[NetWeight]
			,[GrossWeight]
			,[BatchFlg]
	FROM [dbo].[tblTransferTransportDeliveryItem]
	WHERE TransferID=@TransferID

	INSERT INTO [dbo].[tblTransferTransportStageArchive]
           ([id]
		   ,[TransferID]
           ,[StageNo]
           ,[DeliveryNo]
           ,[AddressNo]
           ,[PartnerCodeFrom]
           ,[PartnerNameFrom]
           ,[PartnerCountryFrom]
           ,[PartnerCityFrom]
           ,[PartnerAddressFrom]
           ,[PartnerPhoneFrom]
           ,[PartnerMailFrom]
           ,[PartnerZIPFrom]
           ,[PartnerCodeTo]
           ,[PartnerNameTo]
           ,[PartnerCountryTo]
           ,[PartnerCityTo]
           ,[PartnerAddressTo]
           ,[PartnerPhoneTo]
           ,[PartnerMailTo]
           ,[PartnerZIPTo]
           ,[SiteIDFrom]
           ,[SiteIDTo])
	SELECT 
			[id]
		   ,[TransferID]
           ,[StageNo]
           ,[DeliveryNo]
           ,[AddressNo]
           ,[PartnerCodeFrom]
           ,[PartnerNameFrom]
           ,[PartnerCountryFrom]
           ,[PartnerCityFrom]
           ,[PartnerAddressFrom]
           ,[PartnerPhoneFrom]
           ,[PartnerMailFrom]
           ,[PartnerZIPFrom]
           ,[PartnerCodeTo]
           ,[PartnerNameTo]
           ,[PartnerCountryTo]
           ,[PartnerCityTo]
           ,[PartnerAddressTo]
           ,[PartnerPhoneTo]
           ,[PartnerMailTo]
           ,[PartnerZIPTo]
           ,[SiteIDFrom]
           ,[SiteIDTo]
	FROM [dbo].[tblTransferTransportStage]
	WHERE TransferID=@TransferID


	--Delete
	DELETE FROM tblTransferTransport WHERE TransferID=@TransferID
	DELETE FROM tblTransferTransportDelivery WHERE TransferID=@TransferID
	DELETE FROM tblTransferTransportDeliveryItem WHERE TransferID=@TransferID
	DELETE FROM tblTransferTransportStage WHERE TransferID=@TransferID

	--LOG
	UPDATE tblTransferIn
	SET TransformFlg=1
	WHERE id=@TransferID

	SET @Msg='SAP Load success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
	SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,1,5,@TransferID,@TransportNo
	
	SET @SuccessFlg=1

END TRY
BEGIN CATCH
	SELECT  
    ERROR_NUMBER() AS ErrorNumber  
    ,ERROR_SEVERITY() AS ErrorSeverity  
    ,ERROR_STATE() AS ErrorState  
    ,ERROR_PROCEDURE() AS ErrorProcedure  
    ,ERROR_LINE() AS ErrorLine  
    ,ERROR_MESSAGE() AS ErrorMessage;  

	UPDATE tblTransferIn
	SET TransformFlg=0
	WHERE id=@TransferID

	SELECT @Msg=ERROR_MESSAGE() 
	
	SET @TransportNo=ISNULL((SELECT tt.TransportNo FROm tblTransferTransport tt WHERE tt.TransferID=@TransferID),(SELECT tt.TransportNo FROm tblTransferTransportArchive tt WHERE tt.TransferID=@TransferID))
	--SET @Msg='SAP Load failure'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
	SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo

	SET @SuccessFlg=0
END CATCH

END
GO
