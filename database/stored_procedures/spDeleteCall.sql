/****** Object:  StoredProcedure [dbo].[spDeleteCall]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spDeleteCall](
	@SiteCode VARCHAR(15),
	@StationID VARCHAR(50),
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
		@ShipmentStatus	SMALLINT,
		@TransportNo VARCHAR(20),
		@TransportID INT,
		@RampID INT

SELECT @TransportNo=ts.TransportID, @TransportID = ts.id, @RampID=tr.id FROm tblShipment ts 
INNER JOIN tblRamp tr on tr.CallID=ts.CallID
WHERE ts.StationID=@StationID
SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/stations/'+@StationID+'/call' FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,0,23,@TransportNo,@TransferID
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='PATCH'


SET @TransferType=18

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@TransportID

SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
EXECUTE spDeleteCallBody
		@TransferID=@TransferID,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

--PRINT @Body

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Body create Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,0,23,@TransportNo,@TransferID
	
	UPDATE tblRamp
	SET DeleteStatus=2
	WHERE id=@RampID
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
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,0,23,@TransportNo,@TransferID

	--Here to update table, delete failed
	UPDATE tblRamp
	SET DeleteStatus=2
	WHERE id=@RampID

	UPDATE tblShipment
	SET  CallStatus=2
	WHERE TransportID=@TransportNo
	RETURN

END
ELSE
BEGIN
	--Here to update table, call delete success
	UPDATE tblRamp
	SET DeleteStatus=1,CallID=NULL
	WHERE id=@RampID	

	UPDATE tblShipment
	SET CallID=NULL, RampID=NULL, CallStatus=NULL
	WHERE TransportID=@TransportNo
END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,1,23,@TransportNo,@TransferID
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tblRamp
	SET DeleteStatus=2
	WHERE id=@RampID

	UPDATE tblShipment
	SET  CallStatus=2
	WHERE StationID=@StationID

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,0,23,@TransportNo,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
