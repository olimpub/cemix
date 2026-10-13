/****** Object:  UserDefinedFunction [dbo].[fnSAPE1EDT47]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnSAPE1EDT47](
	@ShipmentID INT
)
/*
Version 1.00

1.00	:		Created by Daniel Bakos on 2024/07/06
*/
    RETURNS XML
    AS
    BEGIN

    	-- Declare the return variable here
    	DECLARE @ResultVar XML

    	SET @ResultVar =
    		(
			SELECT TOP 1
				1 AS '@SEGMENT',
				tb.SAPID AS [TEXT1]
			FROM tblCargo tc INNER JOIN tblShipment ts ON ts.TransportID=tc.TransportID
			INNER JOIN tblXrefBorder tb ON tb.GLABsID=tc.BorderCrossingID
			WHERE ts.id=@ShipmentID
			FOR XML PATH('E1EDT47')
    		)
    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
