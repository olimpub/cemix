/****** Object:  View [dbo].[vwCarrierStat]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwCarrierStat]
AS
SELECT tp.PartnerName, tss.Latency, tss.ShipmentDate, CASE tsp.SelfOrganized WHEN 1 THEN 'Cemix' ELSE 'Partner' END AS OrganizedBy FROM tblShipmentStat tss INNER JOIN tblShipment ts ON tss.StationID=ts.StationID AND tss.SiteCode=ts.SiteCode
INNER JOIN tblTransport tsp ON tsp.TransportNo=ts.TransportID
INNER JOIN tblPartner tp ON tp.GLABsID=tsp.CarrierID
WHERE Latency IS NOT NULL AND tp.PartnerName<>'Fuvarozó cég'
AND Latency<360
GO
