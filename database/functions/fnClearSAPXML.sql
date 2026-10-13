/****** Object:  UserDefinedFunction [dbo].[fnClearSAPXML]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnClearSAPXML](
       @Body NVARCHAR(MAX)
       )
    RETURNS XML
    AS
    BEGIN

      -- Declare the return variable here
       DECLARE @ResultVar XML

	   IF(@Body LIKE '<?xml version%')
	   BEGIN
		   SELECT @Body=REPLACE(@Body,'<?xml version="1.0" encoding="UTF-8"?>','')
		   SELECT @Body=REPLACE(@Body,' SEGMENT="1"','')
		   SELECT @Body=REPLACE(@Body,' BEGIN="1"','')
	   END
	   ELSE 
	   BEGIN
		   SELECT @Body=REPLACE(@Body,'<n0:YYSHPMNT06_GLABS xmlns:n0="http://www.lasselsberger.com/YYSHPMNT06_GLABS/" xmlns:prx="urn:sap.com:proxy:DS4:/1SAI/TAS13E43C478AD2BC75F7B5:758" xmlns:soap-env="http://schemas.xmlsoap.org/soap/envelope/">','<YYSHPMNT06_GLABS>')
		   SELECT @Body=REPLACE(@Body,' BEGIN=""','')
		   SELECT @Body=REPLACE(@Body,' SEGMENT=""','')
		   SELECT @Body=REPLACE(@Body,' SEGMENT="1"','')
		   SELECT @Body=REPLACE(@Body,' BEGIN="1"','')
		   SELECT @Body=REPLACE(@Body,'n0:','')
	   END
       SELECT @ResultVar=CAST(@Body AS XML)
       RETURN @ResultVar
    END
GO
