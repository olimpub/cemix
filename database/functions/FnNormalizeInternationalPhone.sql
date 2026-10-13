/****** Object:  UserDefinedFunction [dbo].[FnNormalizeInternationalPhone]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   FUNCTION [dbo].[FnNormalizeInternationalPhone] (@Phone nvarchar(100))
RETURNS varchar(32)
AS
BEGIN
    IF @Phone IS NULL
        RETURN NULL;

    DECLARE @Digits varchar(100) = '';
    DECLARE @i int = 1;
    DECLARE @c char(1);

    -- Csak a számjegyek megtartása
    WHILE @i <= LEN(@Phone)
    BEGIN
        SET @c = SUBSTRING(@Phone, @i, 1);

        IF @c >= '0' AND @c <= '9'
            SET @Digits += @c;

        SET @i += 1;
    END;

    -- Nemzetközi hívóelőtag átalakítása
    IF LEFT(@Digits, 2) = '00'
        SET @Digits = SUBSTRING(@Digits, 3, 100);

    -- Országkód nélkül nem lehet biztosan nemzetközi számot készíteni
    IF LEN(@Digits) < 8 OR LEN(@Digits) > 15
        RETURN NULL;

    RETURN '+' + @Digits;
END;
GO
