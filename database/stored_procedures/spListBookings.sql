/****** Object:  StoredProcedure [dbo].[spListBookings]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spListBookings](
	@SiteCode VARCHAR(10),
	@Page SMALLINT,
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
		@Filter NVARCHAR(200),
		@BookingDateMax VARCHAR(25),
		@BookingDateMin VARCHAR(25)

SELECT @BookingDateMin=CONVERT(VARCHAR(23), GETDATE()-1, 126), @BookingDateMax=CONVERT(VARCHAR(23), GETDATE()+2, 126)

SELECT @Filter='?filter[booking][startMin]='+@BookingDateMin+'&filter[booking][startMax]='+@BookingDateMax+'&filter[stage][current]=otw'


IF(@Page<>1)
BEGIN
	BEGIN
		SET @Filter=@Filter+'&page%5Bnumber%5D='+CAST(@Page AS varchar(3))
		--'%26page%5Bnumber%5D='+CAST(@Page AS varchar(3))
	END
END

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/stations'+@Filter FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spListBookings','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType=''
SET @MsgMethod='GET'

SELECT TOP 1 @TransferType = tt.id FROM tblTransferType tt WHERE tt.TransferType='Partner'

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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spListBookings','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0
	RETURN
END
ELSE
BEGIN
		DECLARE @MaxPage SMALLINT
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID

		DECLARE @Bookings TABLE(
			StationID VARCHAR(50),
			BookingDate BIGINT,
			BookingDateTime DATETIME
		)
		INSERT INTO @Bookings(StationID,BookingDate)
		SELECT StationID,BookingDate
		FROM OPENJSON(@Msg,'$.data')
		WITH (
			StationID NVARCHAR(100) '$.id',
			BookingDate BIGINT '$.attributes.booking.start'
		);

		UPDATE @Bookings
		SET BookingDateTime= dateadd(S, BookingDate, '1970-01-01') AT TIME ZONE 'Central European Standard Time'

		UPDATE @Bookings 
		SET BookingDateTime=DATEADD(hour,DATEDIFF(hour,GETUTCDATE(), GETDATE()),  BookingDateTime);

		--SELECT * FROM @Bookings

		UPDATE ts
		SET BookingDate=BookingDateTime,ts.ShipmentStatus=1, ts.SAPStatus=0
		FROM tblShipment ts INNER JOIN @Bookings bs ON bs.StationID=ts.StationID
		WHERE ((ts.BookingDate is NULL) OR (ts.BookingDate<>bs.BookingDateTime))
		AND ts.ShipmentStatus<=1
		
		IF(@Page=1)
		BEGIN
			SELECT @MaxPage=PageNo
			FROM OPENJSON(@Msg)
			WITH (
				PageNo SMALLINT '$.meta.pagination.pageTotal'
			);
					   
			IF(@Page<>@MaxPage)
			BEGIN
				SET @Page=@Page+1
				--Loop for further pages
				WHILE(@Page<=@MaxPage)
				BEGIN
					EXECUTE [dbo].[spListBookings]
						@SiteCode=@SiteCode,
						@Page=@Page,
						@SuccessFlg=@SuccessFlg
					SET @Page=@Page+1
				END
			END

		END
END
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spListBookings','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,1
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spListBookings','@SiteCode='+@SiteCode+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0
	SET @SuccessFlg=0
END CATCH
END
GO
