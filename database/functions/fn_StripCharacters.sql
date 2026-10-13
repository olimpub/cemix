/****** Object:  UserDefinedFunction [dbo].[fn_StripCharacters]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fn_StripCharacters]
(
    @String NVARCHAR(MAX), 
    @MatchExpression VARCHAR(255)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    SET @MatchExpression =  '%['+@MatchExpression+']%'
    
    WHILE PatIndex(@MatchExpression, @String) > 0
        SET @String = Stuff(@String, PatIndex(@MatchExpression, @String), 1, '')
    
    RETURN @String
    
END
GO
