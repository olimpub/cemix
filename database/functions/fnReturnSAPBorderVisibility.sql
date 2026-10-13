/****** Object:  UserDefinedFunction [dbo].[fnReturnSAPBorderVisibility]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--SAP write back change
CREATE FUNCTION [dbo].[fnReturnSAPBorderVisibility](
	@ShipmentID INT
)
/*
Version 1.00

1.00	:		Created by Daniel Bakos on 2024/07/06
*/
RETURNS BIT
BEGIN
	DECLARE @Visible BIT
	IF EXISTS(SELECT * FROM tblShipment ts INNER JOIN tblCargo tc ON tc.TransportID=ts.TransportID WHERE ts.id=@ShipmentID AND tc.BorderCrossingID IS NOT NULL)
	BEGIN
		SET @Visible=1
	END
	ELSE
	BEGIN
		SET @Visible=0
	END

	RETURN @Visible
END
GO
