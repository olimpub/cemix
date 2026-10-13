/****** Object:  UserDefinedFunction [dbo].[fnGetDocumentTypev225]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Change function
CREATE FUNCTION [dbo].[fnGetDocumentTypev225](
       @SAPID VARCHAR(100),
	   @SiteCode VARCHAR(15),
	   @SelfOrganized BIT
       )
    RETURNS VARCHAR(100)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(100)
	   SET @Return=ISNULL((SELECT tx.GLABsID FROM tblXrefDocumentType tx WHERE tx.SAPID=@SAPID AND tx.SiteCode=@SiteCode AND tx.SelfOrganized=@SelfOrganized),
			ISNULL((SELECT tx.GLABsID FROM tblXrefDocumentType tx WHERE tx.SAPID=@SAPID AND tx.SiteCode=@SiteCode AND tx.SelfOrganized IS NULL),(SELECT tx.GLABsID FROM tblXrefDocumentType tx WHERE tx.SAPID='SYSDEFAULT' AND tx.SiteCode=@SiteCode)))
    
       RETURN @Return
    END
GO
