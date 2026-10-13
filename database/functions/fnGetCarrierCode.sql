/****** Object:  UserDefinedFunction [dbo].[fnGetCarrierCode]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE FUNCTION [dbo].[fnGetCarrierCode](
       @PartnerCode VARCHAR(50),
	   @SiteCode VARCHAR(10)
       )
    RETURNS VARCHAR(50)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(50)

	   SET @Return=ISNULL((SELECT TOP 1 tp.GLABsID FROM tblPartner tp WHERE tp.PartnerCode=@PartnerCode AND tp.SiteCode=@SiteCode AND tp.PartnerType=3),ISNULL((SELECT TOP 1 tp.GLABsID FROM tblPartner tp WHERE tp.PartnerCode=@PartnerCode AND tp.PartnerType=3),''))
    
       RETURN @Return
    END
GO
