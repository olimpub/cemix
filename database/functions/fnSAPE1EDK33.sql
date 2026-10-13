/****** Object:  UserDefinedFunction [dbo].[fnSAPE1EDK33]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[fnSAPE1EDK33](
	@ShipmentID INT
)
    RETURNS XML
    AS
    BEGIN

    	-- Declare the return variable here
    	DECLARE @ResultVar XML

    	SET @ResultVar =
    		(
			SELECT 
				1 AS '@SEGMENT',
				vw.StageNo AS TSNUM,
				[dbo].[fnSAPE1EDT45](vw.ShipmentID,vw.StageNo)
			FROM vwArrivalDates vw
			WHERE vw.ShipmentID=@ShipmentID
			ORDER BY vw.StageNo
			FOR XML PATH('E1EDK33')
    		)
    		
    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
