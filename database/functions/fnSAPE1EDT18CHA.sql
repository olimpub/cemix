/****** Object:  UserDefinedFunction [dbo].[fnSAPE1EDT18CHA]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[fnSAPE1EDT18CHA](
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
				1 AS '@SEGMENT',
				'CHA' AS [QUALF],
				'' AS [PARAM]
			FOR XML PATH('E1EDT18')
    		)
    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
