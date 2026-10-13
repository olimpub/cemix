/****** Object:  UserDefinedFunction [dbo].[fnSAPE1EDT10]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE FUNCTION [dbo].[fnSAPE1EDT10](
	@ShipmentID INT
)
    RETURNS XML
    AS
    BEGIN

    	-- Declare the return variable here
    	DECLARE @ResultVar XML,@ShipmentStatus SMALLINT, @BookingDate DATETIME

		SELECT @ShipmentStatus = ts.ShipmentStatus, @BookingDate= ts.BookingDate FROM tblShipment ts WHERE ts.id=@ShipmentID



    	IF(@ShipmentStatus=1)
		BEGIN
    	SET @ResultVar =
    		(
			SELECT 
				1 AS '@SEGMENT',
				'003' AS [QUALF],
				CONVERT(VARCHAR,@BookingDate,112) AS [NTANF],
				REPLACE(CONVERT(VARCHAR, @BookingDate,108),':','') AS [NTANZ]
			FOR XML PATH('E1EDT10')
    		)
		END

    	IF(@ShipmentStatus=2)
		BEGIN
    	SET @ResultVar =
    		(
			SELECT 
				1 AS '@SEGMENT',
				'003' AS [QUALF], --Only for Phase1
				CONVERT(VARCHAR,GETDATE(),112) AS [ISDD],
				REPLACE(CONVERT(VARCHAR, GETDATE(),108),':','') AS [ISDZ]
			FOR XML PATH('E1EDT10')
    		)
		END

		IF(@ShipmentStatus=3)
		BEGIN
    	SET @ResultVar =
    		(
			SELECT 
				1 AS '@SEGMENT',
				'003' AS [QUALF],
				CONVERT(VARCHAR,GETDATE(),112) AS [ISDD],
				REPLACE(CONVERT(VARCHAR, GETDATE(),108),':','') AS [ISDZ]
			FOR XML PATH('E1EDT10')
    		)
		END

		IF(@ShipmentStatus=4)
		BEGIN
    	SET @ResultVar =
    		(
			SELECT 
				1 AS '@SEGMENT',
				'003' AS [QUALF],
				CONVERT(VARCHAR,GETDATE(),112) AS [IEDD],
				REPLACE(CONVERT(VARCHAR, GETDATE(),108),':','') AS [IEDZ]
			FOR XML PATH('E1EDT10')
    		)
		END

		
		IF(@ShipmentStatus=5)
		BEGIN
    	SET @ResultVar =
    		(
			SELECT 
				1 AS '@SEGMENT',
				'005' AS [QUALF],
				CONVERT(VARCHAR,GETDATE(),112) AS [ISDD],
				REPLACE(CONVERT(VARCHAR, GETDATE(),108),':','') AS [ISDZ]
			FOR XML PATH('E1EDT10')
    		)
		END

    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
