/****** Object:  UserDefinedFunction [dbo].[fnCleanLicensePlate]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnCleanLicensePlate](
       @Input VARCHAR(100)
       )
    RETURNS VARCHAR(100)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(100)

	   IF(LEN(RTRIM(LTRIM(@Input)))=1)
	   BEGIN
			SET @Return=NULL
	   END
	   ELSE
	   BEGIN
			SET @Return=@Input
	   END
    
       RETURN @Return
    END
GO
