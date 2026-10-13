/****** Object:  View [dbo].[vwPersonPickingStats]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwPersonPickingStats]
AS
SELECT DISTINCT sl.StationID, sl.SiteCode,ISNULL((usr.FirstName+' '+usr.LastName), usr.Email) AS "User",sl.StartDate AS "Date",
CASE LogTime WHEN 0 THEN 1 ELSE LogTime END AS "Time worked", PackagePrepared AS "Package Prepared",
CAST(PackagePrepared AS NUMERIC(9,2))/(CASE LogTime WHEN 0 THEN CAST(1.00 AS NUMERIC(9,2)) ELSE CAST(LogTime AS NUMERIC(9,2)) END) AS "Picking Effectivity"
FROM tblShipmentLog sl INNER JOIN tblUsers usr ON usr.ProfileUserID=sl.UserID 
INNER JOIN tblShipmentStat tss ON tss.StationID=sl.StationID
WHERE PickingFlg=1 AND LogTime IS NOT NULL AND usr.ReportFlg=1
GO
