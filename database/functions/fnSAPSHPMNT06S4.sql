/****** Object:  UserDefinedFunction [dbo].[fnSAPSHPMNT06S4]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[fnSAPSHPMNT06S4](
	@ShipmentID INT
)
    RETURNS XML
    AS
    BEGIN

    	-- Declare the return variable here
    	DECLARE @ResultVar XML

    	-- Add the T-SQL statements to compute the return value here
    	SET @ResultVar =
    		(SELECT 
				[dbo].[fnSAPIDOCS4](@ShipmentID)
			FOR XML PATH('SHPMNT06')
    		)
    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
