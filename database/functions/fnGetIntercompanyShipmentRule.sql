/****** Object:  UserDefinedFunction [dbo].[fnGetIntercompanyShipmentRule]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnGetIntercompanyShipmentRule](
       @SAPID VARCHAR(100),
	   @SiteCode VARCHAR(15)
       )
    RETURNS VARCHAR(100)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(100)
	   SELECT @Return=ISNULL((SELECT tx.IntercompanyGLABsID FROM [dbo].[tblXrefShipmentRule] tx WHERE tx.SAPID=@SAPID AND tx.SiteCode=@SiteCode),(SELECT tx.IntercompanyGLABsID FROM [dbo].[tblXrefShipmentRule] tx WHERE tx.SAPID='SYSDEFAULT' AND tx.SiteCode=@SiteCode))
	   
	   IF(@Return IS NULL)
	   BEGIN
			SELECT @Return=ISNULL((SELECT tx.GLABsID FROM [dbo].[tblXrefShipmentRule] tx WHERE tx.SAPID=@SAPID AND tx.SiteCode=@SiteCode),(SELECT tx.GLABsID FROM [dbo].[tblXrefShipmentRule] tx WHERE tx.SAPID='SYSDEFAULT' AND tx.SiteCode=@SiteCode))
	   END
       RETURN @Return
    END
GO
