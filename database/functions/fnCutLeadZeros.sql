/****** Object:  UserDefinedFunction [dbo].[fnCutLeadZeros]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnCutLeadZeros](
       @Input VARCHAR(100)
       )
    RETURNS VARCHAR(100)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(100)

	   SELECT @Return=SUBSTRING(@Input, PATINDEX('%[^0]%', @Input), LEN(@Input))
    
       RETURN @Return
    END
GO
