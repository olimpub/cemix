/****** Object:  StoredProcedure [dbo].[spCreateCall]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spCreateCall](
	@SiteCode VARCHAR(15),
	@StationID VARCHAR(50),
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
		@ShipmentStatus	SMALLINT,
		@TransportNo VARCHAR(20),
		@TransportID INT,
		@RampID INT

SELECT @TransportNo=ts.TransportID, @TransportID = ts.id, @RampID=tr.id FROm tblShipment ts 
INNER JOIN tblRamp tr on tr.id=ts.RampID
WHERE ts.StationID=@StationID
SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/calls' FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,24,@TransportNo,@TransferID
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='POST'


SET @TransferType=19

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@TransportID

SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
EXECUTE spCreateCallBody
		@TransferID=@TransferID,
		@StationID=@StationID,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

--PRINT @Body

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Body create Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,24,@TransportNo,@TransferID
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
	SELECT 'spCreateCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,24,@TransportNo,@TransferID

	--Here to update table, call failed
	UPDATE ts
	SET ts.CallStatus=2
	FROM tblShipment ts
	WHERE id=@TransportID
	RETURN

END
ELSE
BEGIN
	--Here to update table, call delete success
			DECLARE @RCallID VARCHAR(50)
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		--Save IDs
		SELECT @RCallID = CallID
		FROM OPENJSON(@Msg)
		WITH (
			CallID NVARCHAR(50) '$.data.id'
		);

		SET @GLABsID=@RCallID
		SELECT @RCallID AS 'CallID', @TransportID, @RampID
		UPDATE ts
		SET ts.CallStatus=1,ts.CallID=@RCallID
		FROM tblShipment ts
		WHERE id=@TransportID	

		UPDATE tr
		SET tr.CallID=@RCallID
		FROM tblRamp tr
		WHERE tr.id=@RampID


END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,1,24,@TransportNo,@TransferID
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tblRamp
	SET DeleteStatus=2
	WHERE id=@RampID

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateCall','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,1,24,@TransportNo,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
