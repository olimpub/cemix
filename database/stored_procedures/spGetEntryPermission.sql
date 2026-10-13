/****** Object:  StoredProcedure [dbo].[spGetEntryPermission]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[spGetEntryPermission](
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
		@Filter NVARCHAR(500),
		@CurrentDate VARCHAR(30),
		@OriginalPage INT
		
	SELECT @CurrentDate =[dbo].[spGetUnixTimestamp](GETDATE())
	SET @OriginalPage=@Page


IF(@Page<>1)
BEGIN
	SET @Filter='&page%5Bnumber%5D='+CAST(@Page AS varchar(3))
END
ELSE
BEGIN
	SET @Filter=''
END

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/entry-permissions?filter[actual]=1'+@Filter FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spGetEntryPermission','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,22,@TransferID
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType=''
SET @MsgMethod='GET'

SET @TransferID=99   ----NEED TO ADD

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0

SELECT @TransferID=SCOPE_IDENTITY()

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

--SELECT @TransferID

IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spGetEntryPermission','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,22,@TransferID

	RETURN
END
ELSE
BEGIN
		DECLARE @MaxPage SMALLINT
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		
		DECLARE @Entry TABLE(
			id VARCHAR(50),
			PlateNo1 VARCHAR(50)
		)
		INSERT INTO @Entry(id,PlateNo1)
		SELECT PermissionID, LicensePlateNo1
		FROM OPENJSON(@Msg,'$.data')
		WITH (
			PermissionID NVARCHAR(100) '$.id',
			LicensePlateNo1 NVARCHAR(50) '$.attributes.plateNumber'
		);
		
		--SELECT * FROM @Entry

		IF(@Page=1)
		BEGIN
			DELETE FROM tblActivePlates WHERE SiteCode=@SiteCode AND SourceID=3
		END 

		INSERT INTO tblActivePlates(SiteCode,PlateNo,SourceID,EntryDate)
		SELECT @SiteCode, c.PlateNo1,3,GETDATE() FROM @Entry c
		WHERE c.PlateNo1 IS NOT NULL



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
					EXECUTE [dbo].[spGetEntryPermission]
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
SELECT 'spGetEntryPermission','@SiteCode='+@SiteCode+',@Page='+CAST(@OriginalPage AS varchar(10)),'',@Msg,1,22,@TransferID

SET @SuccessFlg=1

END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spGetEntryPermission','@SiteCode='+@SiteCode+',@Page='+CAST(@OriginalPage AS varchar(10)),'',@Msg,0,22,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
