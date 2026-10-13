/****** Object:  UserDefinedFunction [dbo].[fnConvertToDatetime]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnConvertToDatetime](
       @Date VARCHAR(50)
       )
    RETURNS DATETIME
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return DATETIME

	   SET @Date=LEFT(@Date,4)+'-'+SUBSTRING(@Date,5,2)+'-'+SUBSTRING(@Date,7,2)+' '+SUBSTRING(@Date,9,2)+':'+SUBSTRING(@Date,11,2)+':'+SUBSTRING(@Date,13,2)
	   SELECT @Return=CONVERT(DATETIME,@Date,120)	
       RETURN @Return
    END
GO
