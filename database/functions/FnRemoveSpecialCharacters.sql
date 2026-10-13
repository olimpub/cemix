/****** Object:  UserDefinedFunction [dbo].[FnRemoveSpecialCharacters]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[FnRemoveSpecialCharacters](@Input NVARCHAR(200))
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @Output NVARCHAR(MAX) = ''
    DECLARE @i INT = 1
    DECLARE @Char NCHAR(1)

    WHILE @i <= LEN(@Input)
    BEGIN
        SET @Char = SUBSTRING(@Input, @i, 1)
        -- Keep only letters (A-Z, a-z) and digits (0-9)
        IF (@Char LIKE '[A-Za-z0-9]')
            SET @Output = @Output + @Char
        SET @i = @i + 1
    END

    RETURN @Output
END
GO
