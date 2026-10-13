/****** Object:  StoredProcedure [dbo].[spCreateCargov223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCreateCargov223](
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
		@Direction BIT,
		@TransportNo VARCHAR(20),
		@DeliveryNo VARCHAR(20),
		@SourceFlg BIT



SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/shipments/cargos' FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
SELECT @Direction=tc.Direction, @TransportNo=tc.TransportID, @DeliveryNo=tc.DeliveryNo, @SourceFlg = CASE WHEN tc.SourceSiteCode=@SiteCode THEN 0 ELSE 1 END FROM tblCargo tc WHERE tc.id=@CargoID


--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransportNo,DeliveryNo)
	SELECT 'spCreateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,6,@TransportNo,@DeliveryNo
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='POST'

SET @TransferType=2

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@CargoID

SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
EXECUTE spCreateCargoBodyv223
		@TransferID=@TransferID,
		@CargoID=@CargoID,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

--PRINT @Body

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Body create Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo)
	SELECT 'spCreateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,6,@TransportNo,@DeliveryNo
		
	UPDATE tc
	SET  tc.Status=2
	FROM tblCargo tc
	WHERE tc.id=@CargoID 

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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo, TransferOut)
	SELECT 'spCreateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID'+ISNULL(@GLABsID,'NULL'),@Msg,0,6,@TransportNo,@DeliveryNo,@TransferID

	UPDATE tc
	SET  tc.Status=2
	FROM tblCargo tc
	WHERE tc.id=@CargoID 

	IF(@SourceFlg=0)
	BEGIN
		UPDATE tci
		SET tci.SourceStatus=2
		FROM tblCargoItem tci INNER JOIN tblCargo tc On tc.DeliveryNo=tci.DeliveryNo
		WHERE tc.id=@CargoID AND tci.SourceGLABsID IS NULL
	END
	ELSE
	BEGIN
		UPDATE tci
		SET tci.DestinationStatus=2
		FROM tblCargoItem tci INNER JOIN tblCargo tc On tc.DeliveryNo=tci.DeliveryNo
		WHERE tc.id=@CargoID AND tci.DestinationGLABsID IS NULL
	END

	RETURN;
END
ELSE
BEGIN
		DECLARE @RCargoID VARCHAR(50), @RShipmentID VARCHAR(50), @RSourceStationID VARCHAR(50),@RDestinationStationID VARCHAR(50),@RSourceOperationsID VARCHAR(50),@RDestinationOperationsID VARCHAR(50)
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		--Save IDs
		SELECT @RCargoID = CargoID
		FROM OPENJSON(@Msg)
		WITH (
			CargoID NVARCHAR(100) '$.data.id'
		);

		SET @GLABsID=@RCargoID

		UPDATE tc
		SET tc.GLABsID=@RCargoID, tc.Status=1
		FROM tblCargo tc
		WHERE tc.id=@CargoID 

		SELECT @RShipmentID = ShipmentID
		FROM OPENJSON(@Msg)
		WITH (
			ShipmentID NVARCHAR(100) '$.data.relationships.shipment.data.id'
		);

		UPDATE ts
		SET ts.GLABsID=@RShipmentID, ts.Status=1
		FROM tblTransport ts
		INNER JOIN tblCargo tc ON tc.TransportID=ts.TransportNo
		WHERE tc.id=@CargoID AND ts.GLABsID IS NULL

		SELECT @RSourceOperationsID = OperationsID, @RSourceStationID=StationID
			FROM OPENJSON(@Msg)
			WITH (
				OperationsID NVARCHAR(100) '$.data.relationships.sourceOperation.data.id',
				StationID NVARCHAR(100) '$.data.relationships.sourceStation.data.id'
			);

		SELECT @RDestinationOperationsID = OperationsID, @RDestinationStationID=StationID
			FROM OPENJSON(@Msg)
			WITH (
				OperationsID NVARCHAR(100) '$.data.relationships.destinationOperation.data.id',
				StationID NVARCHAR(100) '$.data.relationships.destinationStation.data.id'
			);

		UPDATE ts
		SET ts.StationID=@RSourceStationID
		FROM tblShipment ts INNER JOIN tblCargo tc ON tc.TransportID=ts.TransportID AND tc.SourceSiteCode=ts.SiteCode 
		WHERE tc.id=@CargoID AND ts.StationID IS NULL

		
		UPDATE ts
		SET ts.StationID=@RDestinationStationID
		FROM tblShipment ts INNER JOIN tblCargo tc ON tc.TransportID=ts.TransportID AND tc.DestinationSiteCode=ts.SiteCode 
		WHERE tc.id=@CargoID AND ts.StationID IS NULL

		UPDATE tc
		SET tc.DestinationOperationsID=@RDestinationOperationsID, tc.SourceOperationsID=@RSourceOperationsID
		FROM tblCargo tc
		WHERE tc.id=@CargoID 


		/*
		DECLARE @RItems TABLE(
			RowNo INT IDENTITY(1,1),
			GLABsID NVARCHAR(50)
		)

		INSERT INTO @RItems(GLABsID)
		SELECT Item
		FROM OPENJSON(@Msg,'$.data.relationships.items.data')
		WITH (
			Item NVARCHAR(100) '$.id'
		);

		DECLARE @OItems TABLE(
			RowNo INT IDENTITY(1,1),
			ItemNo VARCHAR(10)
		)

		INSERT INTO @OItems(ItemNo)
		SELECT tci.ItemNo FROM tblCargoItem tci INNER JOIN tblCargo tc On tc.DeliveryNo=tci.DeliveryNo
		WHERE tc.id=@CargoID AND tci.GLABsID IS NULL
		ORDER BY tci.id


		UPDATE tci
		SET tci.GLABsID=ri.GLABsID, tci.Status=1
		FROM tblCargoItem tci INNER JOIN tblCargo tc On tc.DeliveryNo=tci.DeliveryNo
		INNER JOIN @OItems oi ON oi.ItemNo=tci.ItemNo 
		INNER JOIN @RItems ri ON ri.RowNo=oi.RowNo
		WHERE tc.id=@CargoID
		*/


END
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spCreateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),'',1,6,@TransportNo,@DeliveryNo,@TransferID
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tc
	SET  tc.Status=2
	FROM tblCargo tc
	WHERE tc.id=@CargoID 

	IF(@SourceFlg=0)
	BEGIN
		UPDATE tci
		SET tci.SourceStatus=2
		FROM tblCargoItem tci INNER JOIN tblCargo tc On tc.DeliveryNo=tci.DeliveryNo
		WHERE tc.id=@CargoID AND tci.SourceGLABsID IS NULL
	END
	ELSE
	BEGIN
		UPDATE tci
		SET tci.DestinationStatus=2
		FROM tblCargoItem tci INNER JOIN tblCargo tc On tc.DeliveryNo=tci.DeliveryNo
		WHERE tc.id=@CargoID AND tci.DestinationGLABsID IS NULL
	END

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spCreateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,6,@TransportNo,@DeliveryNo,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
