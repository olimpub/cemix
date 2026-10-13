/****** Object:  UserDefinedFunction [dbo].[fnBase64DecodeCLR]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE FUNCTION [dbo].[fnBase64DecodeCLR](@Input [nvarchar](max))
RETURNS [varbinary](max) WITH EXECUTE AS CALLER
AS 
EXTERNAL NAME [Base64DecodeDll].[UserDefinedFunctions].[DecodeBase64]
GO
