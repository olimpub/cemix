/****** Object:  StoredProcedure [dbo].[spUpdateCargov223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spUpdateCargov223](
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
		@CargoIDURL VARCHAR(50),
		@ShipmentIDURL VARCHAR(50),
		@TransportNo VARCHAR(20),
		@DeliveryNo VARCHAR(20),
		@SourceFlg BIT


SELECT @CargoIDURL= tc.GLABsID, @ShipmentIDURL = ts.GLABsID, @TransportNo=tc.TransportID, @DeliveryNo=tc.DeliveryNo,@SourceFlg = CASE WHEN tc.SourceSiteCode=@SiteCode THEN 0 ELSE 1 END FROM tblTransport ts INNER JOIN
tblCargo tc ON tc.TransportID=ts.TransportNo WHERE tc.id=@CargoID


SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/shipments/'+@ShipmentIDURL+'/cargos/'+@CargoIDURL FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode
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
	SELECT 'spUpdateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,7,@TransportNo,@DeliveryNo,@TransferID
	
	UPDATE tc
	SET  tc.Status=2
	FROM tblCargo tc
	WHERE tc.id=@CargoID 

	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType='application/json'
SET @MsgMethod='PATCH'

SET @TransferType=3

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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,7,@TransportNo,@DeliveryNo,@TransferID

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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,7,@TransportNo,@DeliveryNo,@TransferID


	UPDATE tc
	SET  tc.Status=2
	FROM tblCargo tc
	WHERE tc.id=@CargoID 

	RETURN
END
ELSE
BEGIN
		DECLARE @RCargoID VARCHAR(50), @RShipmentID VARCHAR(50), @RSourceStation VARCHAR(50),@RDestinationStation VARCHAR(50),@RStationID VARCHAR(50)
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
		
END
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),'Success',1,7,@TransportNo,@DeliveryNo,@TransferID
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tc
	SET  tc.Status=2
	FROM tblCargo tc
	WHERE tc.id=@CargoID 

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateCargov223','@SiteCode='+@SiteCode+',@CargoID='+CAST(@CargoID AS VARCHAR(10)),'@GLABsID='+ISNULL(@GLABsID,'NULL'),@Msg,0,7,@TransportNo,@DeliveryNo,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
