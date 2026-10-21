/****** Object:  StoredProcedure [dbo].[spGetStationInProgress]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spGetStationInProgress](
	@SiteCode VARCHAR(10),
	@StationID VARCHAR(30),
	@SuccessFlg BIT OUT,
	@InProgressFlg BIT OUT
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
		@CargoID VARCHAR(50),
		@RowID VARCHAR(50),
		@Filter NVARCHAR(200)

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/stations/'+@StationID FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spGetStationInProgress','@SiteCode='+@SiteCode+',@StationID='+@StationID,'',@Msg,0
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType=''
SET @MsgMethod='GET'

SELECT TOP 1 @TransferType = tt.id FROM tblTransferType tt WHERE tt.TransferType='Get Station'

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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spGetStationInProgress','@SiteCode='+@SiteCode+',@StationID='+@StationID,'',@Msg,0
	RETURN
END
ELSE
BEGIN
		DECLARE @MaxPage SMALLINT,@Stage VARCHAR(50),@PickingStatus VARCHAR(500), @CurrentStatus VARCHAR(500)
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID

		SELECT @PickingStatus = currentPickingStatus, @CurrentStatus=currentStatus
		FROM OPENJSON(@Msg,'$.data')
		WITH (
				currentPickingStatus VARCHAR(100) '$.attributes.picking.current.name',
				currentStatus VARCHAR(100) '$.attributes.stage.current.name'

			);
		
		IF(ISNULL(@PickingStatus,'')<>'inprogress' AND ISNULL(@CurrentStatus,'')<>'loading')
		BEGIN
			SET @InProgressFlg=0
		END
		ELSE
		BEGIN
			SET @InProgressFlg=1
		END


END
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spGetStationInProgress','@SiteCode='+@SiteCode+',@StationID='+@StationID,'',@Msg,1
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spGetStationInProgress','@SiteCode='+@SiteCode+',@StationID='+@StationID,'',@Msg,0
	SET @SuccessFlg=0
END CATCH
END
GO
