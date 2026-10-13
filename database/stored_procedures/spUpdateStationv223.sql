/****** Object:  StoredProcedure [dbo].[spUpdateStationv223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spUpdateStationv223](
	@SiteCode VARCHAR(15),
	@StationID VARCHAR(50),
	@BlockFlg BIT,
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
		@StationGLABsID VARCHAR(50),
		@TransportNo VARCHAR(20),
		@SourceFlg BIT,
		@ID INT


SELECT TOP 1 @ID= tsp.id,  @TransportNo = tsp.TransportID FROM tblShipment tsp WHERE tsp.StationID=@StationID


SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/stations/'+@StationID FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
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
	SELECT 'spUpdateStationv223','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50))+',@BlockFlg='+CAST(@BlockFlg AS VARCHAR(10)),'',@Msg,0,27,@TransportNo,NULL,@TransferID
	
	IF(@BlockFlg=0)
	BEGIN
		UPDATE ts
		SET ts.CheckOutAllow=2
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END
	IF(@BlockFlg=1)
	BEGIN
		UPDATE ts
		SET ts.CheckOutBlock=2
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='PATCH'

SET @TransferType=22

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@ID


SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
EXECUTE spCreateStationBodyv223
		@TransferID=@TransferID,
		@StationID=@ID,
		@BlockFlg=@BlockFlg,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

--PRINT @Body

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Body create Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateStationv223','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50))+',@BlockFlg='+CAST(@BlockFlg AS VARCHAR(10)),'',@Msg,0,27,@TransportNo,NULL,@TransferID

	IF(@BlockFlg=0)
	BEGIN
		UPDATE ts
		SET ts.CheckOutAllow=2
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END
	IF(@BlockFlg=1)
	BEGIN
		UPDATE ts
		SET ts.CheckOutBlock=2
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END

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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateStationv223','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50))+',@BlockFlg='+CAST(@BlockFlg AS VARCHAR(10)),'',@Msg,0,27,@TransportNo,NULL,@TransferID

	IF(@BlockFlg=0)
	BEGIN
		UPDATE ts
		SET ts.CheckOutAllow=2
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END
	IF(@BlockFlg=1)
	BEGIN
		UPDATE ts
		SET ts.CheckOutBlock=2
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END
	RETURN
END
ELSE
BEGIN
		--DECLARE @RCargoID VARCHAR(50), @RShipmentID VARCHAR(50), @RSourceStation VARCHAR(50),@RDestinationStation VARCHAR(50),@RStationID VARCHAR(50)
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		--Save IDs
		/*
		SELECT @RCargoID = CargoID
		FROM OPENJSON(@Msg)
		WITH (
			CargoID NVARCHAR(100) '$.data.id'
		);

		--SET @GLABsID=@RCargoID
		
		UPDATE tc
		SET tc.GLABsID=@RCargoID, tc.Status=1
		FROM tblCargo tc
		WHERE tc.id=@CargoID */
		
END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateStationv223','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50))+',@BlockFlg='+CAST(@BlockFlg AS VARCHAR(10)),'',@Msg,1,27,@TransportNo,NULL,@TransferID
	SET @SuccessFlg=1
	IF(@BlockFlg=0)
	BEGIN
		UPDATE ts
		SET ts.CheckOutAllow=1
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END
	IF(@BlockFlg=1)
	BEGIN
		UPDATE ts
		SET ts.CheckOutBlock=1
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END
END TRY
BEGIN CATCH
	/*SELECT  
    ERROR_NUMBER() AS ErrorNumber  
    ,ERROR_SEVERITY() AS ErrorSeverity  
    ,ERROR_STATE() AS ErrorState  
    ,ERROR_PROCEDURE() AS ErrorProcedure  
    ,ERROR_LINE() AS ErrorLine  
    ,ERROR_MESSAGE() AS ErrorMessage; 
	*/
	IF(@BlockFlg=0)
	BEGIN
		UPDATE ts
		SET ts.CheckOutAllow=2
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END
	IF(@BlockFlg=1)
	BEGIN
		UPDATE ts
		SET ts.CheckOutBlock=2
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
	END

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateStationv223','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50))+',@BlockFlg='+CAST(@BlockFlg AS VARCHAR(10)),'',@Msg,0,27,@TransportNo,NULL,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
