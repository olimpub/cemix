/****** Object:  StoredProcedure [dbo].[spDeleteCargoItemv223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spDeleteCargoItemv223](
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
		@ItemNo NVARCHAR(50),
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
	SELECT 'spDeleteCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,11,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	
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
SET @MsgMethod='DELETE'

SET @TransferType=7

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@CargoItemID

SELECT @TransferID=SCOPE_IDENTITY()

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0)
BEGIN
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

	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spDeleteCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,11,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 

	RETURN
END
ELSE
BEGIN
		IF(@SourceFlg=1)
		BEGIN
			UPDATE tci
			SET tci.SourceStatus=3, tci.SourceGLABsID=NULL
			FROM tblCargoItem tci 
			WHERE tci.id=@CargoItemID
		END
		ELSE
		BEGIN
			UPDATE tci
			SET tci.DestinationStatus=3, tci.DestinationGLABsID=NULL
			FROM tblCargoItem tci 
			WHERE tci.id=@CargoItemID
		END

END	
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spDeleteCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,1,11,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
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
	SELECT 'spDeleteCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,11,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	SET @SuccessFlg=0
END CATCH
END
GO
