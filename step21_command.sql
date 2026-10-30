DECLARE @Stations TABLE(
	TransportNo VARCHAR(50),
	BookingDate DATETIME,
	StationID VARCHAR(50),
	SiteCodeFrom VARCHAR(10),
	SiteCodeTo VARCHAR(10),
	NewBookingDate DATETIME,
	Cntr SMALLINT,
	SlotFlg BIT,
	NewBookingSuccess BIT,
	NewBookingSlot DATETIME
)

DECLARE @BookingMap TABLE(
	RowID INT IDENTITY(1,1),
	SiteCode VARCHAR(10),
	StationID VARCHAR(50),
	BookingDate DATETIME,
	SuccessFlg BIT
)


INSERT INTO @Stations(TransportNo,BookingDate)
SELECT TransportID, MAX(BookingDate) FROM tblShipment ts
WHERE EXISTS(
SELECT * FROM tblShipment ts2 WHERE ts2.TransportID=ts.TransportID AND ts2.StationID IS NOT NULL AND ts2.BookingDate IS NULL
) AND EXISTS(
SELECT * FROM tblShipment ts2 WHERE ts2.TransportID=ts.TransportID AND ts2.StationID IS NOT NULL AND ts2.BookingDate IS NOT NULL
)
GROUP BY TransportID
HAVING COUNT(*)>1


UPDATE s
SET s.SiteCodeFrom=(SELECT TOP 1 ts.SiteCode FROM tblShipment ts WHERE ts.TransportID=s.TransportNo AND ts.BookingDate=s.BookingDate )
FROM @Stations s

UPDATE s
SET s.SiteCodeTo=(SELECT TOP 1 ts.SiteCode FROM tblShipment ts WHERE ts.TransportID=s.TransportNo AND ts.BookingDate IS NULL )
FROM @Stations s

UPDATE s
SET s.StationID=(SELECT TOP 1 ts.StationID FROM tblShipment ts WHERE ts.TransportID=s.TransportNo AND ts.SiteCode=s.SiteCodeTo )
FROM @Stations s

UPDATE s
SET s.Cntr=10
FROM @Stations s

DELETE FROM @Stations WHERE BookingDate<GETDATE()-1

SELECT * FROm @Stations

--FirstLoop: generate Transfer times
DECLARE 
		@StationID VARCHAR(50),
		@CurrentBookingDate DATETIME,
		@BookingDate DATETIME,
		@FromSiteCode VARCHAR(10),
		@ToSiteCode VARCHAR(10)

WHILE EXISTS(SELECT * FROM @Stations s WHERE s.NewBookingDate IS NULL)
BEGIN
	SELECT TOP 1 @FromSiteCode = s.SiteCodeFrom, @ToSiteCode = s.SiteCodeTo, @CurrentBookingDate = s.BookingDate, @StationID= s.StationID   FROM  @Stations s WHERE s.NewBookingDate IS NULL

	IF(@FromSiteCode=''H6K1'')  --6:00-15:45
	BEGIN
		IF(@ToSiteCode=''H6K2'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,120,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H6K4'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,240,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H6K5'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,60,@CurrentBookingDate)
		END
	END
	IF(@FromSiteCode=''H6K2'') --6:00-17:45
	BEGIN
		IF(@ToSiteCode=''H6K1'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,120,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H6K4'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,360,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H6K5'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,120,@CurrentBookingDate)
		END
	END
	IF(@FromSiteCode=''H6K4'')--8:00-16:00
	BEGIN
		IF(@ToSiteCode=''H6K1'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,360,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H6K2'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,240,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H6K5'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,360,@CurrentBookingDate)
		END
	END
	IF(@FromSiteCode=''H6K5'') --8:00-16:00
	BEGIN
		IF(@ToSiteCode=''H6K1'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,60,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H6K2'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,120,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H6K4'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,360,@CurrentBookingDate)
		END
	END

	IF(@FromSiteCode=''H311'')  --6:00-15:45
	BEGIN
		IF(@ToSiteCode=''H312'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,120,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H315'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,240,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H314'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,60,@CurrentBookingDate)
		END
	END
	IF(@FromSiteCode=''H312'') --6:00-17:45
	BEGIN
		IF(@ToSiteCode=''H311'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,120,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H315'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,360,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H314'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,120,@CurrentBookingDate)
		END
	END
	IF(@FromSiteCode=''H315'')--8:00-16:00
	BEGIN
		IF(@ToSiteCode=''H311'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,360,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H312'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,240,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H314'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,360,@CurrentBookingDate)
		END
	END
	IF(@FromSiteCode=''H314'') --8:00-16:00
	BEGIN
		IF(@ToSiteCode=''H311'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,60,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H312'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,120,@CurrentBookingDate)
		END
		ELSE IF(@ToSiteCode=''H315'')
		BEGIN
			SET @BookingDate=DATEADD(MINUTE,360,@CurrentBookingDate)
		END
	END

	IF(@BookingDate<GETDATE())
	BEGIN
		SET @BookingDate=DATEADD(MINUTE,60,GETDATE())
		--SET @BookingDate=GETDATE()+2.05
	END 

	SET @BookingDate=DATEADD(MINUTE,(DATEDIFF(MINUTE, 0, @BookingDate) + 7) / 15 * 15, 0)

	UPDATE @Stations
	SET NewBookingDate=@BookingDate
	WHERE StationID=@StationID

END

---------------------------------------------
--Now
DECLARE @Cntr SMALLINT, @StartTime TIME, @EndTime TIME, @DayNum SMALLINT, @SlotDate DATETIME, @SiteCode VARCHAR(10), @CurrentDate DATE, @CurrentTime TIME
SET DATEFIRST 1;
WHILE EXISTS(SELECT * FROm @Stations WHERE SlotFlg IS NULL)
BEGIN
	SELECT TOP 1 @SiteCode= s.SiteCodeTo, @Cntr = s.Cntr, @SlotDate = s.NewBookingDate, @StationID =s.StationID FROM @Stations s WHERE s.SlotFlg IS NULL
	IF(@SiteCode IN (''H6K1'',''H311''))
	BEGIN
		SET @StartTime = ''06:00:00'';
		SET @EndTime = ''15:30:00'';
	END
	ELSE IF(@SiteCode IN (''H6K2'',''H312''))
	BEGIN
		SET @StartTime = ''06:00:00'';
		SET @EndTime = ''17:30:00'';
	END
	ELSE 
	BEGIN
		SET @StartTime = ''08:00:00'';
		SET @EndTime = ''15:45:00'';
	END

	WHILE(@Cntr>0)
	BEGIN 
		--SELECT @StationID, @SlotDate, @Cntr
		--First select correct day
		SELECT @DayNum = DATEPART(WEEKDAY, @SlotDate) 
		IF(@DayNum=6)
		BEGIN
			SELECT @CurrentDate = CONVERT(DATE, @SlotDate)
			SET @CurrentDate=DATEADD(DAY,2, @CurrentDate)
			SET @CurrentTime=@StartTime
		END
		ELSE IF(@DayNum=7)
		BEGIN
			SELECT @CurrentDate = CONVERT(DATE, @SlotDate)
			SET @CurrentDate=DATEADD(DAY,1, @CurrentDate)
			SET @CurrentTime=@StartTime
		END
		ELSE
		BEGIN
		--Check if with loading time
			IF(CONVERT(TIME, @SlotDate) <@StartTime)
			BEGIN
				SELECT @CurrentDate = CONVERT(DATE, @SlotDate)
				SET @CurrentTime=@StartTime
			END
			ELSE IF(CONVERT(TIME, @SlotDate)>= @EndTime)
			BEGIN
				IF(@DayNum<5)
				BEGIN
					SELECT @CurrentDate = CONVERT(DATE, @SlotDate)
					SET @CurrentDate=DATEADD(DAY,1, @CurrentDate)
					SET @CurrentTime=@StartTime
				END
				ELSE IF(@DayNum=5)
				BEGIN
					SELECT @CurrentDate = CONVERT(DATE, @SlotDate)
					SET @CurrentDate=DATEADD(DAY,3, @CurrentDate)
					SET @CurrentTime=@StartTime
				END
			END
			ELSE
			BEGIN
				SELECT @CurrentDate = CONVERT(DATE, @SlotDate)
				SET @CurrentTime=CONVERT(TIME,@SlotDate)
			END
		END
			
		SET @SlotDate=CAST(CONVERT(VARCHAR(10), @CurrentDate, 120) + '' '' + CONVERT(VARCHAR(8), @CurrentTime, 108) AS DATETIME);

		INSERT INTO @BookingMap(SiteCode,StationID, BookingDate)
		SELECT @SiteCode,@StationID,@SlotDate
		
		--Decrease counter
		SET @Cntr=@Cntr-1

		--Add 15 mins to slot
		SET @SlotDate=DATEADD(MINUTE,15,@SlotDate)
	END
	
	UPDATE @Stations
	SET SlotFlg=1
	WHERE StationID=@StationID
END



DECLARE 
	 @UpdSiteCode varchar(15)
	,@UpdStationID varchar(50)
	,@UpdBookingDate datetime
	,@UpdRowID INT
	,@SuccessFlg bit

---Try to Update make booking then
WHILE EXISTS(SELECT * FROM  @BookingMap WHERE SuccessFlg IS NULL)
BEGIN
	SELECT TOP 1 @UpdSiteCode = SiteCode, @UpdStationID = StationID, @UpdBookingDate = BookingDate,@UpdRowID=RowID FROM  @BookingMap WHERE SuccessFlg IS NULL ORDER BY RowID

	EXECUTE [dbo].[spUpdateStationBookingv236] 
	   @SiteCode=@UpdSiteCode
	  ,@StationID=@UpdStationID
	  ,@BookingDate=@UpdBookingDate
	  ,@SuccessFlg=@SuccessFlg OUTPUT

	  IF(@SuccessFlg=0)
	  BEGIN
		UPDATE @BookingMap
		SET SuccessFlg=0
		WHERE RowID=@UpdRowID
	  END
	  ELSE IF(@SuccessFlg=1)
	  BEGIN
		UPDATE @BookingMap
		SET SuccessFlg=1
		WHERE RowID=@UpdRowID

		SELECT @UpdStationID
		SELECT * FROm @BookingMap

		DELETE FROM @BookingMap WHERE StationID=@UpdStationID AND SuccessFlg IS NULL

		UPDATE @Stations
		SET NewBookingSuccess=1, NewBookingSlot=@UpdBookingDate
		WHERE StationID=@UpdStationID
	  END

END

--UPDATE Stations where only Failed
UPDATE @Stations
SET NewBookingSuccess=0
WHERE NewBookingSuccess IS NULL

--Update tblShipment
UPDATE ts
SET ts.BookingDate=s.NewBookingSlot, ts.ShipmentStatus=1,ts.SAPStatus=0
FROM tblShipment ts
INNER JOIN @Stations s ON s.StationID=ts.StationID
WHERE s.NewBookingSuccess=1

UPDATE ts
SET  ts.ShipmentStatus=-1
FROM tblShipment ts
INNER JOIN @Stations s ON s.StationID=ts.StationID
WHERE s.NewBookingSuccess=0


--SELECT * FROm @Stations
--SELECT * FROM @BookingMap