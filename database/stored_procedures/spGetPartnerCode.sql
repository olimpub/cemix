/****** Object:  StoredProcedure [dbo].[spGetPartnerCode]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spGetPartnerCode](
	@PartnerCode VARCHAR(50),
	@PartnerName VARCHAR(300),
	@PartnerOut VARCHAR(50) OUT
)
AS 
BEGIN
DECLARE @TransferID INT,@XML XML,@Direction VARCHAR(5),@AddressCode VARCHAR(10)

SELECT @TransferID=MAX(TransferID) FROm tblTransferTransportArchive WHERE CarrierCode=@PartnerCode AND CarrierName=@PartnerName

IF(@TransferID IS NOT NULL)
BEGIN
	SELECT @XML=BodyXML FROM tblTransferIn WHERE id=@TransferID
		SELECT @Direction = f.m.value('(ABFER)[1]' ,'VARCHAR(5)')
	FROM @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20') as f(m)
		SELECT @AddressCode = CASE WHEN @Direction IN('1','3') THEN 'AG' ELSE 'LF' END

		SELECT @PartnerOut= c.m.value('(PARTNER_ID)[1]' ,'VARCHAR(50)')
		FROM @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1ADRM4') as c(m)
		WHERE c.m.value('(PARTNER_Q)[1]' ,'VARCHAR(50)')='SP'
		AND c.m.value('(YE1ADRM4_GLABS/STCD1)[1]' ,'VARCHAR(50)')=@PartnerCode
END
END
GO
