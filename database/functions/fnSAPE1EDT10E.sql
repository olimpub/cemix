/****** Object:  UserDefinedFunction [dbo].[fnSAPE1EDT10E]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[fnSAPE1EDT10E](
	@ShipmentID INT
)
    RETURNS XML
    AS
    BEGIN

    	-- Declare the return variable here
    	DECLARE @ResultVar XML, @BookingDate DATETIME, @ShipmentStatus INT, @TransportID VARCHAR(50)

		SELECT  @ShipmentStatus = ts.ShipmentStatus,@BookingDate= DATEADD(mi,15,ts.BookingDate), @TransportID=ts.TransportID FROM tblShipment ts WHERE ts.id=@ShipmentID

		IF(@ShipmentStatus=1)
		BEGIN
    		SET @ResultVar =
    			(
				SELECT 
					1 AS '@SEGMENT',
					'003' AS [QUALF],
					CONVERT(VARCHAR,@BookingDate,112) AS [NTEND],
					REPLACE(CONVERT(VARCHAR, @BookingDate,108),':','') AS [NTENZ]
				FOR XML PATH('E1EDT10')
    			)
		END

		IF(@ShipmentStatus=5)
		BEGIN
			SELECT  @BookingDate=MAX(tc.ArrivalDate) FROM tblCargo tc WHERE tc.TransportID=@TransportID
			
			IF(@BookingDate IS NOT NULL AND @BookingDate>GETDATE())
			BEGIN
	    		SET @ResultVar =
    			(
				SELECT 
					1 AS '@SEGMENT',
					'005' AS [QUALF],
					CONVERT(VARCHAR,@BookingDate,112) AS [IEDD],
					REPLACE(CONVERT(VARCHAR, @BookingDate,108),':','') AS [IEDZ]
				FOR XML PATH('E1EDT10')
    			)
			END
			ELSE
			BEGIN
				SET @ResultVar =
    			(
				SELECT 
					1 AS '@SEGMENT',
					'005' AS [QUALF],
					CONVERT(VARCHAR,GETDATE()+0.05,112) AS [IEDD],
					REPLACE(CONVERT(VARCHAR, GETDATE()+0.05,108),':','') AS [IEDZ]
				FOR XML PATH('E1EDT10')
    			)
			END
		END


    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
