/****** Object:  UserDefinedFunction [dbo].[fnGetValidTaxCode]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnGetValidTaxCode](
       @SAPID VARCHAR(100),
	   @ItemCode VARCHAR(100)
       )
    RETURNS BIT
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return BIT

	   SET @Return=ISNULL((SELECT tx.GLABsID FROM tblXrefTaxCode tx WHERE tx.SAPID=@SAPID
	   AND NOT EXISTS(SELECT tl.ExValue FROM tblXrefExceptions tl WHERE tl.ExType='TaxCode' AND tl.ExValue=@ItemCode)),(SELECT tx.GLABsID FROM tblXrefTaxCode tx WHERE tx.SAPID='SYSDEFAULT'))
    
       RETURN @Return
    END
GO
