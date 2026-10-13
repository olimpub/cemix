/****** Object:  UserDefinedFunction [dbo].[fnBase64CLR]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE FUNCTION [dbo].[fnBase64CLR](@Input [nvarchar](max))
RETURNS [nvarchar](max) WITH EXECUTE AS CALLER
AS 
EXTERNAL NAME [Base64Dll].[UserDefinedFunctions].[Base64Decode]
GO
