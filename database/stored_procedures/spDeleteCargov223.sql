/****** Object:  StoredProcedure [dbo].[spDeleteCargov223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spDeleteCargov223](
	@SiteCode VARCHAR(15),
	@CargoID INT,
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
		@DeliveryNo VARCHAR(20),
		@SourceFlg	BIT


SELECT 
@CargoDelID=tc.GLABsID,@ShipmentID = ts.GLABsID,@TransportNo=tc.TransportID, @DeliveryNo=tc.DeliveryNo,@SourceFlg = CASE WHEN tc.SourceSiteCode=@SiteCode THEN 0 ELSE 1 END
FROM tblCargo tc
INNER JOIN tblTransport ts ON ts.TransportNo=tc.TransportID
WHERE tc.id=@CargoID

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/shipments/'+@ShipmentID+'/cargos/'+@CargoDelID FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
SELECT @URL=REPLACE(@URL,'#','%23')

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spDeleteCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,7,@TransportNo,@DeliveryNo,@TransferID
	
	UPDATE tc
	SET tc.Status=2
	FROM tblCargo tc 
	WHERE tc.id=@CargoID
	
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
SET @TransferType=4

INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status, TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@CargoID

SELECT @TransferID=SCOPE_IDENTITY()

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spDeleteCargo','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,8,@TransportNo,@DeliveryNo,@TransferID

	UPDATE tc
	SET tc.Status=2
	FROM tblCargo tc 
	WHERE tc.id=@CargoID
	RETURN
END
ELSE
BEGIN
		UPDATE tc
		SET tc.Status=3,tc.GLABsID=NULL
		FROM tblCargo tc 
		WHERE tc.id=@CargoID

		IF(@SourceFlg=0)
		BEGIN
			UPDATE tci
			SET tci.SourceStatus=3, tci.SourceGLABsID=NULL
			FROM tblCargoItem tci INNER JOIN tblCargo tc On tc.DeliveryNo=tci.DeliveryNo
			WHERE tc.id=@CargoID AND tci.SourceGLABsID IS NULL
		END
		ELSE
		BEGIN
			UPDATE tci
			SET tci.DestinationStatus=3, tci.DestinationGLABsID=NULL
			FROM tblCargoItem tci INNER JOIN tblCargo tc On tc.DeliveryNo=tci.DeliveryNo
			WHERE tc.id=@CargoID AND tci.DestinationGLABsID IS NULL
		END
END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spDeleteCargo','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,1,8,@TransportNo,@DeliveryNo,@TransferID
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tc
	SET tc.Status=2
	FROM tblCargo tc 
	WHERE tc.id=@CargoID

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spDeleteCargo','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,8,@TransportNo,@DeliveryNo,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
