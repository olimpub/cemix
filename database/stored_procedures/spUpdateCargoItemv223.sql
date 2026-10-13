/****** Object:  StoredProcedure [dbo].[spUpdateCargoItemv223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spUpdateCargoItemv223](
	@SiteCode VARCHAR(15),
	@CargoItemID INT,
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
		@CargoID VARCHAR(50),
		@RowID VARCHAR(50),
		@TransportNo VARCHAR(20),
		@DeliveryNo VARCHAR(20),
		@ItemNo VARCHAR(20),
		@SourceFlg BIT


SELECT 
@CargoID=tc.GLABsID,@ShipmentID = CASE WHEN tc.SourceSiteCode=@SiteCode THEN tc.SourceOperationsID ELSE tc.DestinationOperationsID END,
@RowID = CASE WHEN tc.SourceSiteCode=@SiteCode THEN ci.SourceGLABsID ELSE ci.DestinationGLABsID END,
@TransportNo=tc.TransportID, @DeliveryNo=tc.DeliveryNo ,@ItemNo=ci.ItemNo,
@SourceFlg=CASE WHEN tc.SourceSiteCode=@SiteCode THEN 1 ELSE 0 END
FROM tblCargoItem ci INNER JOIN tblCargo tc ON tc.DeliveryNo=ci.DeliveryNo 
INNER JOIN tblShipment ts ON ts.TransportID=tc.TransportID
WHERE ci.id=@CargoItemID

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/cargo-operations/'+@ShipmentID+'/items/'+@RowID FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
SELECT @URL=REPLACE(@URL,'#','%23')

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spUpdateCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,10,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	
	IF(@SourceFlg=1)
	BEGIN
		UPDATE tci
		SET tci.SourceStatus=2
		FROM tblCargoItem tci
		WHERE tci.id=@CargoItemID
	END
	ELSE
	BEGIN
		UPDATE tci
		SET tci.DestinationStatus=2
		FROM tblCargoItem tci
		WHERE tci.id=@CargoItemID
	END
	
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='PATCH'

SET @TransferType=6

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@CargoItemID

SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
EXECUTE spCreateCargoItemBodyv223
		@TransferID=@TransferID,
		@SiteCode=@SiteCode,
		@CargoItemID=@CargoItemID,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Body create Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spUpdateCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,10,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	
	IF(@SourceFlg=1)
	BEGIN
		UPDATE tci
		SET tci.SourceStatus=2
		FROM tblCargoItem tci
		WHERE tci.id=@CargoItemID
	END
	ELSE
	BEGIN
		UPDATE tci
		SET tci.DestinationStatus=2
		FROM tblCargoItem tci
		WHERE tci.id=@CargoItemID
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
	SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
	IF(@SourceFlg=1)
	BEGIN
		UPDATE tci
		SET tci.SourceStatus=2, tci.SourceInProgressFlg= CASE WHEN @Msg LIKE '%in progress%' THEN 1 ELSE NULL END
		FROM tblCargoItem tci
		WHERE tci.id=@CargoItemID
	END
	ELSE
	BEGIN
		UPDATE tci
		SET tci.DestinationStatus=2, tci.DestinationInProgressFlg= CASE WHEN @Msg LIKE '%in progress%' THEN 1 ELSE NULL END
		FROM tblCargoItem tci
		WHERE tci.id=@CargoItemID
	END
	
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spUpdateCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,10,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 

	RETURN
END
ELSE
BEGIN
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		--Save IDs
		SELECT @GLABsID = CargoItemID
		FROM OPENJSON(@Msg)
		WITH (
			CargoItemID NVARCHAR(100) '$.data.id'
		);
			
		IF(@SourceFlg=1)
		BEGIN
			UPDATE tci
			SET tci.SourceStatus=1
			FROM tblCargoItem tci 
			WHERE tci.id=@CargoItemID
		END
		ELSE
		BEGIN
			UPDATE tci
			SET tci.DestinationStatus=1
			FROM tblCargoItem tci 
			WHERE tci.id=@CargoItemID
		END

END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spUpdateCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,1,10,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SELECT 
	@SourceFlg=CASE WHEN tc.SourceSiteCode=@SiteCode THEN 1 ELSE 0 END
	FROM tblCargoItem ci INNER JOIN tblCargo tc ON tc.DeliveryNo=ci.DeliveryNo 
	WHERE ci.id=@CargoItemID
	IF(@SourceFlg=1)
	BEGIN
		UPDATE tci
		SET tci.SourceStatus=2
		FROM tblCargoItem tci
		WHERE tci.id=@CargoItemID
	END
	ELSE
	BEGIN
		UPDATE tci
		SET tci.DestinationStatus=2
		FROM tblCargoItem tci
		WHERE tci.id=@CargoItemID
	END

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spUpdateCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,10,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	SET @SuccessFlg=0
END CATCH
END
GO
