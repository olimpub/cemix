/****** Object:  View [dbo].[vwArrivalDates]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwArrivalDates]
AS
SELECT ts.id AS ShipmentID, tc.StageNo, MIN(tc.ArrivalDate) AS ArrivalDate FROM tblShipment ts INNER JOIN tblCargo tc
ON tc.TransportID=ts.TransportID
WHERE tc.StageNo IS NOT NULL AND ArrivalDate IS NOT NULL
GROUP BY ts.id, tc.StageNo

GO
