/****** Object:  StoredProcedure [dbo].[spDeleteTransportv223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




--Start Delete Transport
CREATE PROCEDURE [dbo].[spDeleteTransportv223](
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
		@ShipmentID VARCHAR(50),
		@CargoDelID VARCHAR(50),
		@RowID VARCHAR(50),
		@TransportNo VARCHAR(20),
		@DeliveryNo VARCHAR(20)


SELECT 
@ShipmentID = ts.GLABsID,@TransportNo=ts.TransportNo
FROM tblTransport ts
WHERE ts.id=@TransportID

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/shipments/'+@ShipmentID FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
SELECT @URL=REPLACE(@URL,'#','%23')

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteTransportv223','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,18,@TransportNo,@TransferID
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='DELETE'



BEGIN TRY
--Insert Transfer
SET @TransferType=14

INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status, TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@TransportID

SELECT @TransferID=SCOPE_IDENTITY()

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteTransportv223','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,18,@TransportNo,@TransferID

	UPDATE ts
	SET ts.Status=2
	FROM tblTransport ts
	WHERE ts.id=@TransportID
	RETURN
END
ELSE
BEGIN
		UPDATE ts
		SET ts.Status=3
		FROM tblTransport ts
		WHERE ts.id=@TransportID
		
		UPDATE ts
		SET ts.Status=3
		FROM tblShipment ts
		WHERE ts.id=@TransportID

		UPDATE tc
		SET tc.Status=3,tc.GLABsID=NULL
		FROM tblCargo tc INNER JOIN tblTransport ts
		ON ts.TransportNo=tc.TransportID
		WHERE ts.id=@TransportID

		UPDATE tci
		SET tci.SourceStatus=3, tci.DestinationStatus=3,tci.DestinationGLABsID=NULL, tci.SourceGLABsID=NULL
		FROM tblCargoItem tci 
		INNER JOIN tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo
		INNER JOIN tblTransport ts
		ON ts.TransportNo=tc.TransportID
		WHERE ts.id=@TransportID

END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteTransportv223','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,1,18,@TransportNo,@TransferID
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE ts
	SET ts.Status=2
	FROM tblTransport ts
	WHERE ts.id=@TransportID

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spDeleteTransportv223','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,18,@TransportNo,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
