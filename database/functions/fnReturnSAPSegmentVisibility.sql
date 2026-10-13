/****** Object:  UserDefinedFunction [dbo].[fnReturnSAPSegmentVisibility]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--SAP write back change
CREATE FUNCTION [dbo].[fnReturnSAPSegmentVisibility](
	@ShipmentID INT,
	@Segment SMALLINT --1=DateStart 2=DateEnd 3=ArrivalDates
)
/*
Version 1.01

1.01	:		Changed by Daniel Bakos, add SAPTemplateID to tblShipment on 2023/02/19
*/
RETURNS BIT
BEGIN
	DECLARE @TransportNo VARCHAR(30),@SiteCode VARCHAR(10), @SAPStatus BIT, @ShipmentStatus INT, @SAPTemplateID INT
	SELECT @TransportNo = ts.TransportID, @SiteCode = ts.SiteCode, @ShipmentStatus = ts.ShipmentStatus, @SAPTemplateID = ts.SAPTemplateID FROM tblShipment ts WHERE ts.id=@ShipmentID
	IF(@SAPTemplateID IS NULL)
	BEGIN
		SET @SAPTemplateID=(SELECT tst.id FROm tblShipmentStatusTemplate tst WHERE tst.DefaultFlg=1)
	END
	IF EXISTS(SELECT * FROM tblCargo tc WHERE tc.TransportID=@TransportNo AND tc.Direction=1)
	BEGIN
		IF(@Segment=1)
		BEGIN
			SELECT @SAPStatus = ts.SAPStatusOutDateStart FROM tblShipmentStatus ts WHERE ts.id=@ShipmentStatus AND ts.TemplateID=@SAPTemplateID
		END	
		IF(@Segment=2)
		BEGIN
			SELECT @SAPStatus = ts.SAPStatusOutDateEnd FROM tblShipmentStatus ts WHERE ts.id=@ShipmentStatus AND ts.TemplateID=@SAPTemplateID
		END
		IF(@Segment=3)
		BEGIN
			SELECT @SAPStatus = ts.SAPStatusArrivalDate FROM tblShipmentStatus ts WHERE ts.id=@ShipmentStatus AND ts.TemplateID=@SAPTemplateID
		END
	END
	ELSE
	BEGIN
		IF(@Segment=1)
		BEGIN
			SELECT @SAPStatus = ts.SAPStatusInDateStart FROM tblShipmentStatus ts WHERE ts.id=@ShipmentStatus AND ts.TemplateID=@SAPTemplateID
		END	
		IF(@Segment=2)
		BEGIN
			SELECT @SAPStatus = ts.SAPStatusInDateEnd FROM tblShipmentStatus ts WHERE ts.id=@ShipmentStatus AND ts.TemplateID=@SAPTemplateID
		END
		IF(@Segment=3)
		BEGIN
			SELECT @SAPStatus = ts.SAPStatusArrivalDate FROM tblShipmentStatus ts WHERE ts.id=@ShipmentStatus AND ts.TemplateID=@SAPTemplateID
		END
	END

	RETURN @SAPStatus
END
GO
