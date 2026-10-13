/****** Object:  StoredProcedure [dbo].[spSAPUpdate_depr]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spSAPUpdate_depr](
	@ShipmentID INT,
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
		@Token VARCHAR(300),
		@TransferID INT,
		@SiteCode VARCHAR(10),
		@TransportID VARCHAR(100),
		@ShipmentStatus INT,
		@XML XML,
		@UserName NVARCHAR(200),
		@Password NVARCHAR(200),
		@TransportNo VARCHAR(50)

SELECT @SiteCode = ts.SiteCode, @TransportNo = ts.TransportID  FROM [dbo].[tblShipment] ts WHERE ts.id=@ShipmentID
SELECT @URL=tcpr.[SAPUrl], @UserName=tcpr.SAPUserName, @Password=tcpr.SAPPassword FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode



SELECT @Token=dbo.fnBase64CLR(@UserName+':'+@Password)

--Create Header
SET @Header='Authorization: Basic '+@Token+'&'
SELECT @Header
--Other data
SET @ResponseAccept='application/xml'
SET @MsgType='application/xml'
SET @MsgMethod='POST'

SELECT @URL

SET @TransferType=12

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status, TransportID)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0, @ShipmentID

SELECT @TransferID=SCOPE_IDENTITY()

--Generate Body
SELECT @XML=[dbo].[fnSAPSHPMNT06](@ShipmentID)
SELECT @Body='<?xml version="1.0" encoding="utf-8"?>'+REPLACE((CONVERT(VARCHAR(MAX),@XML,1)),' xmlns=""','')
SELECT @Body

--Update Body
UPDATE tblTransferOut
SET Body=@Body
WHERE id=@TransferID

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT


IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut,TransportNo)
	SELECT 'spSAPUpdate','@ShipmentID='+CAST(@ShipmentID AS VARCHAR(10)),'',@Msg,0,16,@TransferID,@TransportNo

	/*
	UPDATE tblShipment
	SET SAPStatus=-1
	WHERE id=@ShipmentID
	*/--to comment out, because shipment should retry
END
ELSE
BEGIN
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut,TransportNo)
	SELECT 'spSAPUpdate','@ShipmentID='+CAST(@ShipmentID AS VARCHAR(10)),'',@Msg,1,16,@TransferID,@TransportNo
	
	UPDATE tblShipment
	SET SAPStatus=1
	WHERE id=@ShipmentID
	
	SET @SuccessFlg=1
END
END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut,TransportNo)
	SELECT 'spSAPUpdate','@ShipmentID='+CAST(@ShipmentID AS VARCHAR(10)),'',@Msg,0,16,@TransferID,@TransportNo
	
	
	UPDATE tblShipment
	SET SAPStatus=-1
	WHERE id=@ShipmentID
	
	SET @SuccessFlg=0
END CATCH
END
GO
