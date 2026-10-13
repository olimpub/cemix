/****** Object:  UserDefinedFunction [dbo].[fnGetSAPTemplateID]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--MW load process change
CREATE FUNCTION [dbo].[fnGetSAPTemplateID](
       @SAPID VARCHAR(100),
	   @SiteCode VARCHAR(15)
       )
    RETURNS VARCHAR(100)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return INT

	   SELECT @Return=ISNULL((SELECT tx.TemplateID FROM [dbo].[tblXrefShipmentRule] tx WHERE tx.SAPID=@SAPID AND tx.SiteCode=@SiteCode),(SELECT tx.TemplateID FROM [dbo].[tblXrefShipmentRule] tx WHERE tx.SAPID='SYSDEFAULT' AND tx.SiteCode=@SiteCode))
    
       RETURN @Return
    END
GO
