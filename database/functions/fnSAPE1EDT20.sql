/****** Object:  UserDefinedFunction [dbo].[fnSAPE1EDT20]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[fnSAPE1EDT20](
	@ShipmentID INT
)
/*
Version 1.01

1.01	:		Changed by Daniel Bakos on 2024/07/06, added Border crossing segment
*/
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
				ts.TransportID AS [TKNUM],
				tss.[LicensePlate1] AS [EXTI1],
				tss.[LicensePlate2] AS [EXTI2],
				tss.[DriverPhone] AS [SIGNI],
				--CASE ts.ShipmentStatus WHEN 1 THEN 0 WHEN 2 THEN '3' WHEN 3 THEN '3' WHEN 4 THEN '3' WHEN 5 THEN '6' END AS [STTRG], ---Only For Phase1
				--CASE ts.ShipmentStatus WHEN 1 THEN 0 WHEN 3 THEN '3' WHEN 4 THEN '4' WHEN 5 THEN '7' END AS [STTRG],
				[dbo].[fnReturnSAPStatus](@ShipmentID) AS [STTRG],
				[dbo].[fnSAPE1EDT18CHA](),
				[dbo].[fnSAPE1EDT18PID](),
				CASE WHEN [dbo].[fnReturnSAPSegmentVisibility](@ShipmentID,1)=1 THEN [dbo].[fnSAPE1EDT10](ts.id) END, --Only For Phase 1
				CASE WHEN [dbo].[fnReturnSAPSegmentVisibility](@ShipmentID,2)=1 THEN [dbo].[fnSAPE1EDT10E](ts.id) END, --Only Fpor Phase 1
				CASE WHEN [dbo].[fnReturnSAPSegmentVisibility](@ShipmentID,3)=1 THEN [dbo].[fnSAPE1EDK33](ts.id) END,
				CASE WHEN [dbo].[fnReturnSAPBorderVisibility](@ShipmentID)=1 THEN [dbo].[fnSAPE1EDT47](ts.id) END
			FROM [dbo].[tblShipment] ts
			INNER JOIN tblTransport tss ON tss.TransportNo=ts.TransportID
			WHERE ts.id=@ShipmentID
			FOR XML PATH('E1EDT20')
    		)
    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
