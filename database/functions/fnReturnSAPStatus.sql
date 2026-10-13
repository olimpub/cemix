/****** Object:  UserDefinedFunction [dbo].[fnReturnSAPStatus]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnReturnSAPStatus](
	@ShipmentID INT
)
/*
Version 1.01

1.01	:		Changed by Daniel Bakos, add SAPTemplateID to tblShipment on 2023/02/19
*/
RETURNS VARCHAR(10)
BEGIN
	DECLARE @TransportNo VARCHAR(30),@SiteCode VARCHAR(10), @SAPStatus VARCHAR(10), @ShipmentStatus INT, @SAPTemplateID INT
	SELECT @TransportNo = ts.TransportID, @SiteCode = ts.SiteCode, @ShipmentStatus = ts.ShipmentStatus, @SAPTemplateID = ts.SAPTemplateID FROM tblShipment ts WHERE ts.id=@ShipmentID
	IF(@SAPTemplateID IS NULL)
	BEGIN
		SET @SAPTemplateID=(SELECT tst.id FROm tblShipmentStatusTemplate tst WHERE tst.DefaultFlg=1)
	END
	IF EXISTS(SELECT * FROM tblCargo tc WHERE tc.TransportID=@TransportNo AND tc.Direction=1)
	BEGIN
		SELECT @SAPStatus = ts.SAPStatusOut FROM tblShipmentStatus ts WHERE ts.id=@ShipmentStatus AND ts.TemplateID=@SAPTemplateID
	END
	ELSE
	BEGIN
		SELECT @SAPStatus = ts.SAPStatusIn FROM tblShipmentStatus ts WHERE ts.id=@ShipmentStatus AND ts.TemplateID=@SAPTemplateID
	END

	RETURN @SAPStatus
END
GO
