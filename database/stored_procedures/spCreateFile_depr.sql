/****** Object:  StoredProcedure [dbo].[spCreateFile_depr]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



----Document transfer
CREATE PROCEDURE [dbo].[spCreateFile_depr](
	@DocumentID INT,
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
		@Direction BIT,
		@TransportNo VARCHAR(50),
		@ShipmentID VARCHAR(50),
		@CargoID VARCHAR(50),
		@DeliveryNo VARCHAR(50),
		@SiteCode VARCHAR(10),
		@DocumentType VARCHAR(50),
		@TransportID INT

SELECT @TransportNo= sd.TransportID, @DeliveryNo = sd.DeliveryNo, @ShipmentID=sd.GLABsID, @DocumentType=sd.GLABsID FROM tblShipmentDocument sd WHERE sd.id=@DocumentID
SELECT @CargoID=tc.GLABsID FROM tblCargo tc WHERE tc.TransportID=@TransportNo AND tc.DeliveryNo=@DeliveryNo

SELECT @SiteCode=SiteCode,@TransportID =id FROM tblTransport WHERE TransportNo=@TransportNo

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/shipments/cargos/'+@CargoID+'/documents' FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
SELECT @URL=REPLACE(@URL,'#','%23')

SELECT @URL AS 'URL', @CargoID AS CargoID

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, TransportNo,TransferOut,ProcessID)
	SELECT 'spCreateFile','@SiteCode='+@SiteCode+',@DocumentID='+CAST(@DocumentID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0, @TransportNo,@TransferID,19
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'

--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='POST'


SET @TransferType=15

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0, @TransportID

SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
EXECUTE spCreateFileBody
		@TransferID=@TransferID,
		@DocumentID=@DocumentID,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

--PRINT @Body

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Body create Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, TransportNo,TransferOut,ProcessID)
	SELECT 'spCreateFile','@SiteCode='+@SiteCode+',@DocumentID='+CAST(@DocumentID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0, @TransportNo,@TransferID,19
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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, TransportNo,TransferOut,ProcessID)
	SELECT 'spCreateFile','@SiteCode='+@SiteCode+',@DocumentID='+CAST(@DocumentID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0, @TransportNo,@TransferID,19
	RETURN
END
ELSE
BEGIN
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		--Save IDs
		SELECT @GLABsID = DocumentID
		FROM OPENJSON(@Msg)
		WITH (
			DocumentID NVARCHAR(100) '$.data.id'
		);

		
	UPDATE tblShipmentDocument
	SET DocumentStatus=1, DocumentID=@GLABsID
	WHERE id=@DocumentID
END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, TransportNo,TransferOut,ProcessID)
	SELECT 'spCreateFile','@SiteCode='+@SiteCode+',@DocumentID='+CAST(@DocumentID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,1, @TransportNo,@TransferID,19

	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tblShipmentDocument
	SET DocumentStatus=-1
	WHERE id=@DocumentID

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, TransportNo,TransferOut,ProcessID)
	SELECT 'spCreateFile','@SiteCode='+@SiteCode+',@DocumentID='+CAST(@DocumentID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0, @TransportNo,@TransferID,19
	SET @SuccessFlg=0
END CATCH
END
GO
