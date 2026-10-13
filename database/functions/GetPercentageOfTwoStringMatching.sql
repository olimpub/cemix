/****** Object:  UserDefinedFunction [dbo].[GetPercentageOfTwoStringMatching]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetPercentageOfTwoStringMatching]
(
    @string1 NVARCHAR(100)
    ,@string2 NVARCHAR(100)
)
RETURNS INT
AS
BEGIN

    DECLARE @levenShteinNumber INT

    DECLARE @string1Length INT = LEN(@string1)
    , @string2Length INT = LEN(@string2)
    DECLARE @maxLengthNumber INT = CASE WHEN @string1Length > @string2Length THEN @string1Length ELSE @string2Length END

    SELECT @levenShteinNumber = [dbo].[LEVENSHTEIN] (   @string1  ,@string2)

    DECLARE @percentageOfBadCharacters INT = @levenShteinNumber * 100 / @maxLengthNumber

    DECLARE @percentageOfGoodCharacters INT = 100 - @percentageOfBadCharacters

    -- Return the result of the function
    RETURN @percentageOfGoodCharacters

END


GO
