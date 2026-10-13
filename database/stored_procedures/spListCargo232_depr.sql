/****** Object:  StoredProcedure [dbo].[spListCargo232_depr]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spListCargo232_depr](
	@SiteCode VARCHAR(10),
	@Status SMALLINT,
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
		@LastRunDate VARCHAR(30),
		@StatusName VARCHAR(30),
		@LastRunDateInDateFormat DATETIME

SELECT @LastRunDate =[dbo].[spGetUnixTimestamp](DATEADD(mi,-5,st.LastRunDate)), @LastRunDateInDateFormat = st.LastRunDate  FROM tblShipmentStatusExecution st WHERE st.id=@Status AND SiteCode=@SiteCode 
SELECT TOP 1 @StatusName= st.StatusName FROM tblShipmentStatus st WHERE st.id=@Status 

SELECT @Status AS StatusRequest, @StatusName AS StatusName, @LastRunDateInDateFormat AS StatusDate

IF(@Status=0)
BEGIN
	SET @Filter=N''
END
ELSE
BEGIN
	IF(@Status=1)
	BEGIN
		SELECT @Filter='?filter[booking][createdAtMin]='+@LastRunDate
	END
	

	IF(@Status IN (2,3))
	BEGIN
		SELECT @Filter='?include=cargoOperations,shipment&filter[stage][current]='+@StatusName+'&filter[stage][createdAtMin]='+@LastRunDate 
	END
	IF(@Status=4)
	BEGIN
		SELECT @Filter='?include=cargoOperations,shipment&filter[documentation_status][current]='+@StatusName+'&filter[stage][current]=closed'--+'&filter[stage][createdAtMin]='+@LastRunDate 
	END
	IF(@Status=5)
	BEGIN
		SELECT @Filter='?include=cargoOperations,statonStages&filter[closed][closed]=1&filter[core][notAppeared]=0&filter[closed][createdAtMin]='+@LastRunDate
	END
END

IF(@Page<>1)
BEGIN
	IF(@Status=0)
	BEGIN
		SET @Filter='?page%5Bnumber%5D='+CAST(@Page AS varchar(3))
	END 
	ELSE
	BEGIN
		SET @Filter=@Filter+'&page%5Bnumber%5D='+CAST(@Page AS varchar(3))
		--'%26page%5Bnumber%5D='+CAST(@Page AS varchar(3))
	END
END

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/stations'+@Filter FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

SELECT @URL, @Filter


RETURN

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListCargo','@SiteCode='+@SiteCode+',@Status='+CAST(@Status AS varchar(10))+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,13,@TransferID
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
	SELECT 'spListCargo','@SiteCode='+@SiteCode+',@Status='+CAST(@Status AS varchar(10))+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,13,@TransferID

	RETURN
END
ELSE
BEGIN
		DECLARE @MaxPage SMALLINT
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID

		--Collect Stations
		DECLARE @Stations TABLE(
			StationID VARCHAR(50),
			ShipmentStatus SMALLINT
		)

		DECLARE @Stations2 TABLE(
			StationID VARCHAR(50),
			ShipmentStatus SMALLINT
		)

		DECLARE @Stations3 TABLE(
			StationID VARCHAR(50),
			ShipmentStatus SMALLINT
		)
	
		INSERT INTO @Stations(StationID,ShipmentStatus)
		SELECT StationID,@Status 
		FROM OPENJSON(@Msg,'$.data')
		WITH (
			StationID NVARCHAR(100) '$.id'
		);

		
		
		INSERT INTO @Stations2
		SELECT st.StationID,ISNULL(MAX(sq.CurrentStatus),0) FROM tblShipmentStatusQueue sq 
		LEFT OUTER JOIN @Stations st ON st.StationID=sq.StationID
		WHERE st.StationID IS NOT NULL
		GROUP BY st.StationID

		INSERT INTO @Stations3(StationID,ShipmentStatus)
		SELECT st.StationID,MIN(st.ShipmentStatus) FROM @Stations st GROUP BY st.StationID

		WHILE EXISTS(SELECT * FROM @Stations3 s3 INNER JOIN @Stations2 s2 ON s3.StationID=s2.StationID AND s3.ShipmentStatus<>s2.ShipmentStatus+1 AND s3.ShipmentStatus>s2.ShipmentStatus  )
		BEGIN

			INSERT INTO @Stations
			SELECT s3.StationID,s3.ShipmentStatus-1 FROM @Stations3 s3 INNER JOIN @Stations2 s2 ON s3.StationID=s2.StationID AND s3.ShipmentStatus<>s2.ShipmentStatus+1 AND s3.ShipmentStatus>s2.ShipmentStatus 

			UPDATE s3
			SET s3.ShipmentStatus=(SELECT MIN(s1.ShipmentStatus) FROM @Stations s1 WHERE s1.StationID=s3.StationID)
			FROM @Stations3 s3
		END

		SELECT * FROM @Stations
		--RETURN


		IF EXISTS(SELECT * FROM @Stations WHERE ShipmentStatus=1)
		BEGIN
		
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

		--Delete where not relevant
		DELETE bk FROM @Bookings bk WHERE StationID NOT IN(SELECT StationID FROM @Stations WHERE ShipmentStatus=1)

		--SELECT * FROM @Bookings
			INSERT INTO [dbo].[tblShipmentStatusQueue]
					   ([StationID]
					   ,[ActionDate]
					   ,[CurrentStatus]
					   ,[SaveDate]
					   ,[ProcessStatus])
			SELECT 
				bs.StationID,
				bs.BookingDateTime,
				1,
				GETDATE(),
				0
			FROM @Bookings bs
			WHERE NOT EXISTS(SELECT * FROM [dbo].[tblShipmentStatusQueue] qs WHERE qs.StationID=bs.StationID AND qs.CurrentStatus=1)

			UPDATE ts
			SET ts.BookingDate=bs.BookingDateTime
			FROm tblShipment ts INNER JOIN @Bookings bs ON bs.StationID=ts.StationID
		END

		IF EXISTS(SELECT * FROM @Stations WHERE ShipmentStatus=2)
		BEGIN
			DECLARE @CheckIn TABLE(
				StationID VARCHAR(50),
				CheckInDate BIGINT,
				CheckInDateTime DATETIME
			)

			DECLARE @BorderCrossing TABLE(
					CargoID NVARCHAR(50),
					BorderID NVARCHAR(100)
				)

			INSERT INTO @CheckIn(StationID,CheckInDate)
			SELECT StationID,CheckinDate
			FROM OPENJSON(@Msg,'$.data')
			WITH (
				StationID NVARCHAR(100) '$.id',
				CheckinDate BIGINT '$.attributes.checkin.time'
			);

			UPDATE @CheckIn
			SET CheckInDateTime= dateadd(S, CheckInDate, '1970-01-01') AT TIME ZONE 'Central European Standard Time'

			UPDATE @CheckIn 
			SET CheckInDateTime =DATEADD(hour,DATEDIFF(hour,GETUTCDATE(), GETDATE()),  CheckInDateTime );


			INSERT INTO @BorderCrossing(CargoID,BorderID)
			SELECT CargoID,BorderCrossingPoint
			FROM OPENJSON(@Msg,'$.included')
			WITH (
				CargoID NVARCHAR(50) '$.relationships.cargo.data.id',
				BorderCrossingPoint NVARCHAR(100) '$.relationships.borderCrossingPoint.data.id'
			)
			WHERE BorderCrossingPoint IS NOT NULL

			UPDATE tc
			SET tc.BorderCrossingID=bb.BorderID
			FROM [dbo].[tblCargo] tc INNER JOIN @BorderCrossing bb ON bb.CargoID=tc.GLABsID

			--SELECT * FROm @CheckIn
			--Delete where not relevant
			DELETE ck FROM @CheckIn ck WHERE ck.StationID NOT IN(SELECT StationID FROM @Stations s WHERE ShipmentStatus=2)

			INSERT INTO [dbo].[tblShipmentStatusQueue]
						   ([StationID]
						   ,[ActionDate]
						   ,[CurrentStatus]
						   ,[SaveDate]
						   ,[ProcessStatus])
				SELECT 
					cs.StationID,
					cs.CheckInDateTime,
					2,
					GETDATE(),
					0
				FROM @CheckIn cs
				WHERE NOT EXISTS(SELECT * FROM [dbo].[tblShipmentStatusQueue] qs WHERE qs.StationID=cs.StationID AND qs.CurrentStatus=2)
		END

		IF EXISTS(SELECT * FROM @Stations WHERE ShipmentStatus=3)
		BEGIN
			DECLARE @Loading TABLE(
				StationID VARCHAR(50),
				LoadingDate BIGINT,
				LoadingDateTime DATETIME
			)
			INSERT INTO @Loading(StationID,LoadingDate)
			SELECT StationID,LoadingDate
			FROM OPENJSON(@Msg,'$.data')
			WITH (
				StationID NVARCHAR(100) '$.id',
				LoadingDate BIGINT '$.attributes.stage.current.time'
			);

			UPDATE @Loading
			SET LoadingDateTime= dateadd(S, LoadingDate, '1970-01-01') AT TIME ZONE 'Central European Standard Time'

			UPDATE @Loading 
			SET LoadingDateTime =DATEADD(hour,DATEDIFF(hour,GETUTCDATE(), GETDATE()),  LoadingDateTime );

			--Delete where not relevant
			DELETE ld FROM  @Loading ld WHERE ld.StationID NOT IN(SELECT StationID FROM @Stations WHERE ShipmentStatus=3)

			INSERT INTO [dbo].[tblShipmentStatusQueue]
						   ([StationID]
						   ,[ActionDate]
						   ,[CurrentStatus]
						   ,[SaveDate]
						   ,[ProcessStatus])
				SELECT 
					cs.StationID,
					cs.LoadingDateTime,
					3,
					GETDATE(),
					0
				FROM @Loading cs
				WHERE NOT EXISTS(SELECT * FROM [dbo].[tblShipmentStatusQueue] qs WHERE qs.StationID=cs.StationID AND qs.CurrentStatus=3)

		END
		IF EXISTS(SELECT * FROM @Stations WHERE ShipmentStatus=4)
			BEGIN
				DECLARE @Admin TABLE(
					StationID VARCHAR(50),
					AdminDate BIGINT,
					AdminDateTime DATETIME,
					PhoneNumber VARCHAR(50),
					PhoneCountry VARCHAR(10),
					LicensePlateNo1 NVARCHAR(50),
					LicensePlateNo2 NVARCHAR(50)

				)

			DECLARE @Border TABLE(
					CargoID NVARCHAR(50),
					BorderID NVARCHAR(100)
				)

			INSERT INTO @Admin(StationID,AdminDate,PhoneNumber,PhoneCountry,LicensePlateNo1,LicensePlateNo2)
			SELECT StationID,AdminDate,PhoneNumber,PhoneCountry,LicensePlateNo1,LicensePlateNo2
			FROM OPENJSON(@Msg,'$.data')
			WITH (
				StationID NVARCHAR(100) '$.id',
				AdminDate BIGINT '$.attributes.stage.current.time',
				PhoneNumber VARCHAR(50) '$.attributes.driver.phoneNumber',
				PhoneCountry VARCHAR(10) '$.attributes.driver.phoneCountryCode',
				LicensePlateNo1 NVARCHAR(50) '$.attributes.plateNumbers[0]',
				LicensePlateNo2 NVARCHAR(50) '$.attributes.plateNumbers[1]'
			);

			INSERT INTO @Border(CargoID,BorderID)
			SELECT CargoID,BorderCrossingPoint
			FROM OPENJSON(@Msg,'$.included')
			WITH (
				CargoID NVARCHAR(50) '$.relationships.cargo.data.id',
				BorderCrossingPoint NVARCHAR(100) '$.relationships.borderCrossingPoint.data.id'
			)
			WHERE BorderCrossingPoint IS NOT NULL

			UPDATE @Admin
			SET AdminDateTime= dateadd(S, AdminDate, '1970-01-01') AT TIME ZONE 'Central European Standard Time'

			UPDATE @Admin 
			SET AdminDateTime =DATEADD(hour,DATEDIFF(hour,GETUTCDATE(), GETDATE()),  AdminDateTime );

			--Delete where not relevant
			DELETE ad FROM  @Admin ad WHERE ad.StationID NOT IN(SELECT StationID FROM @Stations WHERE ShipmentStatus=4)

	

			DECLARE @Included TABLE(
				DataType VARCHAR(50),
				ID VARCHAR(50),
				loadingQuantityMismatch VARCHAR(10)

			)

			INSERT INTO @Included(DataType,ID,loadingQuantityMismatch)
			SELECT DataType, ID, loadingQuantityMismatch 
			FROM OPENJSON(@Msg,'$.included')
			WITH (
				DataType VARCHAR(50) '$.type',
				ID VARCHAR(50) '$.id',
				loadingQuantityMismatch VARCHAR(10) '$.attributes.loadingQuantityMismatch'
			);


			--UPADTE with values
			/*UPDATE ts
			SET ts.LicensePlate1=id.LicensePlateNo1, ts.LicensePlate2=id.LicensePlateNo2
			FROM tblTransport ts INNER JOIN @Included id ON id.ID=ts.GLABsID
			WHERE id.DataType='shipments'
			*/
			UPDATE tc
			SET tc.QtyMismatchFlg=CASE id.loadingQuantityMismatch WHEN NULL THEN 1 WHEN 'null' THEN 1 WHEN 'true' THEN 1 WHEN 'false' THEN 0 END
			FROM tblCargo tc INNER JOIN @Included id ON id.ID=tc.SourceOperationsID
			WHERE id.DataType='cargoOperations'

			UPDATE tc
			SET tc.QtyMismatchFlg=CASE id.loadingQuantityMismatch WHEN NULL THEN 1 WHEN 'null' THEN 1 WHEN 'true' THEN 1 WHEN 'false' THEN 0 END
			FROM tblCargo tc INNER JOIN @Included id ON id.ID=tc.DestinationOperationsID
			WHERE id.DataType='cargoOperations'

			UPDATE tss
			SET tss.DriverPhone=(adm.PhoneCountry+adm.PhoneNumber),tss.LicensePlate1=adm.LicensePlateNo1, tss.LicensePlate2=adm.LicensePlateNo2
			FROM tblTransport tss INNER JOIN tblShipment ts ON ts.TransportID=tss.TransportNo
			INNER JOIN 	@Admin adm ON adm.StationID=ts.StationID 

			INSERT INTO [dbo].[tblShipmentStatusQueue]
						   ([StationID]
						   ,[ActionDate]
						   ,[CurrentStatus]
						   ,[SaveDate]
						   ,[ProcessStatus])
				SELECT 
					cs.StationID,
					cs.AdminDateTime,
					4,
					GETDATE(),
					0
				FROM @Admin cs
				WHERE NOT EXISTS(SELECT * FROM [dbo].[tblShipmentStatusQueue] qs WHERE qs.StationID=cs.StationID AND qs.CurrentStatus=@Status)
				AND NOT EXISTS(SELECT ts.StationID FROm tblShipment ts INNER JOIN tblCargo tc ON tc.TransportID=ts.TransportID AND tc.SourceSiteCode=ts.SiteCode AND tc.QtyMismatchFlg=1 AND ts.StationID=cs.StationID
				UNION
				SELECT ts.StationID FROm tblShipment ts INNER JOIN tblCargo tc ON tc.TransportID=ts.TransportID AND tc.DestinationSiteCode=ts.SiteCode AND tc.QtyMismatchFlg=1 AND ts.StationID=cs.StationID)

				UPDATE tc
				SET tc.BorderCrossingID=bb.BorderID
				FROM [dbo].[tblCargo] tc INNER JOIN @Border bb ON bb.CargoID=tc.GLABsID
		END

		IF EXISTS(SELECT * FROM @Stations WHERE ShipmentStatus=5)
		BEGIN
		
		DECLARE @Arrivals TABLE(
			OperationID VARCHAR(50),
			ArrivalDate BIGINT,
			ArrivalDateTime DATETIME)

        DECLARE @Borders TABLE(
					CargoID NVARCHAR(50),
					BorderID NVARCHAR(100)
				)

		INSERT INTO @Arrivals(OperationID,ArrivalDate)
		SELECT operationid,estimatedArrival
		FROM OPENJSON(@Msg,'$.included')
		WITH (
			operationid VARCHAR(50) '$.id',
			estimatedArrival BIGINT '$.attributes.estimatedArrival'
		);

		INSERT INTO @Borders(CargoID,BorderID)
		SELECT CargoID,BorderCrossingPoint
		FROM OPENJSON(@Msg,'$.included')
		WITH (
			CargoID NVARCHAR(50) '$.relationships.cargo.data.id',
			BorderCrossingPoint NVARCHAR(100) '$.relationships.borderCrossingPoint.data.id'
		)
		WHERE BorderCrossingPoint IS NOT NULL


		UPDATE @Arrivals
		SET ArrivalDateTime= dateadd(S, ArrivalDate, '1970-01-01') AT TIME ZONE 'Central European Standard Time'

		UPDATE @Arrivals 
		SET ArrivalDateTime =DATEADD(hour,DATEDIFF(hour,GETUTCDATE(), GETDATE()),  ArrivalDateTime );

		UPDATE tc
		SET tc.ArrivalDate=ad.ArrivalDateTime
		FROM tblCargo tc INNER JOIN @Arrivals ad ON ad.OperationID= tc.SourceOperationsID

		UPDATE tc
		SET tc.ArrivalDate=ad.ArrivalDateTime
		FROM tblCargo tc INNER JOIN @Arrivals ad ON ad.OperationID= tc.DestinationOperationsID

		--Update Border data
		UPDATE tc
		SET tc.BorderCrossingID=bb.BorderID
		FROM [dbo].[tblCargo] tc INNER JOIN @Borders bb ON bb.CargoID=tc.GLABsID

		--SELECT * FROM @Arrivals


		DECLARE @CheckOut TABLE(
				StationID VARCHAR(50),
				CheckOutDate BIGINT,
				CheckOutDateTime DATETIME
			)
			INSERT INTO @CheckOut(StationID,CheckOutDate)
			SELECT StationID,CheckOutDate
			FROM OPENJSON(@Msg,'$.data')
			WITH (
				StationID NVARCHAR(100) '$.id',
				CheckOutDate BIGINT '$.attributes.stage.current.time'
			);

			UPDATE @CheckOut
			SET CheckOutDateTime= dateadd(S, CheckOutDate, '1970-01-01') AT TIME ZONE 'Central European Standard Time'

			UPDATE @CheckOut 
			SET CheckOutDateTime =DATEADD(hour,DATEDIFF(hour,GETUTCDATE(), GETDATE()),  CheckOutDateTime );

			--Delete where not relevant
			DELETE ck FROM  @CheckOut ck WHERE ck.StationID NOT IN(SELECT StationID FROM @Stations WHERE ShipmentStatus=5)

			INSERT INTO [dbo].[tblShipmentStatusQueue]
						   ([StationID]
						   ,[ActionDate]
						   ,[CurrentStatus]
						   ,[SaveDate]
						   ,[ProcessStatus])
			SELECT 
				cs.StationID,
				cs.CheckOutDateTime,
				5,
				GETDATE(),
				0
			FROM @CheckOut cs
			WHERE NOT EXISTS(SELECT * FROM [dbo].[tblShipmentStatusQueue] qs WHERE qs.StationID=cs.StationID AND qs.CurrentStatus=5)	

		END

		/*
		DECLARE @Stages TABLE(
			StationID VARCHAR(50),
			Stage VARCHAR(20),
			StatusID SMALLINT,
			PhoneNumber VARCHAR(50),
			PhoneCountry VARCHAR(10)
		)
		INSERT INTO @Stages(StationID,Stage,PhoneNumber,PhoneCountry)
		SELECT StationID,ISNULL(Stage,'otw'),PhoneNumber,PhoneCountry
		FROM OPENJSON(@Msg,'$.data')
		WITH (
			StationID NVARCHAR(100) '$.id',
			Stage NVARCHAR(100) '$.attributes.stage.current.name',
			PhoneNumber VARCHAR(50) '$.attributes.driver.phoneNumber',
			PhoneCountry VARCHAR(10) '$.attributes.driver.phoneCountryCode'

		);


		UPDATE st
		SET st.StatusID=tss.id
		FROM @Stages st INNER JOIN tblShipmentStatus tss ON tss.StatusName=st.Stage

		DECLARE @QtyMismatch TABLE(
			DataType VARCHAR(50),
			ID VARCHAR(50),
			loadingQuantityMismatch VARCHAR(10)
		)
		INSERT INTO @QtyMismatch(DataType,ID,loadingQuantityMismatch)
		SELECT DataType, ID, loadingQuantityMismatch
		FROM OPENJSON(@Msg,'$.included')
		WITH (
			DataType VARCHAR(50) '$.type',
			ID VARCHAR(50) '$.id',
			loadingQuantityMismatch VARCHAR(10) '$.attributes.loadingQuantityMismatch'
		);

		UPDATE tc
		SET tc.QtyMismatchFlg=CASE qm.loadingQuantityMismatch WHEN NULL THEN NULL WHEN 'true' THEN 1 WHEN 'false' THEN 0 END
		FROM tblCargo tc INNER JOIN @QtyMismatch qm ON qm.ID=tc.CargoOperationsID

		UPDATE tss
		SET tss.ShipmentStatus=sta.StatusID,tss.SAPStatus=
		CASE WHEN EXISTS(SELECT tc.id FROM tblCargo tc WHERE tc.TransportID=tss.TransportID AND (QtyMismatchFlg<>0)) THEN NULL ELSE 0 END,
		tss.DriverPhone=(sta.PhoneCountry+sta.PhoneNumber)
		FROM tblShipment tss INNER JOIN @Stages sta ON
		sta.StationID=tss.StationID --AND sta.StatusID<>tss.ShipmentStatus 
		*/
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
					EXECUTE [dbo].[spListCargo226]
						@SiteCode=@SiteCode,
						@Status=@Status,
						@Page=@Page,
						@SuccessFlg=@SuccessFlg
					SET @Page=@Page+1
				END
			END

		END
END
	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListCargo','@SiteCode='+@SiteCode+',@Status='+CAST(@Status AS varchar(10))+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,1,13,@TransferID
	
	IF EXISTS(SELECT * FROM tblShipmentStatusExecution sse WHERE sse.id=@Status AND sse.SiteCode=@SiteCode)
	BEGIN
		UPDATE sse
		SET sse.LastRunDate=GETDATE()
		FROM tblShipmentStatusExecution sse WHERE sse.id=@Status AND sse.SiteCode=@SiteCode
	END
	ELSE
	BEGIN
		INSERT INTO tblShipmentStatusExecution
		SELECT @Status,@SiteCode,GETDATE()
	END
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	SELECT @TransferID=IDENT_CURRENT('tblTransferOut')

	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spListCargo','@SiteCode='+@SiteCode+',@Status='+CAST(@Status AS varchar(10))+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,13,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
