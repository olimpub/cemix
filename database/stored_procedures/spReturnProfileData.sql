/****** Object:  StoredProcedure [dbo].[spReturnProfileData]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--Create function returns by name, partnerCode,taxID
CREATE PROCEDURE [dbo].[spReturnProfileData](
	@PartnerName NVARCHAR(300),
	@PartnerCode VARCHAR(50),
	@TaxID VARCHAR(50),
	@ProfileID VARCHAR(50) OUT,
	@TaxOut VARCHAR(50) OUT,
	@SiteOut VARCHAR(50) OUT
)
AS
BEGIN
--partnercode exists as TaxID
IF EXISTS(SELECT * FROM tblProfile tp WHERE tp.TaxNumber=@PartnerCode AND tp.ActiveFlg=1)
BEGIN
	SELECT TOP 1 @TaxOut = tp.TaxNumber, @SiteOut = tp.SiteCode, @ProfileID=tp.ProfileID FROM tblProfile tp WHERE tp.TaxNumber=@PartnerCode AND tp.ActiveFlg=1
	RETURN
END

--partner code exists as SiteCode
IF EXISTS(SELECT * FROM tblProfile tp WHERE tp.SiteCode=@PartnerCode AND tp.ActiveFlg=1)
BEGIN
	SELECT TOP 1 @TaxOut = tp.TaxNumber, @SiteOut = tp.SiteCode, @ProfileID=tp.ProfileID FROM tblProfile tp WHERE tp.SiteCode=@PartnerCode AND tp.ActiveFlg=1
	RETURN
END


--TaxID exists without site code
IF EXISTS(SELECT * FROM tblProfile tp WHERE tp.TaxNumber=@TaxID AND ISNULL(tp.SiteCode,'')='' AND tp.ActiveFlg=1)
BEGIN
	SELECT @TaxOut = tp.TaxNumber, @SiteOut = tp.SiteCode, @ProfileID=tp.ProfileID FROM tblProfile tp WHERE tp.TaxNumber=@TaxID AND ISNULL(tp.SiteCode,'')='' AND tp.ActiveFlg=1
	RETURN
END

--TaxID exists with 001 sitecode
IF EXISTS(SELECT * FROM tblProfile tp WHERE tp.TaxNumber=@TaxID AND ISNULL(tp.SiteCode,'')='001' AND tp.ActiveFlg=1)
BEGIN
	SELECT @TaxOut = tp.TaxNumber, @SiteOut = tp.SiteCode, @ProfileID=tp.ProfileID FROM tblProfile tp WHERE tp.TaxNumber=@TaxID AND ISNULL(tp.SiteCode,'')='001' AND tp.ActiveFlg=1
	RETURN
END


--Tax ID Exists with different site code but same name
IF EXISTS(SELECT * FROM tblProfile tp WHERE tp.TaxNumber=@TaxID AND tp.ProfileName=@PartnerName AND tp.ActiveFlg=1)
BEGIN
	SELECT @TaxOut = tp.TaxNumber, @SiteOut = tp.SiteCode, @ProfileID=tp.ProfileID FROM tblProfile tp WHERE tp.TaxNumber=@TaxID AND tp.ProfileName=@PartnerName AND tp.ActiveFlg=1
	RETURN
END

END
GO
