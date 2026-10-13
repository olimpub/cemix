/****** Object:  StoredProcedure [dbo].[spTokenRequest]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spTokenRequest](
	@SiteCode VARCHAR(10),
	@TransferID INT OUT,
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
		@Msg NVARCHAR(MAX)

SELECT @Body='grant_type=client_credentials&client_id='+tcpr.client_id+'&client_secret='+tcpr.client_secret+'&scope=partners shipments shipping.queue.get_queue entry' ,
--SELECT @Body='grant_type=client_credentials&client_id=FYyDjUzNHVXYtdUIlMTImLB2lmgzfWft&client_secret=UC0ucuGkzMzkwPkFqQURuxPKCA6Dekee1ZueZ6w5wcW55r0Yce3pgSRZJ10ZW757&scope=user.profiles profile.shipments profile.shipment.data.update profile.shipment.checkin profile.shipment.crossings profile.shipment.staging profile.partners profile.shipment.call' ,
@URL=tcpr.[url]
FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

SET @URL=@URL+'oauth/token'
SET @Header=''
SET @ResponseAccept='application/json'
SET @MsgType='application/x-www-form-urlencoded'
SET @MsgMethod='POST'
SELECT TOP 1 @TransferType = tt.id FROM tblTransferType tt WHERE tt.TransferType='Token'

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status)
SELECT @TransferType,@URL,@Header,@Body,@MsgType,@MsgMethod,@ResponseAccept,0

SELECT @TransferID=SCOPE_IDENTITY()

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spTokenRequest',('@SiteCode='+@SiteCode),'@TransferID'+ISNULL(CAST(@TransferID AS VARCHAR(20)),'NULL'),@Msg,1
END
ELSE
BEGIN
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		--Save Token
		INSERT INTO tblToken(access_token,refresh_token,token_type,ExpiryDate)
		SELECT access_token,refresh_token,token_type,DATEADD(ss,expires_in,GETDATE())
		FROM OPENJSON(@Msg)
		WITH (
			access_token NVARCHAR(300) '$.access_token',
			refresh_token NVARCHAR(300) '$.refresh_token',
			token_type NVARCHAR(300) '$.token_type',
			expires_in INT '$.expires_in'
		);
END
INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
SELECT 'spTokenRequest',('@SiteCode='+@SiteCode),'@TransferID='+ISNULL(CAST(@TransferID AS VARCHAR(20)),'NULL'),'',1
END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spTokenRequest',('@SiteCode='+@SiteCode),'@TransferID='+ISNULL(CAST(@TransferID AS VARCHAR(20)),'NULL'),@Msg,1
END CATCH
END
GO
