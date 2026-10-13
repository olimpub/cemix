/****** Object:  StoredProcedure [dbo].[spListPartners]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spListPartners](
	@SiteCode VARCHAR(10),
	@Page SMALLINT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN
DECLARE @TransferType SMALLINT,
		@URL NVARCHAR(1000),
		@Header NVARCHAR(MAX),
		@Body NVARCHAR(MAX),
		@MsgType VARCHAR(100),
		@MsgMethod VARCHAR(100),
		@ResponseAccept VARCHAR(100),
		@Msg NVARCHAR(MAX),
		@Token VARCHAR(100),
		@TransferID INT,
		@Filter NVARCHAR(500)



IF(@Page<>1)
BEGIN
	SET @Filter='?page%5Bnumber%5D='+CAST(@Page AS varchar(3))
END
ELSE
BEGIN
	DELETE FROM [dbo].[tblGLABsPartnerImport] WHERE SiteCode=@SiteCode
	SET @Filter=''
END


SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/partners'+@Filter FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListPartners','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,25,@TransferID
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType=''
SET @MsgMethod='GET'

SET @TransferType=20

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0

SELECT @TransferID=SCOPE_IDENTITY()

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListPartners','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,25,@TransferID

	RETURN
END
ELSE
BEGIN
		DECLARE @MaxPage SMALLINT
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		
		/*
		SELECT id,PartnerName
		FROM OPENJSON(@Msg,'$.data')
		WITH (
			id VARCHAR(50) '$.id',
			PartnerName VARCHAR(50) '$.attributes.name'
		);*/

		INSERT INTO [dbo].[tblGLABsPartnerImport]
           ([PartnerID]
           ,[PartnerType]
           ,[PartnerCode]
           ,[PartnerName]
           ,[PartnerCountry]
           ,[PartnerCity]
           ,[PartnerAddress]
           ,[PartnerPhone]
           ,[PartnerMail]
           ,[PartnerZIP]
           ,[SiteCode]
           ,[ProfileID]
           ,[ProfileMail]
           ,[ProfileName]
           ,[TaxNumber]
           ,[siteId])
		SELECT 
			[PartnerID]
           ,[PartnerType]
           ,[PartnerCode]
           ,[PartnerName]
           ,[PartnerCountry]
           ,[PartnerCity]
           ,[PartnerAddress]
           ,[PartnerPhone]
           ,[PartnerMail]
           ,[PartnerZIP]
           ,[SiteCode]
           ,[ProfileID]
           ,[ProfileMail]
           ,[ProfileName]
           ,[TaxNumber]
           ,[siteId]
		FROM OPENJSON(@Msg,'$.data')
		WITH (
			[PartnerID] [varchar](50) '$.id',
			[PartnerType] [varchar](15) '$.attributes.type',
			[PartnerCode] [varchar](50) '$.attributes.code',
			[PartnerName] [nvarchar](300) '$.attributes.name',
			[PartnerCountry] [varchar](3) '$.attributes.address.countryCode',
			[PartnerCity] [nvarchar](150) '$.attributes.address.city',
			[PartnerAddress] [nvarchar](1000) '$.attributes.address.street',
			[PartnerPhone] [varchar](100) '$.attributes.phone',
			[PartnerMail] [varchar](500) '$.attributes.email',
			[PartnerZIP] [varchar](15) '$.attributes.address.postCode',
			[SiteCode] [varchar](15) '$.attributes.owner.siteCode',
			[ProfileID] [varchar](50) '$.attributes.profile.id',
			[ProfileMail] [varchar](300) '$.attributes.profile.email',
			[ProfileName] [nvarchar](300) '$.attributes.profile.name',
			[TaxNumber] [varchar](30) '$.attributes.profile.taxNumber',
			[siteId] [varchar](30) '$.attributes.profile.siteCode'
		)


		IF(@Page=1)
		BEGIN
			SELECT @MaxPage=PageNo
			FROM OPENJSON(@Msg)
			WITH (
				PageNo SMALLINT '$.meta.pagination.pageTotal'
			);
					   
			IF(@Page<>@MaxPage)
			BEGIN
				SET @Page=@Page+1
				--Loop for further pages
				WHILE(@Page<=@MaxPage)
				BEGIN
					EXECUTE [dbo].[spListPartners]
						@SiteCode=@SiteCode,
						@Page=@Page,
						@SuccessFlg=@SuccessFlg
					SET @Page=@Page+1
				END
			END

		END
END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListPartners','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,1,25,@TransferID

	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListPartners','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,25,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
