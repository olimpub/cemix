/****** Object:  UserDefinedFunction [dbo].[fnGetShipmentOrganizer]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnGetShipmentOrganizer](
       @SAPID VARCHAR(100)
       )
    RETURNS BIT
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return BIT

	   SET @Return=ISNULL((SELECT tx.GLABsID FROM tblXrefShipmentOrganizer tx WHERE tx.SAPID=@SAPID),(SELECT tx.GLABsID FROM tblXrefShipmentOrganizer tx WHERE tx.SAPID='SYSDEFAULT'))
    
       RETURN @Return
    END
GO
