/****** Object:  View [dbo].[vwSiteStats]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwSiteStats]
AS
SELECT SiteCode, StationID, ShipmentDate AS "Date",ISNULL(WaitingTime,0) AS "Waiting Time",
ISNULL(Latency,0) AS "Late",PackagePrepared AS "Picked package", (WeightIn+WeightOut)/1000 AS "Weight",(WaitingTime+LoadingTime+CheckOutTime)  AS "Turnaround Time"
FROm tblShipmentStat
WHERE ISNULL(WaitingTime,0)<241 AND ISNULL(LoadingTime,0)<241 AND ISNULL(CheckOutTime,0)<241 
AND ((WeightIn+WeightOut)/1000)<100
GO
