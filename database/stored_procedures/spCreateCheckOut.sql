/****** Object:  StoredProcedure [dbo].[spCreateCheckOut]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCreateCheckOut](
	@SiteCode VARCHAR(15),
	@TransportID INT,
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
		@StationID VARCHAR(50),
		@ShipmentStatus	SMALLINT,
		@TransportNo VARCHAR(20)

SELECT @StationID=ts.StationID, @ShipmentStatus=ts.ShipmentStatus, @TransportNo = ts.TransportID FROM tblShipment ts WHERE ts.id=@TransportID
SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/stations/'+@StationID+'/checkout' FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateCheckOut','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,17,@TransportNo,@TransferID
	
	UPDATE ts
	SET  ts.AutoCheckOutFlg=0
	FROM tblShipment ts
	WHERE ts.id=@TransportID 
	
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='PUT'


SET @TransferType=13

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0

SELECT @TransferID=SCOPE_IDENTITY()

--Update Body
UPDATE tblTransferOut
SET Body=''
WHERE id=@TransferID

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateCheckOut','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0,17,@TransportNo,@TransferID

	UPDATE ts
	SET  ts.AutoCheckOutFlg=0
	FROM tblShipment ts
	WHERE ts.id=@TransportID 
	RETURN

END
ELSE
BEGIN
		DECLARE @RResult VARCHAR(50)
		
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
--Save IDs
		SELECT @RResult=Success
		FROM OPENJSON(@Msg)
		WITH (
			Success NVARCHAR(100) '$.success'
		);
		
		SET @GLABsID=@RResult

		IF(@RResult<>'true')
		BEGIN
			SET @Msg='WebRequest Failed'
			INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
			SELECT 'spCreateCheckOut','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0,17,@TransportNo,@TransferID

			SET @SuccessFlg=0
			UPDATE ts
			SET  ts.AutoCheckOutFlg=0
			FROM tblShipment ts
			WHERE ts.id=@TransportID 
			RETURN
		END
		ELSE
		BEGIN
			UPDATE ts
			SET  ts.AutoCheckOutFlg=1
			FROM tblShipment ts
			WHERE ts.id=@TransportID 
		END
	

END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateCheckOut','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,1,17,@TransportNo,@TransferID
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE ts
	SET  ts.AutoCheckOutFlg=0
	FROM tblShipment ts
	WHERE ts.id=@TransportID 

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateCheckOut','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0,17,@TransportNo,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
