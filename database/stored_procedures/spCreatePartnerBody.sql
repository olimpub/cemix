/****** Object:  StoredProcedure [dbo].[spCreatePartnerBody]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--Change GLABsBody logic
CREATE PROCEDURE [dbo].[spCreatePartnerBody](
	@TransferID INT,
	@PartnerID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

DECLARE 
	@PartnerType [smallint], 
	@PartnerCode [varchar](50),
	@PartnerName [nvarchar](300),
	@PartnerCountry [varchar](3),
	@PartnerCity [nvarchar](150),
	@PartnerAddress [nvarchar](1000),
	@PartnerPhone [varchar](100),
	@PartnerMail [varchar](500),
	@PartnerZIP [varchar](15),
	@PartnerTaxID [varchar](30),
	@GLABSID [varchar](50),
	@PlantCode [varchar](50),
	@ProfileFlg [bit],
    @ProfileID varchar(50),
	@TaxOut varchar(50),
	@SiteOut varchar(50)

	SELECT @PartnerType = tpr.PartnerType, @PartnerCode=tpr.PartnerCode, @PartnerName=tpr.PartnerName, @PartnerCountry=tpr.PartnerCountry, @PartnerCity=ISNULL(tpr.PartnerCity,'N/A'), @PartnerAddress=ISNULL(tpr.PartnerAddress,'N/A'), @PartnerPhone = ISNULL(tpr.PartnerPhone,'N/A'), 
	@PartnerMail=tpr.PartnerMail,@PartnerTaxID=ISNULL(tpr.TaxID,''),
	@PartnerZIP=tpr.PartnerZIP, @GLABSID = tpr.GLABsID, @PlantCode=tpr.PlantCode, @ProfileFlg=tpr.ProfileFlg
	FROM [dbo].[tblPartner] tpr WHERE tpr.id=@PartnerID

	IF(@PartnerTaxID='')
	BEGIN
		SET @PartnerTaxID=@PartnerCode
	END

	--CheckProfileID
	IF(@ProfileFlg=1)
	BEGIN
		EXECUTE  [dbo].[spReturnProfileData] 
		   @PartnerName=@PartnerName
		  ,@PartnerCode=@PartnerCode
		  ,@TaxID=@PartnerTaxID
		  ,@ProfileID=@ProfileID OUTPUT
		  ,@TaxOut=@TaxOut OUTPUT
		  ,@SiteOut=@SiteOut OUTPUT

		IF(@ProfileID IS NOT NULL)
		BEGIN
			SELECT @PartnerTaxID=@TaxOut, @PlantCode=@SiteOut
		END

	END

	DELETE FROM JSONText WHERE TransferID=@TransferID

INSERT INTO JSONText
SELECT @TransferID,'data.type','''partners''',''
IF(@GLABSID iS NOT NULL)
BEGIN
	
INSERT INTO JSONText
SELECT @TransferID,'data.id',''''+@GLABSID+'''','' 
END

IF(@PartnerType=1)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.type','''partner''',''  --Define partner logic later
END
ELSE IF(@PartnerType=2)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.type','''organizer''',''  --Define partner logic later
END
ELSE IF (@PartnerType=3)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.type','''carrier''',''  --Define partner logic later
END

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.name',''''+REPLACE(@PartnerName,'''','')+'''','' 
/*
IF(@ProfileFlg=1)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.code',''''+REPLACE(@PlantCode,'''','')+'''','' 
END
IF(@ProfileFlg=0)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.code',''''+REPLACE(@PartnerCode,'''','')+'''','' 
END
*/--Out On 2022.07.24.
INSERT INTO JSONText
SELECT @TransferID,'data.attributes.code',''''+REPLACE(@PartnerCode,'''','')+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.email',''''+ISNULL(@PartnerMail,'')+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.phone',''''+ISNULL(@PartnerPhone,'')+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.address.countryCode',''''+REPLACE(@PartnerCountry,'''','')+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.address.county',''''+REPLACE(@PartnerCity,'''','')+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.address.city',''''+REPLACE(@PartnerCity,'''','')+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.address.street',''''+REPLACE(@PartnerAddress,'''','')+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.address.postCode',''''+REPLACE(@PartnerZIP,'''','')+'''','' 

------------
--Add profile data
IF(@ProfileFlg=1 AND @GLABSID IS NULL)
BEGIN

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.profile.taxNumber',''''+@PartnerTaxID+'''','' 	

IF(@PlantCode IS NOT NULL)
BEGIN
INSERT INTO JSONText
SELECT @TransferID,'data.attributes.profile.siteCode',''''+@PlantCode+'''','' 	
END
ELSE
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.profile.siteCode','null','' 	
END

IF(LOWER(@PartnerCountry)='hu')
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.profile.locale','''hu''','' 	
END
ELSE IF(LOWER(@PartnerCountry)='pl')
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.profile.locale','''pl''','' 	
END
ELSE IF(LOWER(@PartnerCountry)='ro')
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.profile.locale','''ro''','' 	
END
ELSE IF(LOWER(@PartnerCountry)='at')
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.profile.locale','''de''','' 	
END
ELSE IF(LOWER(@PartnerCountry)='de')
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.profile.locale','''de''','' 	
END
ELSE
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.profile.locale','''en''','' 	
END

END

BEGIN TRY
DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL=COALESCE(@SQL, '','') +js.JsonText +' AS "' +js.JsonField +'",' FROM JSONText js
WHERE js.TransferID=@TransferID
ORDER BY js.RowID


SELECT @SQL=N'SELECT @JSON=(SELECT '+LEFT(@SQL,LEN(@SQL)-1)+' FOR JSON PATH)'

DECLARE @params NVARCHAR(250)
SET @Params='@JSON NVARCHAR(MAX) OUTPUT'
PRINT @SQL
EXEC sp_executesql @SQL,@Params, @JSON=@Body OUTPUT

SELECT @Body=LEFT(@Body,LEN(@Body)-1)
SELECT @Body=RIGHT(@Body,LEN(@Body)-1)

SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SET @SuccessFlg=0
END CATCH

END
GO
