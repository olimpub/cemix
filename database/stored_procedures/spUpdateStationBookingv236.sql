/****** Object:  StoredProcedure [dbo].[spUpdateStationBookingv236]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spUpdateStationBookingv236](
	@SiteCode VARCHAR(15),
	@StationID VARCHAR(50),
	@BookingDate DATETIME,
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
		@BookingDateUnix INT,
		@BookingDateUnixStr VARCHAR(20),
		@TransportNo VARCHAR(20),
		@ID INT

SELECT TOP 1 @ID= tsp.id,  @TransportNo = tsp.TransportID FROM tblShipment tsp WHERE tsp.StationID=@StationID

SELECT @BookingDateUnix=[dbo].[spGetUnixTimestamp](@BookingDate)
SET @BookingDateUnixStr=CAST(@BookingDateUnix AS VARCHAR(20))


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
	SELECT 'spUpdateStationBookingv236','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,0,27,@TransportNo,NULL,@TransferID
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
EXECUTE spCreateStationBookingBodyv236
		@TransferID=@TransferID,
		@StationID=@ID,
		@BookingDate=@BookingDateUnixStr,
		@Body=@Body OUT,
		@SuccessFlg=@SuccessFlg OUT

--SELECT @BookingDateUnixStr, @Body, @URL
--RETURN

IF(@SuccessFlg=0) -- Body create failed
BEGIN
	SET @Msg='Body create Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateStationBookingv236','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,0,27,@TransportNo,NULL,@TransferID

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
	SELECT 'spUpdateStationBookingv236','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,0,27,@TransportNo,NULL,@TransferID
	RETURN
END
ELSE
BEGIN
		/*	
		UPDATE ts
		SET ts.BookingDate=@BookingDate
		FROM tblShipment ts
		WHERE ts.StationID=@StationID
		*/
		SET @Msg='Success'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
		SELECT 'spUpdateStationBookingv236','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,1,27,@TransportNo,NULL,@TransferID
		
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

	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID, TransportNo,DeliveryNo,TransferOut)
	SELECT 'spUpdateStationBookingv236','@SiteCode='+@SiteCode+',@StationID='+CAST(@StationID AS VARCHAR(50)),'',@Msg,0,27,@TransportNo,NULL,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
