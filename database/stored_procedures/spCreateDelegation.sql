/****** Object:  StoredProcedure [dbo].[spCreateDelegation]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCreateDelegation](
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
		@ShipmentNo VARCHAR(50),
		@SelfOrganized BIT, 
		@CarrierID VARCHAR(50),
		@OrganizerID VARCHAR(50),
		@ForwarderDelegation BIT,
		@CarrierDelegation BIT,
		@ForwarderSuccess BIT,
		@CarrierSuccess BIT,
		@TransportNo VARCHAR(20)

SELECT @ShipmentNo=ts.GLABsID, @TransportNo=ts.TransportNo FROM tblTransport ts WHERE ts.id=@TransportID
SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/shipments/'+@ShipmentNo FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,12,@TransportNo,@TransferID
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='PATCH'


SET @TransferType=8

BEGIN TRY


SELECT @ShipmentNo=ts.GLABsID, @SelfOrganized = ts.SelfOrganized,  @CarrierID=ISNULL(ts.CarrierID,''), @OrganizerID=ISNULL(ts.OrganizerID,'') FROM tblTransport ts WHERE ts.id=@TransportID

IF(@SelfOrganized=1) --If self organized
BEGIN
	SET @CarrierDelegation=0
	SET @ForwarderDelegation=1
END
ELSE --If not self organized
BEGIN
	IF(@OrganizerID<>'')
	BEGIN	
		IF(@CarrierID<>'')
		BEGIN
			IF(@OrganizerID<>@CarrierID)
			BEGIN
				SET @CarrierDelegation=1
				SET @ForwarderDelegation=1
			END
			ELSE
			BEGIN
				SET @ForwarderDelegation=1
				SET @CarrierDelegation=0
			END
		END
		ELSE
		BEGIN
				SET @ForwarderDelegation=1
				SET @CarrierDelegation=0
		END
	END
	ELSE
	BEGIN
		IF(@CarrierID<>'')
		BEGIN
			SET @CarrierDelegation=1
			SET @ForwarderDelegation=0
		END
		ELSE
		BEGIN
			SET @CarrierDelegation=0
			SET @ForwarderDelegation=0	
		END
	END

END

SET @ForwarderSuccess=0

IF(@ForwarderDelegation=1)
BEGIN
	--Insert Transfer
	INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
	SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@TransportID

	SELECT @TransferID=SCOPE_IDENTITY()

	--Generate Body
	EXECUTE spCreateDelegateForwarderBodyv223
			@TransferID=@TransferID,
			@TransportID=@TransportID,
			@Body=@Body OUT,
			@SuccessFlg=@SuccessFlg OUT

	--PRINT @Body

	IF(@SuccessFlg=0) -- No Token
	BEGIN
		SET @Msg='Body create Failed'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
		SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,12,@TransportNo,@TransferID
		
		UPDATE ts
		SET  ts.DelegateFlg=0
		FROM tblTransport ts
		WHERE ts.id=@TransportID 
		
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
		SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,12,@TransportNo,@TransferID

		UPDATE ts
		SET  ts.DelegateFlg=0
		FROM tblTransport ts
		WHERE ts.id=@TransportID 
		RETURN

	END
	ELSE
	BEGIN
			DECLARE @RShipmentID VARCHAR(50)
		
			SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
			--Save IDs
			SELECT @RShipmentID = ShipmentID
			FROM OPENJSON(@Msg)
			WITH (
				ShipmentID NVARCHAR(100) '$.data.id'
			);
		
			SET @GLABsID=@RShipmentID

			IF(@RShipmentID IS NULL)
			BEGIN
				SET @Msg='WebRequest Failed Forwarder Delegation'
				INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
				SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0
				SET @SuccessFlg=0
				UPDATE ts
				SET  ts.DelegateFlg=0
				FROM tblTransport ts
				WHERE ts.id=@TransportID 
				RETURN
			END
			ELSE
			BEGIN
				SET @ForwarderSuccess=1
			END

	END
END
ELSE 
BEGIN
	SET @ForwarderSuccess=1
END


IF(@CarrierDelegation=1 AND @ForwarderSuccess=1)
BEGIN
	--Insert Transfer
	INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status)
	SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0

	SELECT @TransferID=SCOPE_IDENTITY()

	--Generate Body
	EXECUTE spCreateDelegateCarrierBodyv223
			@TransferID=@TransferID,
			@TransportID=@TransportID,
			@Body=@Body OUT,
			@SuccessFlg=@SuccessFlg OUT

	--PRINT @Body

	IF(@SuccessFlg=0) -- No Token
	BEGIN
		SET @Msg='Body create Failed'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
		SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0
		
		UPDATE ts
		SET  ts.DelegateFlg=0
		FROM tblTransport ts
		WHERE ts.id=@TransportID 
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
		SET @Msg='WebRequest Failed Carrier Delegation'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
		SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0

		UPDATE ts
		SET  ts.DelegateFlg=0
		FROM tblTransport ts
		WHERE ts.id=@TransportID 
		RETURN

	END
	ELSE
	BEGIN
			SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
			--Save IDs
			SELECT @RShipmentID = ShipmentID
			FROM OPENJSON(@Msg)
			WITH (
				ShipmentID NVARCHAR(100) '$.data.id'
			);
		
			SET @GLABsID=@RShipmentID

			IF(@RShipmentID IS NULL)
			BEGIN
				SET @Msg='WebRequest Failed Carrier Delegation'
				INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
				SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0
				SET @SuccessFlg=0
				UPDATE ts
				SET  ts.DelegateFlg=0
				FROM tblTransport ts
				WHERE ts.id=@TransportID 
				RETURN
			END
			ELSE  
			BEGIN
				SET @CarrierSuccess=1
			END

	END
END
ELSE 
BEGIN
	SET @CarrierSuccess=1
END
IF(@CarrierSuccess=1 AND @ForwarderSuccess=1)
BEGIN
		UPDATE ts
		SET  ts.DelegateFlg=1
		FROM tblTransport ts
		WHERE ts.id=@TransportID 
END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,1,12,@TransportNo,@TransferID
SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE ts
	SET  ts.DelegateFlg=0
	FROM tblTransport ts
	WHERE ts.id=@TransportID 

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,TransferOut)
	SELECT 'spCreateDelegation','@SiteCode='+@SiteCode+',@TransportID='+CAST(@TransportID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,12,@TransportNo,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
