/****** Object:  StoredProcedure [dbo].[spTransportTracker]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spTransportTracker](
	@TransportNo VARCHAR(50),
	@SearchInLive BIT
)
AS 
BEGIN
DECLARE @Log TABLE(
	[ActionName] [nvarchar](100) NOT NULL,
	[id] [int] NOT NULL,
	[SPName] [nvarchar](100) NOT NULL,
	[Inparams] [nvarchar](1000) NOT NULL,
	[Outparams] [nvarchar](1000) NOT NULL,
	[SuccessFlg] [bit] NOT NULL,
	[Msg] [nvarchar](max) NOT NULL,
	[TransportNo] [varchar](30) NULL,
	[DeliveryNo] [varchar](30) NULL,
	[ItemNo] [varchar](20) NULL,
	[ProcessID] [smallint] NULL,
	[NotificationFlg] [bit] NULL,
	[TransferIn] [int] NULL,
	[TransferOut] [int] NULL,
	[PartnerID] [int] NULL,
	[LogDate] [datetime] NOT NULL
)

INSERT INTO @Log
SELECT lp.ActionName,tl.* FROM tblLog tl INNER JOIN tblLogProcess lp ON lp.id=tl.ProcessID
WHERE tl.TransportNo=@TransportNo



SELECT 'Full Log' AS Result,* FROM @Log
--------------------------------------
IF(@SearchInLive=1)
BEGIN
	--Transzport SAP adat
	SELECT 'SAP transport data' AS Result, * FROm tblTransferTransport WHERE TransferID IN(
	SELECT TransferIn FROM @Log
	)

	SELECT 'SAP delivery note data' AS Result, * FROm tblTransferTransportDelivery WHERE TransferID IN(
	SELECT TransferIn FROM @Log
	)

	SELECT 'SAP item data' AS Result, * FROm tblTransferTransportDeliveryItem WHERE TransferID IN(
	SELECT TransferIn FROM @Log
	)

	SELECT 'SAP stage data' AS Result,* FROm tblTransferTransportStage WHERE TransferID IN(
	SELECT TransferIn FROM @Log
	)
END
ELSE
BEGIN
	--Transzport SAP adat
	SELECT 'SAP transport data' AS Result, * FROm tblTransferTransportArchive WHERE TransferID IN(
	SELECT TransferIn FROM @Log
	)

	SELECT 'SAP delivery note data' AS Result, * FROm tblTransferTransportDeliveryArchive WHERE TransferID IN(
	SELECT TransferIn FROM @Log
	)

	SELECT 'SAP item data' AS Result, * FROm tblTransferTransportDeliveryItemArchive WHERE TransferID IN(
	SELECT TransferIn FROM @Log
	)

	SELECT 'SAP stage data' AS Result,* FROm tblTransferTransportStageArchive WHERE TransferID IN(
	SELECT TransferIn FROM @Log
)
END

---------------------------------------------------------
SELECT 'MW transport data' AS Result,ts.*,tp.PartnerCode AS CArrierCode, tp.PartnerName AS CarrierName,tp2.PartnerCode AS OrganizerCode, tp2.PartnerName AS OrganizerName FROm tblTransport ts
INNER JOIN tblPartner tp ON tp.GLABsID=ts.CarrierID
LEFT OUTER JOIN tblPartner tp2 ON tp2.GLABsID=ts.OrganizerID
WHERE TransportNo=@TransportNo
ORDER BY id

SELECT 'MW station data',ts.* FROm tblShipment ts WHERE ts.TransportID=@TransportNo


SELECT 'MW delivery data' AS Result,tc.* FROm tblCargo tc WHERE TransportID=@TransportNo

SELECT 'MW delivery item data', ci.* FROM tblCargoItem ci INNER JOIN tblCargo tc ON tc.DeliveryNo=ci.DeliveryNo
WHERE ci.TransportID=@TransportNo
-------------------------------------------------------
--Transfers IN
SELECT 'SAP Files' AS Result, * FROM tblTransferIn WHERE id IN(
SELECT TransferIn FROM @Log
)

--Transfers Out
SELECT 'MW transfer out' AS Result, * FROM tblTransferOut WHERE id IN(
SELECT TransferOut FROM @Log
)

SELECT  'ShipmentQueue', * FROM tblShipmentStatusQueue WHERE StationID IN(
	SELECT ts.StationID FROm tblShipment ts WHERE ts.TransportID=@TransportNo
)
ORDER BY ActionDate
END

GO
