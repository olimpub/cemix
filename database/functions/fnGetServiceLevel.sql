/****** Object:  UserDefinedFunction [dbo].[fnGetServiceLevel]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnGetServiceLevel](
       @SAPID VARCHAR(100),
	   @SiteCode VARCHAR(15)
       )
    RETURNS VARCHAR(100)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(100)

	   SET @Return=ISNULL((SELECT tx.GLABsID FROM tblXrefServiceLevel tx WHERE tx.SAPID=@SAPID AND tx.SiteCode=@SiteCode),(SELECT tx.GLABsID FROM tblXrefServiceLevel tx WHERE tx.SAPID='SYSDEFAULT' AND tx.SiteCode=@SiteCode))
    
       RETURN @Return
    END
GO
