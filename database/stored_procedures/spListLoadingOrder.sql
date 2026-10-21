/****** Object:  StoredProcedure [dbo].[spListLoadingOrder]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spListLoadingOrder](
	@SiteCode VARCHAR(10),
	@Page SMALLINT,
	@OrderNo SMALLINT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN
DECLARE @TransferType SMALLINT,
		@URL NVARCHAR(1000),
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
		@Filter NVARCHAR(1000),
		@LastRunDate VARCHAR(30),
		@StatusName VARCHAR(30)

SELECT @Filter='?filter[closed][closed]=0&filter[expr]=depotOperator%3D%3Dnull%26%26(currentStage.name%3D%3D''waiting''%26%26!existEarlierStage(''loading''))%26%26(picking.required%3D%3Dfalse%7C%7C(picking.open%3D%3Dfalse%26%26(currentPickingStatus%3D%3Dnull%7C%7CcurrentPickingStatus.name%3D%3D''closed'')))%26%26picking.mismatching%3D%3Dfalse&sort=-priority,booking'

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/stations'+@Filter FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListLoadingOrder','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,25,@TransferID
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType=''
SET @MsgMethod='GET'

SET @TransferType=9

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status)
SELECT @TransferType,@URL,@Header,''/*@Body*/,@MsgType,@MsgMethod,@ResponseAccept,0

SELECT @TransferID=SCOPE_IDENTITY()

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListLoadingOrder','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,25,@TransferID

	RETURN
END
ELSE
BEGIN
		DECLARE @MaxPage SMALLINT
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID

	
		DECLARE @Bookings TABLE(
			OrderID SMALLINT IDENTITY(1,1),
			StationID VARCHAR(50)
		)
		INSERT INTO @Bookings(StationID)
		SELECT StationID
		FROM OPENJSON(@Msg,'$.data')
		WITH (
			StationID NVARCHAR(100) '$.id'
		);

		DELETE FROM @Bookings WHERE OrderID>@OrderNo

		UPDATE ts
		SET ts.OrderID=bs.OrderID, CallStatus=0
		FROM tblShipment ts INNER JOIN @Bookings bs ON bs.StationID=ts.StationID

END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListLoadingOrder','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,1,25,@TransferID

	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListLoadingOrder','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,25,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
