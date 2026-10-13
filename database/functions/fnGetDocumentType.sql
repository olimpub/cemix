/****** Object:  UserDefinedFunction [dbo].[fnGetDocumentType]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnGetDocumentType](
       @SAPID VARCHAR(100)
       )
    RETURNS VARCHAR(100)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(100)

	   SET @Return=ISNULL((SELECT tx.GLABsID FROM tblXrefDocumentType tx WHERE tx.SAPID=@SAPID),(SELECT tx.GLABsID FROM tblXrefDocumentType tx WHERE tx.SAPID='SYSDEFAULT'))
    
       RETURN @Return
    END
GO
