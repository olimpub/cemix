/****** Object:  UserDefinedFunction [dbo].[fnBase64DecodeXML]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnBase64DecodeXML](@input NVARCHAR(MAX))
RETURNS VARBINARY(MAX)
AS
BEGIN
    DECLARE @BinaryValue VARBINARY(MAX);

    -- Check if the input is NULL or empty
    IF @input IS NULL OR @input = ''
    BEGIN
        RETURN NULL;
    END

    -- Decode the Base64 string into VARBINARY
    SET @BinaryValue = CAST('' AS XML).value('xs:base64Binary(sql:variable("@input"))', 'VARBINARY(MAX)');

    RETURN @BinaryValue;
END;
GO
