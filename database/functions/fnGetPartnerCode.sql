/****** Object:  UserDefinedFunction [dbo].[fnGetPartnerCode]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[fnGetPartnerCode](
       @PartnerCode VARCHAR(50),
	   @SiteCode VARCHAR(15)
       )
    RETURNS VARCHAR(50)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(50)
	   IF([dbo].[fnGetSiteCode](@PartnerCode)=@SiteCode)
	   BEGIN
			SELECT TOP 1  @Return=tp.GLABsID FROM tblPartner tp WHERE tp.PartnerCode=@PartnerCode AND tp.SiteCode=@SiteCode AND tp.PartnerType=1
	   END
	   ELSE
	   BEGIN
			SELECT @Return=ISNULL([dbo].[fnGetSiteID](@PartnerCode),(SELECT TOP 1 tp.GLABsID FROM tblPartner tp WHERE tp.PartnerCode=@PartnerCode AND tp.SiteCode=@SiteCode AND tp.PartnerType=1))
	   END
	  
	   /*
	   IF(ISNULL(@PlantCode,'')='')
	   BEGIN
			SET @Return=ISNULL((SELECT TOP 1 tp.GLABsID FROM tblPartner tp WHERE tp.PartnerCode=@PartnerCode /*AND tp.SiteCode=@SiteCode*/ AND tp.PartnerType=1),ISNULL((SELECT TOP 1 tp.GLABsID FROM tblPartner tp WHERE tp.PartnerCode=@PartnerCode AND tp.PartnerType=1),''))
	   END
	   ELSE
	   BEGIN
			SET @Return=ISNULL((SELECT TOP 1 tp.GLABsID FROM tblPartner tp WHERE tp.PartnerCode=@PartnerCode /* AND tp.SiteCode=@SiteCode*/ AND tp.PlantCode=@PlantCode AND tp.PartnerType=1),ISNULL((SELECT TOP 1 tp.GLABsID FROM tblPartner tp WHERE tp.PartnerCode=@PartnerCode /*AND tp.PlantCode=@PlantCode*/ AND tp.PartnerType=1),''))
	   END
	   */
       RETURN @Return
    END
GO
