/****** Object:  UserDefinedFunction [dbo].[fnSAPIDOC]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnSAPIDOC](
	@ShipmentID INT
)
    RETURNS XML
    AS
    BEGIN

    	-- Declare the return variable here
    	DECLARE @ResultVar XML

    	-- Add the T-SQL statements to compute the return value here
    	SET @ResultVar =
    		(
			SELECT 
				1 AS '@BEGIN',
				[dbo].[fnSAPEDIHeader](),
				[dbo].[fnSAPE1EDT20](@ShipmentID)
			FROM [dbo].[tblShipment] ts
			WHERE ts.id=@ShipmentID
			FOR XML PATH('IDOC')
    		)
    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
