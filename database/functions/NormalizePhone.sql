/****** Object:  UserDefinedFunction [dbo].[NormalizePhone]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[NormalizePhone]
(
    @Phone nvarchar(100)
)
RETURNS varchar(17)
AS
BEGIN
    IF @Phone IS NULL
        RETURN NULL;

    DECLARE @Digits varchar(100) = '';
    DECLARE @i int = 1;
    DECLARE @c nchar(1);

    -- Formázó karakterek eltávolítása, csak a számjegyek megtartása
    WHILE @i <= LEN(@Phone)
    BEGIN
        SET @c = SUBSTRING(@Phone, @i, 1);

        IF @c >= N'0' AND @c <= N'9'
            SET @Digits += @c;

        SET @i += 1;
    END;

    -- Magyar belföldi előtag: 06 → 36
    IF LEFT(@Digits, 2) = '06'
        SET @Digits = '+36' + SUBSTRING(@Digits, 3, 100);

    -- Nemzetközi 00 előtag: 00 → elhagyjuk
    ELSE IF LEFT(@Digits, 2) = '00'
        SELECT @Digits ='+' + SUBSTRING(@Digits, 3, 100);

	ELSE
		SELECT @Digits ='+'+@Digits;

    -- Az E.164 formátum legfeljebb 15 számjegyű
    IF LEN(@Digits) < 8 OR LEN(@Digits) > 15
        SET @Digits='';

    RETURN @Digits;
END;
GO
