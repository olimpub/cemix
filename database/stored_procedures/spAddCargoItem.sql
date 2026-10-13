/****** Object:  StoredProcedure [dbo].[spAddCargoItem]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--End of Step 6 Delivery modifications


CREATE PROCEDURE [dbo].[spAddCargoItem](
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
		@TransportNo VARCHAR(20),
		@DeliveryNo VARCHAR(20),
		@ItemNo VARCHAR(20)	

SELECT 
@CargoID=tc.GLABsID,@ShipmentID = ts.GLABsID,@TransportNo=tc.TransportID, @DeliveryNo=tc.DeliveryNo ,@ItemNo=ci.ItemNo
FROM tblCargoItem ci INNER JOIN tblCargo tc ON tc.DeliveryNo=ci.DeliveryNo 
INNER JOIN tblShipment ts ON ts.TransportID=tc.TransportID
WHERE ci.id=@CargoItemID


SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/shipments/'+@ShipmentID+'/cargos/'+@CargoID+'/items' FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
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
		SELECT 'spAddCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,9,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='POST'


SELECT TOP 1 @TransferType = tt.id FROM tblTransferType tt WHERE tt.TransferType='Partner'

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status,TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0,@CargoItemID

SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
EXECUTE spCreateCargoItemBody
		@TransferID=@TransferID,
		@CargoItemID=@CargoItemID,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Body create Failed'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
		SELECT 'spAddCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,9,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spAddCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,9,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
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

		
		UPDATE tci
		SET tci.GLABsID=@GLABsID, tci.Status=1
		FROM tblCargoItem tci 
		WHERE tci.id=@CargoItemID

END
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spAddCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),'Success',1,9,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tci
	SET tci.Status=2
	FROM tblCargoItem tci
	WHERE tci.id=@CargoItemID

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,ItemNo,TransferOut)
	SELECT 'spAddCargoItemv223','@SiteCode='+@SiteCode+',@CargoItemID='+CAST(@CargoItemID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,9,@TransportNo,@DeliveryNo,@ItemNo,@TransferID 
	SET @SuccessFlg=0
END CATCH
END
GO
