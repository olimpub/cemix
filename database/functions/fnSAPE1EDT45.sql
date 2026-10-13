/****** Object:  UserDefinedFunction [dbo].[fnSAPE1EDT45]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnSAPE1EDT45](
	@ShipmentID INT,
	@StageNo VARCHAR(20)
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
				'005' AS [QUALF],
				CONVERT(VARCHAR,vw.ArrivalDate,112) AS [NTEND],
				REPLACE(CONVERT(VARCHAR, vw.ArrivalDate,108),':','') AS [NTENZ]
			FROM vwArrivalDates vw
			WHERE vw.ShipmentID=@ShipmentID AND vw.StageNo=@StageNo
			FOR XML PATH('E1EDT45')
    		)
    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
