/****** Object:  UserDefinedFunction [dbo].[fnGetSiteCode]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnGetSiteCode](
	   @SiteCode VARCHAR(10)
       )
    RETURNS VARCHAR(50)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(50)

	   SET @Return=ISNULL((SELECT cp.SiteCode FROM tblClientParams cp WHERE cp.SiteCode=@SiteCode AND cp.ActiveFlg=1),(SELECT cp.SiteCode FROM tblClientParams cp WHERE cp.WHCode=@SiteCode AND cp.ActiveFlg=1))    
       RETURN @Return
    END
GO
