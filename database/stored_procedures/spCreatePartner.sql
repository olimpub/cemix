/****** Object:  StoredProcedure [dbo].[spCreatePartner]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--Modify Create partner sp to store
CREATE PROCEDURE [dbo].[spCreatePartner](
	@SiteCode VARCHAR(15),
	@PartnerID INT,
	@GLABsID VARCHAR(50) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN
DECLARE @TransferType SMALLINT,
		@URL VARCHAR(1000),
		@Header NVARCHAR(MAX),
		@Body NVARCHAR(MAX),
		@MsgType VARCHAR(100),
		@MsgMethod VARCHAR(100),
		@ResponseAccept VARCHAR(100),
		@Msg NVARCHAR(MAX),
		@Token VARCHAR(100),
		@TransferID INT,
		@ID VARCHAR(50)

SELECT @ID=tp.GLABsID FROM tblPartner tp WHERE tp.id=@PartnerID

IF(@ID IS NULL)
BEGIN
	SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/partners' FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
END
ELSE
BEGIN
	SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/partners/'+@ID FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
END

SELECT @ID,@URL


--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,PartnerID)
	SELECT 'spCreatePartner','@SiteCode='+@SiteCode+',@PartnerID='+CAST(@PartnerID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,3,@PartnerID
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
IF(@ID IS NULL)
BEGIN
	SET @MsgMethod='POST'
END
ELSE
BEGIN
	SET @MsgMethod='PATCH'
END


SET @TransferType=1

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@PartnerID

SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
EXECUTE spCreatePartnerBody
		@TransferID=@TransferID,
		@PartnerID=@PartnerID,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Body create Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,PartnerID,TransferOut)
	SELECT 'spCreatePartner','@SiteCode='+@SiteCode+',@PartnerID='+CAST(@PartnerID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,3,@PartnerID,@TransferID
	RETURN
END
--Update Body
UPDATE tblTransferOut
SET Body=@Body
WHERE id=@TransferID

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0)
BEGIN
	
	UPDATE tblPartner
	SET [Status]=2
	WHERE id=@PartnerID

	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,PartnerID,TransferOut)
	SELECT 'spCreatePartner','@SiteCode='+@SiteCode+',@PartnerID='+CAST(@PartnerID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,3,@PartnerID,@TransferID
	RETURN;
END
ELSE
BEGIN
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		--Save ID
		SELECT @GLABsID=GLABsID
		FROM OPENJSON(@Msg)
		WITH (
			GLABsID NVARCHAR(100) '$.data.id'
		);

		
		DECLARE @RProfileID [varchar](50),@RProfileMail [varchar](300),@RProfileName [nvarchar](300),@RTaxNumber [varchar](30),@RSiteCode [varchar](30)

		SELECT @RProfileID=[ProfileID], @RProfileMail=[ProfileMail] ,@RProfileName=[ProfileName], @RTaxNumber=[TaxNumber],@RSiteCode=[SiteCode]
		FROM OPENJSON(@Msg)
		WITH (
				[ProfileID] [varchar](50)  '$.data.attributes.profile.id',
				[ProfileMail] [varchar](300)  '$.data.attributes.profile.email',
				[ProfileName] [nvarchar](300) '$.data.attributes.profile.name',
				[TaxNumber] [varchar](30) '$.data.attributes.profile.taxNumber',
				[SiteCode] [varchar](30)  '$.data.attributes.profile.siteCode'
		);

		UPDATE tblPartner
		SET GLABsID=@GLABsID,[Status]=1, ProfileID=@RProfileID
		WHERE id=@PartnerID

		IF NOT EXISTS(SELECT * FROM tblProfile tpr WHERE tpr.ProfileID=@RProfileID)
		BEGIN
			INSERT INTO tblProfile(ProfileID,ProfileMail,ProfileName,TaxNumber,SiteCode,ActiveFlg)
			SELECT @RProfileID, @RProfileMail, @RProfileName, @RTaxNumber, @RSiteCode, CASE WHEN @RSiteCode LIKE '%DELETE%' THEN 0 ELSE 1 END
		END
END
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,PartnerID,TransferOut)
	SELECT 'spCreatePartner','@SiteCode='+@SiteCode+',@PartnerID='+CAST(@PartnerID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),'',1,3,@PartnerID,@TransferID
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tblPartner
	SET [Status]=2
	WHERE id=@PartnerID

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,PartnerID,TransferOut)
	SELECT 'spCreatePartner','@SiteCode='+@SiteCode+',@PartnerID='+CAST(@PartnerID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0,3,@PartnerID,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
