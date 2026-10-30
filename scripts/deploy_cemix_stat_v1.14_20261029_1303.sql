/*==============================================================================
  CEMIX S/4HANA MIDDLEWARE - STAT HISTORY MIGRATION & OPTIMIZATION
  Version:   v1.14
  Date:      2026-10-29 13:03
  Source DB: [Middleware_prod]
  Target DB: [Middleware_dev]

  Summary of actions:
  1. Create missing Stat tables (tblTaskHistory, tblTaskWorkHistory, tmpStat1..3)
     and widen StationID to VARCHAR(50) on tblShipmentHistory/Log/Stat.
  2. Migrate historical data directly from [Middleware_prod] to [Middleware_dev]
     via cross-database INSERT (including tblUsers sync and tblShipment.HistoryFlg).
  3. Create performance indexes on StationID, TaskID, WorkID, ProfileUserID.
  4. Deploy optimized spGetStationHistory, spSaveStationHistory, spListTasks.
  5. Recreate SQL Agent Job [Collect Stat data] pointing to [Middleware_dev].
==============================================================================*/

USE [Middleware_dev]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*==============================================================================
  STEP 1: CREATE MISSING TABLES & ENSURE COLUMN SIZES
==============================================================================*/

IF OBJECT_ID('[dbo].[tblShipmentHistory]', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[tblShipmentHistory](
		[id] [int] IDENTITY(1,1) NOT NULL,
		[SiteCode] [varchar](20) NULL,
		[StationID] [varchar](50) NULL,
		[ChangeID] [varchar](50) NULL,
		[Status] [varchar](50) NULL,
		[ChangeDate] [datetime] NULL,
		[UserID] [varchar](50) NULL,
		[StageFlg] [bit] NULL,
		[ProcessFlg] [bit] NULL,
		PRIMARY KEY CLUSTERED ([id] ASC)
	) ON [PRIMARY];
END
ELSE
BEGIN
	ALTER TABLE [dbo].[tblShipmentHistory] ALTER COLUMN [StationID] [varchar](50) NULL;
END
GO

IF OBJECT_ID('[dbo].[tblShipmentLog]', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[tblShipmentLog](
		[id] [int] IDENTITY(1,1) NOT NULL,
		[SiteCode] [varchar](20) NULL,
		[StationID] [varchar](50) NULL,
		[PickingFlg] [bit] NULL,
		[LoadingFlg] [bit] NULL,
		[StartID] [int] NULL,
		[EndID] [int] NULL,
		[StartDate] [datetime] NULL,
		[EndDate] [datetime] NULL,
		[LogTime] [int] NULL,
		[UserID] [varchar](50) NULL,
		[ExcludeFlg] [bit] NULL,
		PRIMARY KEY CLUSTERED ([id] ASC)
	) ON [PRIMARY];
END
ELSE
BEGIN
	ALTER TABLE [dbo].[tblShipmentLog] ALTER COLUMN [StationID] [varchar](50) NULL;
END
GO

IF OBJECT_ID('[dbo].[tblShipmentStat]', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[tblShipmentStat](
		[id] [int] IDENTITY(1,1) NOT NULL,
		[SiteCode] [varchar](20) NULL,
		[StationID] [varchar](50) NULL,
		[ShipmentDate] [date] NULL,
		[Latency] [smallint] NULL,
		[PickingTime] [smallint] NULL,
		[WaitingTime] [smallint] NULL,
		[LoadingTime] [smallint] NULL,
		[CheckOutTime] [smallint] NULL,
		[ColliIn] [int] NULL,
		[WeightIn] [numeric](18, 3) NULL,
		[ColliOut] [int] NULL,
		[WeightOut] [numeric](18, 3) NULL,
		[PackagePrepared] [smallint] NULL,
		PRIMARY KEY CLUSTERED ([id] ASC)
	) ON [PRIMARY];
END
ELSE
BEGIN
	ALTER TABLE [dbo].[tblShipmentStat] ALTER COLUMN [StationID] [varchar](50) NULL;
END
GO

IF OBJECT_ID('[dbo].[tblTaskHistory]', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[tblTaskHistory](
		[SiteCode] [varchar](10) NULL,
		[TaskID] [varchar](100) NULL,
		[TaskName] [nvarchar](200) NULL,
		[TaskDescription] [nvarchar](2000) NULL,
		[CreateDate] [datetime] NULL,
		[Deadline] [datetime] NULL,
		[FinishDate] [datetime] NULL,
		[TotalWork] [int] NULL,
		[Priority] [int] NULL
	) ON [PRIMARY];
END
GO

IF OBJECT_ID('[dbo].[tblTaskWorkHistory]', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[tblTaskWorkHistory](
		[SiteCode] [varchar](10) NULL,
		[TaskID] [varchar](100) NULL,
		[WorkID] [varchar](100) NULL,
		[StartDate] [datetime] NULL,
		[EndDate] [datetime] NULL,
		[WorkTime] [int] NULL,
		[UserID] [nvarchar](100) NULL
	) ON [PRIMARY];
END
GO

IF OBJECT_ID('[dbo].[tmpStat1]', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[tmpStat1](
		[SiteCode] [varchar](20) NULL,
		[Picker] [varchar](50) NULL,
		[Loader] [varchar](50) NULL,
		[StationID] [varchar](50) NULL,
		[ShipmentDate] [date] NULL,
		[Weight] [numeric](24, 8) NULL,
		[Package] [int] NULL,
		[PackagePrepared] [smallint] NULL,
		[TransportID] [varchar](100) NOT NULL,
		[WeekNo] [int] NULL,
		[Year] [int] NULL,
		[WeightPrepared] [numeric](38, 6) NOT NULL
	) ON [PRIMARY];
END
ELSE
BEGIN
	ALTER TABLE [dbo].[tmpStat1] ALTER COLUMN [StationID] [varchar](50) NULL;
END
GO

IF OBJECT_ID('[dbo].[tmpStat2]', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[tmpStat2](
		[SiteCode] [varchar](20) NULL,
		[Picker] [varchar](50) NULL,
		[Loader] [varchar](50) NULL,
		[StationID] [varchar](50) NULL,
		[ShipmentDate] [date] NULL,
		[Weight] [numeric](24, 8) NULL,
		[Package] [int] NULL,
		[PackagePrepared] [smallint] NULL,
		[TransportID] [varchar](100) NOT NULL,
		[WeekNo] [int] NULL,
		[Year] [int] NULL,
		[WeightPrepared] [numeric](38, 6) NOT NULL
	) ON [PRIMARY];
END
ELSE
BEGIN
	ALTER TABLE [dbo].[tmpStat2] ALTER COLUMN [StationID] [varchar](50) NULL;
END
GO

IF OBJECT_ID('[dbo].[tmpStat3]', 'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[tmpStat3](
		[UserID] [varchar](50) NULL,
		[WeekNo] [int] NULL,
		[Year] [int] NULL,
		[SiteCode] [varchar](20) NULL
	) ON [PRIMARY];
END
GO

/*==============================================================================
  STEP 2: MIGRATE HISTORICAL DATA FROM [Middleware_prod] TO [Middleware_dev]
==============================================================================*/

-- 2.1 tblShipmentHistory
TRUNCATE TABLE [Middleware_dev].[dbo].[tblShipmentHistory];
SET IDENTITY_INSERT [Middleware_dev].[dbo].[tblShipmentHistory] ON;

INSERT INTO [Middleware_dev].[dbo].[tblShipmentHistory] (
	[id], [SiteCode], [StationID], [ChangeID], [Status], [ChangeDate], [UserID], [StageFlg], [ProcessFlg]
)
SELECT
	[id], [SiteCode], [StationID], [ChangeID], [Status], [ChangeDate], [UserID], [StageFlg], [ProcessFlg]
FROM [Middleware_prod].[dbo].[tblShipmentHistory];

SET IDENTITY_INSERT [Middleware_dev].[dbo].[tblShipmentHistory] OFF;
GO

-- 2.2 tblShipmentLog
TRUNCATE TABLE [Middleware_dev].[dbo].[tblShipmentLog];
SET IDENTITY_INSERT [Middleware_dev].[dbo].[tblShipmentLog] ON;

INSERT INTO [Middleware_dev].[dbo].[tblShipmentLog] (
	[id], [SiteCode], [StationID], [PickingFlg], [LoadingFlg], [StartID], [EndID], [StartDate], [EndDate], [LogTime], [UserID], [ExcludeFlg]
)
SELECT
	[id], [SiteCode], [StationID], [PickingFlg], [LoadingFlg], [StartID], [EndID], [StartDate], [EndDate], [LogTime], [UserID], [ExcludeFlg]
FROM [Middleware_prod].[dbo].[tblShipmentLog];

SET IDENTITY_INSERT [Middleware_dev].[dbo].[tblShipmentLog] OFF;
GO

-- 2.3 tblShipmentStat
TRUNCATE TABLE [Middleware_dev].[dbo].[tblShipmentStat];
SET IDENTITY_INSERT [Middleware_dev].[dbo].[tblShipmentStat] ON;

INSERT INTO [Middleware_dev].[dbo].[tblShipmentStat] (
	[id], [SiteCode], [StationID], [ShipmentDate], [Latency], [PickingTime], [WaitingTime], [LoadingTime], [CheckOutTime],
	[ColliIn], [WeightIn], [ColliOut], [WeightOut], [PackagePrepared]
)
SELECT
	[id], [SiteCode], [StationID], [ShipmentDate], [Latency], [PickingTime], [WaitingTime], [LoadingTime], [CheckOutTime],
	[ColliIn], [WeightIn], [ColliOut], [WeightOut], [PackagePrepared]
FROM [Middleware_prod].[dbo].[tblShipmentStat];

SET IDENTITY_INSERT [Middleware_dev].[dbo].[tblShipmentStat] OFF;
GO

-- 2.4 tblTaskHistory
TRUNCATE TABLE [Middleware_dev].[dbo].[tblTaskHistory];

INSERT INTO [Middleware_dev].[dbo].[tblTaskHistory] (
	[SiteCode], [TaskID], [TaskName], [TaskDescription], [CreateDate], [Deadline], [FinishDate], [TotalWork], [Priority]
)
SELECT
	[SiteCode], [TaskID], [TaskName], [TaskDescription], [CreateDate], [Deadline], [FinishDate], [TotalWork], [Priority]
FROM [Middleware_prod].[dbo].[tblTaskHistory];
GO

-- 2.5 tblTaskWorkHistory
TRUNCATE TABLE [Middleware_dev].[dbo].[tblTaskWorkHistory];

INSERT INTO [Middleware_dev].[dbo].[tblTaskWorkHistory] (
	[SiteCode], [TaskID], [WorkID], [StartDate], [EndDate], [WorkTime], [UserID]
)
SELECT
	[SiteCode], [TaskID], [WorkID], [StartDate], [EndDate], [WorkTime], [UserID]
FROM [Middleware_prod].[dbo].[tblTaskWorkHistory];
GO

-- 2.6 tmpStat1, tmpStat2, tmpStat3
TRUNCATE TABLE [Middleware_dev].[dbo].[tmpStat1];

INSERT INTO [Middleware_dev].[dbo].[tmpStat1] (
	[SiteCode], [Picker], [Loader], [StationID], [ShipmentDate], [Weight], [Package], [PackagePrepared], [TransportID], [WeekNo], [Year], [WeightPrepared]
)
SELECT
	[SiteCode], [Picker], [Loader], [StationID], [ShipmentDate], [Weight], [Package], [PackagePrepared], [TransportID], [WeekNo], [Year], [WeightPrepared]
FROM [Middleware_prod].[dbo].[tmpStat1];
GO

TRUNCATE TABLE [Middleware_dev].[dbo].[tmpStat2];

INSERT INTO [Middleware_dev].[dbo].[tmpStat2] (
	[SiteCode], [Picker], [Loader], [StationID], [ShipmentDate], [Weight], [Package], [PackagePrepared], [TransportID], [WeekNo], [Year], [WeightPrepared]
)
SELECT
	[SiteCode], [Picker], [Loader], [StationID], [ShipmentDate], [Weight], [Package], [PackagePrepared], [TransportID], [WeekNo], [Year], [WeightPrepared]
FROM [Middleware_prod].[dbo].[tmpStat2];
GO

TRUNCATE TABLE [Middleware_dev].[dbo].[tmpStat3];

INSERT INTO [Middleware_dev].[dbo].[tmpStat3] (
	[UserID], [WeekNo], [Year], [SiteCode]
)
SELECT
	[UserID], [WeekNo], [Year], [SiteCode]
FROM [Middleware_prod].[dbo].[tmpStat3];
GO

-- 2.7 Sync missing users & ReportFlg from [Middleware_prod].[dbo].[tblUsers]
INSERT INTO [Middleware_dev].[dbo].[tblUsers] (
	[SiteCode], [ProfileUserID], [FirstName], [LastName], [Email], [Position], [ReportFlg]
)
SELECT
	src.[SiteCode], src.[ProfileUserID], src.[FirstName], src.[LastName], src.[Email], src.[Position], ISNULL(src.[ReportFlg], 0)
FROM [Middleware_prod].[dbo].[tblUsers] src
WHERE NOT EXISTS (
	SELECT 1
	FROM [Middleware_dev].[dbo].[tblUsers] dst
	WHERE dst.ProfileUserID = src.ProfileUserID
);

UPDATE dst
SET dst.ReportFlg = src.ReportFlg
FROM [Middleware_dev].[dbo].[tblUsers] dst
INNER JOIN [Middleware_prod].[dbo].[tblUsers] src
	ON src.ProfileUserID = dst.ProfileUserID
WHERE dst.ReportFlg <> src.ReportFlg;
GO

-- 2.8 Mark HistoryFlg = 1 on [Middleware_dev].[dbo].[tblShipment] for already-collected stations
UPDATE ts
SET ts.HistoryFlg = 1
FROM [Middleware_dev].[dbo].[tblShipment] ts
WHERE ts.HistoryFlg IS NULL
  AND EXISTS (
	  SELECT 1
	  FROM [Middleware_dev].[dbo].[tblShipmentStat] tss
	  WHERE tss.StationID = ts.StationID
  );
GO

/*==============================================================================
  STEP 3: CREATE PERFORMANCE INDEXES
==============================================================================*/

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tblShipmentHistory_StationID' AND object_id = OBJECT_ID('[dbo].[tblShipmentHistory]'))
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblShipmentHistory_StationID] ON [dbo].[tblShipmentHistory]
	(
		[StationID] ASC,
		[StageFlg] ASC,
		[Status] ASC
	)
	INCLUDE ([ChangeDate], [UserID]) ON [PRIMARY];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tblShipmentLog_StationID' AND object_id = OBJECT_ID('[dbo].[tblShipmentLog]'))
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblShipmentLog_StationID] ON [dbo].[tblShipmentLog]
	(
		[StationID] ASC,
		[PickingFlg] ASC,
		[LoadingFlg] ASC
	)
	INCLUDE ([LogTime], [UserID], [ExcludeFlg], [StartDate]) ON [PRIMARY];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tblShipmentStat_StationID' AND object_id = OBJECT_ID('[dbo].[tblShipmentStat]'))
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblShipmentStat_StationID] ON [dbo].[tblShipmentStat]
	(
		[StationID] ASC
	)
	INCLUDE ([SiteCode], [ShipmentDate], [Latency], [WeightIn], [WeightOut], [ColliIn], [ColliOut], [PackagePrepared]) ON [PRIMARY];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tblTaskHistory_TaskID' AND object_id = OBJECT_ID('[dbo].[tblTaskHistory]'))
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblTaskHistory_TaskID] ON [dbo].[tblTaskHistory]
	(
		[TaskID] ASC
	)
	INCLUDE ([SiteCode], [CreateDate], [FinishDate]) ON [PRIMARY];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tblTaskWorkHistory_WorkID' AND object_id = OBJECT_ID('[dbo].[tblTaskWorkHistory]'))
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblTaskWorkHistory_WorkID] ON [dbo].[tblTaskWorkHistory]
	(
		[WorkID] ASC
	)
	INCLUDE ([TaskID], [UserID], [WorkTime]) ON [PRIMARY];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tmpStat1_StationID' AND object_id = OBJECT_ID('[dbo].[tmpStat1]'))
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tmpStat1_StationID] ON [dbo].[tmpStat1]
	(
		[StationID] ASC
	)
	INCLUDE ([ShipmentDate], [Picker], [Loader], [WeekNo], [Year], [SiteCode]) ON [PRIMARY];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tmpStat2_Lookup' AND object_id = OBJECT_ID('[dbo].[tmpStat2]'))
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tmpStat2_Lookup] ON [dbo].[tmpStat2]
	(
		[Year] ASC,
		[WeekNo] ASC,
		[SiteCode] ASC
	)
	INCLUDE ([Picker], [Loader]) ON [PRIMARY];
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tblUsers_ProfileUserID' AND object_id = OBJECT_ID('[dbo].[tblUsers]'))
BEGIN
	CREATE NONCLUSTERED INDEX [IX_tblUsers_ProfileUserID] ON [dbo].[tblUsers]
	(
		[ProfileUserID] ASC
	)
	INCLUDE ([FirstName], [LastName], [ReportFlg]) ON [PRIMARY];
END
GO

/*==============================================================================
  STEP 4: DEPLOY OPTIMIZED STORED PROCEDURES
==============================================================================*/

CREATE OR ALTER PROCEDURE [dbo].[spGetStationHistory](
	@SiteCode VARCHAR(10),
	@StationID VARCHAR(50),
	@Page SMALLINT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN
	SET NOCOUNT ON;

	DECLARE @TransferType SMALLINT = 23,
			@URL NVARCHAR(1000),
			@Header NVARCHAR(MAX),
			@MsgType VARCHAR(100) = '',
			@MsgMethod VARCHAR(100) = 'GET',
			@ResponseAccept VARCHAR(100) = 'application/json',
			@Msg NVARCHAR(MAX),
			@Token VARCHAR(100),
			@TransferID INT;

	SELECT @URL = tcpr.[url] + 'api/' + tcpr.[profile id] + '/stations/' + @StationID + '?include=stages,pickingWorks,stages.creator,pickingWorks.creator,currentBooking,currentBooking.creator'
	FROM [dbo].[tblClientParams] tcpr
	WHERE tcpr.SiteCode = @SiteCode;

	-- TOKEN
	EXECUTE spGetToken
		@SiteCode = @SiteCode,
		@Token = @Token OUT,
		@SuccessFlg = @SuccessFlg OUT;

	IF (@SuccessFlg = 0)
	BEGIN
		SET @Msg = 'Token Request Failed';
		INSERT INTO tblLog (SPName, Inparams, Outparams, Msg, SuccessFlg, ProcessID)
		SELECT 'spGetStationHistory', '@SiteCode=' + ISNULL(@SiteCode, '') + ',@StationID=' + ISNULL(@StationID, '') + ',@Page=' + CAST(@Page AS VARCHAR(10)), '', @Msg, 0, 28;
		RETURN;
	END

	SET @Header = 'Authorization: Bearer ' + @Token + '&';

	BEGIN TRY
		-- Insert Transfer
		INSERT INTO tblTransferOut (TransferType, URL, Header, Body, MsgType, MsgMethod, ResponseAccept, Status)
		SELECT @TransferType, @URL, @Header, '', @MsgType, @MsgMethod, @ResponseAccept, 0;

		SELECT @TransferID = SCOPE_IDENTITY();

		-- Execute Webrequest
		EXECUTE spSendWebRequest @TransferID = @TransferID, @SuccessFlg = @SuccessFlg OUT;

		IF (@SuccessFlg = 0)
		BEGIN
			SET @Msg = 'WebRequest Failed';
			INSERT INTO tblLog (SPName, Inparams, Outparams, Msg, SuccessFlg, ProcessID)
			SELECT 'spGetStationHistory', '@SiteCode=' + ISNULL(@SiteCode, '') + ',@StationID=' + ISNULL(@StationID, '') + ',@Page=' + CAST(@Page AS VARCHAR(10)), '', @Msg, 0, 28;
			RETURN;
		END

		SELECT @Msg = tou.ReturnMsg FROM tblTransferOut tou WHERE id = @TransferID;

		-- Update History
		DELETE FROM tblShipmentHistory WHERE StationID = @StationID;

		INSERT INTO tblShipmentHistory (SiteCode, StationID, ChangeID, StageFlg, ChangeDate, UserID, Status)
		SELECT
			@SiteCode,
			@StationID,
			j.ID,
			CASE j.DataType WHEN 'stationStages' THEN 1 ELSE 0 END,
			CAST(DATEADD(SECOND, j.CreatedAt, '1970-01-01') AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS DATETIME),
			j.UserID,
			j.AttributeName
		FROM OPENJSON(@Msg, '$.included')
		WITH (
			DataType      VARCHAR(50)  '$.type',
			ID            VARCHAR(50)  '$.id',
			AttributeName VARCHAR(30)  '$.attributes.name',
			CreatedAt     BIGINT       '$.attributes.createdAt',
			Revoked       NVARCHAR(50) '$.attributes.revoked',
			UserID        VARCHAR(50)  '$.relationships.creator.data.id'
		) j
		WHERE j.DataType <> 'ProfileUsers'
		  AND ISNULL(j.Revoked, '') <> 'true'
		ORDER BY j.CreatedAt;

		-- Parse & Update Users
		DECLARE @User TABLE (
			ID        VARCHAR(50),
			FirstName NVARCHAR(200),
			LastName  NVARCHAR(200),
			Email     NVARCHAR(200),
			Position  NVARCHAR(200)
		);

		INSERT INTO @User (ID, FirstName, LastName, Email, Position)
		SELECT ID, FirstName, LastName, Email, Position
		FROM OPENJSON(@Msg, '$.included')
		WITH (
			DataType  VARCHAR(50)   '$.type',
			ID        VARCHAR(50)   '$.id',
			FirstName NVARCHAR(200) '$.attributes.firstName',
			LastName  NVARCHAR(200) '$.attributes.lastName',
			Email     NVARCHAR(200) '$.attributes.email',
			Position  NVARCHAR(200) '$.attributes.position'
		)
		WHERE DataType = 'ProfileUsers';

		INSERT INTO tblUsers (SiteCode, ProfileUserID, FirstName, LastName, Position, Email)
		SELECT @SiteCode, u.ID, u.FirstName, u.LastName, u.Position, u.Email
		FROM @User u
		WHERE NOT EXISTS (SELECT 1 FROM tblUsers tu WHERE tu.ProfileUserID = u.ID);

		UPDATE tu
		SET
			tu.FirstName = us.FirstName,
			tu.LastName  = us.LastName,
			tu.Position  = us.Position,
			tu.Email     = us.Email
		FROM tblUsers tu
		INNER JOIN @User us ON us.ID = tu.ProfileUserID
		WHERE ISNULL(tu.FirstName, '') <> ISNULL(us.FirstName, '')
		   OR ISNULL(tu.LastName, '')  <> ISNULL(us.LastName, '')
		   OR ISNULL(tu.Position, '')  <> ISNULL(us.Position, '')
		   OR ISNULL(tu.Email, '')     <> ISNULL(us.Email, '');

		INSERT INTO tblLog (SPName, Inparams, Outparams, Msg, SuccessFlg, ProcessID)
		SELECT 'spGetStationHistory', '@SiteCode=' + ISNULL(@SiteCode, '') + ',@StationID=' + ISNULL(@StationID, '') + ',@Page=' + CAST(@Page AS VARCHAR(10)), '', @Msg, 1, 28;

		SET @SuccessFlg = 1;
	END TRY
	BEGIN CATCH
		SELECT @Msg = ERROR_MESSAGE();
		INSERT INTO tblLog (SPName, Inparams, Outparams, Msg, SuccessFlg, ProcessID)
		SELECT 'spGetStationHistory', '@SiteCode=' + ISNULL(@SiteCode, '') + ',@StationID=' + ISNULL(@StationID, '') + ',@Page=' + CAST(@Page AS VARCHAR(10)), '', @Msg, 0, 28;
		SET @SuccessFlg = 0;
	END CATCH
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spSaveStationHistory](
	@StationID VARCHAR(50)
)
AS 
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY	
		DELETE FROM tblShipmentStat WHERE StationID = @StationID;
		DELETE FROM tblShipmentLog WHERE StationID = @StationID;

		-- Insert Picking (StageFlg=0, Status='inprogress') and Loading (StageFlg=1, Status='loading') start events in one pass
		INSERT INTO tblShipmentLog (SiteCode, StationID, PickingFlg, LoadingFlg, StartID, StartDate, UserID, ExcludeFlg)
		SELECT
			tbh.SiteCode,
			tbh.StationID,
			CASE WHEN tbh.StageFlg = 0 THEN 1 ELSE 0 END AS PickingFlg,
			CASE WHEN tbh.StageFlg = 1 THEN 1 ELSE 0 END AS LoadingFlg,
			tbh.id,
			tbh.ChangeDate,
			tbh.UserID,
			0
		FROM tblShipmentHistory tbh
		WHERE tbh.StationID = @StationID
		  AND (
			  (tbh.StageFlg = 0 AND tbh.Status = 'inprogress')
			  OR (tbh.StageFlg = 1 AND tbh.Status = 'loading')
		  );

		-- Match each start event with the next chronological event of the same StageFlg
		UPDATE tsl
		SET
			tsl.EndID      = CASE
								 WHEN tsl.PickingFlg = 1 AND nextEvt.Status = 'closed' THEN nextEvt.id
								 WHEN tsl.LoadingFlg = 1 AND nextEvt.Status IN ('administration', 'closed') THEN nextEvt.id
								 ELSE NULL
							 END,
			tsl.EndDate    = CASE
								 WHEN tsl.PickingFlg = 1 AND nextEvt.Status = 'closed' THEN nextEvt.ChangeDate
								 WHEN tsl.LoadingFlg = 1 AND nextEvt.Status IN ('administration', 'closed') THEN nextEvt.ChangeDate
								 ELSE NULL
							 END,
			tsl.LogTime    = CASE
								 WHEN (tsl.PickingFlg = 1 AND nextEvt.Status = 'closed')
								   OR (tsl.LoadingFlg = 1 AND nextEvt.Status IN ('administration', 'closed'))
								 THEN DATEDIFF(MINUTE, tsl.StartDate, nextEvt.ChangeDate)
								 ELSE NULL
							 END,
			tsl.ExcludeFlg = CASE
								 WHEN (tsl.PickingFlg = 1 AND nextEvt.Status = 'closed')
								   OR (tsl.LoadingFlg = 1 AND nextEvt.Status IN ('administration', 'closed'))
								 THEN 0
								 ELSE 1
							 END
		FROM tblShipmentLog tsl
		OUTER APPLY (
			SELECT TOP 1 tbh.id, tbh.ChangeDate, tbh.Status
			FROM tblShipmentHistory tbh
			WHERE tbh.StationID = tsl.StationID
			  AND tbh.id > tsl.StartID
			  AND (
				  (tsl.PickingFlg = 1 AND tbh.StageFlg = 0)
				  OR (tsl.LoadingFlg = 1 AND tbh.StageFlg = 1)
			  )
			ORDER BY tbh.id ASC
		) nextEvt
		WHERE tsl.StationID = @StationID;

		-- Aggregate Stage timestamps in a single scan of tblShipmentHistory
		DECLARE @MinWaitingDate DATETIME,
				@MinLoadingDate DATETIME,
				@MaxAdminDate   DATETIME,
				@MaxClosedDate  DATETIME,
				@PickingTime    SMALLINT,
				@LoadingTime    SMALLINT;

		SELECT
			@MinWaitingDate = MIN(CASE WHEN tbh.Status = 'waiting'        THEN tbh.ChangeDate END),
			@MinLoadingDate = MIN(CASE WHEN tbh.Status = 'loading'        THEN tbh.ChangeDate END),
			@MaxAdminDate   = MAX(CASE WHEN tbh.Status = 'administration' THEN tbh.ChangeDate END),
			@MaxClosedDate  = MAX(CASE WHEN tbh.Status = 'closed'         THEN tbh.ChangeDate END)
		FROM tblShipmentHistory tbh
		WHERE tbh.StationID = @StationID
		  AND tbh.StageFlg = 1;

		-- Aggregate PickingTime & LoadingTime in a single scan of tblShipmentLog
		SELECT
			@PickingTime = SUM(CASE WHEN tsl.PickingFlg = 1 THEN tsl.LogTime END),
			@LoadingTime = SUM(CASE WHEN tsl.LoadingFlg = 1 THEN tsl.LogTime END)
		FROM tblShipmentLog tsl
		WHERE tsl.StationID = @StationID
		  AND ISNULL(tsl.ExcludeFlg, 0) = 0;

		-- Aggregate Outbound and Inbound Cargo metrics
		DECLARE @ColliIn INT = 0, @WeightIn NUMERIC(18,3) = 0,
				@ColliOut INT = 0, @WeightOut NUMERIC(18,3) = 0, @PackageOut SMALLINT = 0;

		SELECT
			@ColliOut   = ISNULL(SUM(tc.Colli), 0),
			@WeightOut  = ISNULL(SUM(tc.Weight), 0),
			@PackageOut = ISNULL(SUM(ci.PickedCount), 0)
		FROM tblShipment ts
		INNER JOIN tblCargo tc
			ON tc.TransportID = ts.TransportID
		   AND tc.SourceSiteCode = ts.SiteCode
		OUTER APPLY (
			SELECT COUNT(*) AS PickedCount
			FROM tblCargoItem ci
			WHERE ci.DeliveryNo = tc.DeliveryNo
			  AND ci.TransportID = ts.TransportID
			  AND ci.PickingFlg = 1
		) ci
		WHERE ts.StationID = @StationID;

		SELECT
			@ColliIn  = ISNULL(SUM(tc.Colli), 0),
			@WeightIn = ISNULL(SUM(tc.Weight), 0)
		FROM tblShipment ts
		INNER JOIN tblCargo tc
			ON tc.TransportID = ts.TransportID
		   AND tc.DestinationSiteCode = ts.SiteCode
		WHERE ts.StationID = @StationID;

		INSERT INTO tblShipmentStat (
			SiteCode, StationID, ShipmentDate, Latency,
			PickingTime, WaitingTime, LoadingTime, CheckOutTime,
			ColliIn, WeightIn, ColliOut, WeightOut, PackagePrepared
		)
		SELECT
			ts.SiteCode,
			ts.StationID,
			@MinLoadingDate,
			DATEDIFF(MINUTE, ts.BookingDate, @MinWaitingDate),
			@PickingTime,
			DATEDIFF(MINUTE, @MinWaitingDate, @MinLoadingDate),
			@LoadingTime,
			DATEDIFF(MINUTE, ISNULL(@MaxAdminDate, @MinLoadingDate), @MaxClosedDate),
			@ColliIn,
			@WeightIn,
			@ColliOut,
			@WeightOut,
			@PackageOut
		FROM tblShipment ts
		WHERE ts.StationID = @StationID;

		UPDATE tblShipment
		SET HistoryFlg = 1
		WHERE StationID = @StationID;
	END TRY
	BEGIN CATCH
		UPDATE tblShipment
		SET HistoryFlg = 0
		WHERE StationID = @StationID;
	END CATCH
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spListTasks](
	@SiteCode VARCHAR(10),
	@Days INT,
	@Page SMALLINT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN
	SET NOCOUNT ON;

	DECLARE @TransferType SMALLINT = 26,
			@URL NVARCHAR(1000),
			@Header NVARCHAR(MAX),
			@MsgType VARCHAR(100) = '',
			@MsgMethod VARCHAR(100) = 'GET',
			@ResponseAccept VARCHAR(100) = 'application/json',
			@Msg NVARCHAR(MAX),
			@Token VARCHAR(100),
			@TransferID INT,
			@Filter NVARCHAR(200),
			@BookingDateMax VARCHAR(25),
			@BookingDateMin VARCHAR(25);

	SELECT
		@BookingDateMin = CONVERT(VARCHAR(23), DATEADD(DAY, -@Days, GETDATE()), 126),
		@BookingDateMax = CONVERT(VARCHAR(23), GETDATE(), 126);

	SET @Filter = '?filter[finishedAt]>' + @BookingDateMin + '&filter[finishedAt]<' + @BookingDateMax + '&include=works,works.user';

	IF (@Page <> 1)
	BEGIN
		SET @Filter = @Filter + '&page%5Bnumber%5D=' + CAST(@Page AS VARCHAR(10));
	END

	SELECT @URL = tcpr.[url] + 'api/' + tcpr.[profile id] + '/tasks' + @Filter
	FROM [dbo].[tblClientParams] tcpr
	WHERE tcpr.SiteCode = @SiteCode;

	-- TOKEN
	EXECUTE spGetToken
		@SiteCode = @SiteCode,
		@Token = @Token OUT,
		@SuccessFlg = @SuccessFlg OUT;

	IF (@SuccessFlg = 0)
	BEGIN
		SET @Msg = 'Token Request Failed';
		INSERT INTO tblLog (SPName, Inparams, Outparams, Msg, SuccessFlg, ProcessID)
		SELECT 'spListTasks', '@SiteCode=' + ISNULL(@SiteCode, '') + ',@Page=' + CAST(@Page AS VARCHAR(10)), '', @Msg, 0, 28;
		RETURN;
	END

	SET @Header = 'Authorization: Bearer ' + @Token + '&';

	BEGIN TRY
		-- Insert Transfer
		INSERT INTO tblTransferOut (TransferType, URL, Header, Body, MsgType, MsgMethod, ResponseAccept, Status)
		SELECT @TransferType, @URL, @Header, '', @MsgType, @MsgMethod, @ResponseAccept, 0;

		SELECT @TransferID = SCOPE_IDENTITY();

		-- Execute Webrequest
		EXECUTE spSendWebRequest @TransferID = @TransferID, @SuccessFlg = @SuccessFlg OUT;

		IF (@SuccessFlg = 0)
		BEGIN
			SET @Msg = 'WebRequest Failed';
			INSERT INTO tblLog (SPName, Inparams, Outparams, Msg, SuccessFlg, ProcessID)
			SELECT 'spListTasks', '@SiteCode=' + ISNULL(@SiteCode, '') + ',@Page=' + CAST(@Page AS VARCHAR(10)), '', @Msg, 0, 28;
			RETURN;
		END

		DECLARE @MaxPage SMALLINT;
		SELECT @Msg = tou.ReturnMsg FROM tblTransferOut tou WHERE id = @TransferID;

		DECLARE @User TABLE (
			ID        VARCHAR(50),
			FirstName NVARCHAR(200),
			LastName  NVARCHAR(200),
			Email     NVARCHAR(200),
			Position  NVARCHAR(200)
		);

		DECLARE @Tasks TABLE (
			TaskID          VARCHAR(100),
			TaskName        NVARCHAR(200),
			TaskDescription NVARCHAR(2000),
			CreatedAt       DATETIME,
			DeadlineAt      DATETIME,
			Priority        INT,
			Finished        VARCHAR(10)
		);

		DECLARE @TaskWork TABLE (
			TaskID    VARCHAR(100),
			WorkID    VARCHAR(100),
			StartDate DATETIME,
			EndDate   DATETIME,
			WorkTime  INT,
			UserID    NVARCHAR(100)
		);

		INSERT INTO @Tasks (TaskID, TaskName, TaskDescription, CreatedAt, DeadlineAt, Priority, Finished)
		SELECT
			TaskID,
			TaskName,
			TaskDescription,
			CAST(DATEADD(SECOND, CreateDate, '1970-01-01') AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS DATETIME),
			CAST(DATEADD(SECOND, Deadline,   '1970-01-01') AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS DATETIME),
			Priority,
			Finished
		FROM OPENJSON(@Msg, '$.data')
		WITH (
			TaskID          NVARCHAR(100)  '$.id',
			TaskName        NVARCHAR(200)  '$.attributes.name',
			TaskDescription NVARCHAR(2000) '$.attributes.description',
			CreateDate      BIGINT         '$.attributes.createdAt',
			Deadline        BIGINT         '$.attributes.deadline',
			Priority        INT            '$.attributes.priority',
			Finished        VARCHAR(10)    '$.attributes.finish'
		);

		INSERT INTO @User (ID, FirstName, LastName, Email, Position)
		SELECT ID, FirstName, LastName, Email, Position
		FROM OPENJSON(@Msg, '$.included')
		WITH (
			DataType  VARCHAR(50)   '$.type',
			ID        VARCHAR(50)   '$.id',
			FirstName NVARCHAR(200) '$.attributes.firstName',
			LastName  NVARCHAR(200) '$.attributes.lastName',
			Email     NVARCHAR(200) '$.attributes.email',
			Position  NVARCHAR(200) '$.attributes.position'
		)
		WHERE DataType = 'ProfileUsers';

		-- Sync Users into tblUsers
		INSERT INTO tblUsers (SiteCode, ProfileUserID, FirstName, LastName, Position, Email)
		SELECT @SiteCode, u.ID, u.FirstName, u.LastName, u.Position, u.Email
		FROM @User u
		WHERE NOT EXISTS (SELECT 1 FROM tblUsers tu WHERE tu.ProfileUserID = u.ID);

		UPDATE tu
		SET
			tu.FirstName = us.FirstName,
			tu.LastName  = us.LastName,
			tu.Position  = us.Position,
			tu.Email     = us.Email
		FROM tblUsers tu
		INNER JOIN @User us ON us.ID = tu.ProfileUserID
		WHERE ISNULL(tu.FirstName, '') <> ISNULL(us.FirstName, '')
		   OR ISNULL(tu.LastName, '')  <> ISNULL(us.LastName, '')
		   OR ISNULL(tu.Position, '')  <> ISNULL(us.Position, '')
		   OR ISNULL(tu.Email, '')     <> ISNULL(us.Email, '');

		INSERT INTO @TaskWork (TaskID, WorkID, StartDate, EndDate, WorkTime, UserID)
		SELECT
			TaskID,
			WorkID,
			StartDt,
			EndDt,
			DATEDIFF(MINUTE, StartDt, EndDt),
			UserID
		FROM (
			SELECT
				TaskID,
				WorkID,
				CAST(DATEADD(SECOND, StartTime, '1970-01-01') AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS DATETIME) AS StartDt,
				CAST(DATEADD(SECOND, EndTime,   '1970-01-01') AT TIME ZONE 'UTC' AT TIME ZONE 'Central European Standard Time' AS DATETIME) AS EndDt,
				UserID
			FROM OPENJSON(@Msg, '$.included')
			WITH (
				DataType  VARCHAR(50)   '$.type',
				WorkID    VARCHAR(50)   '$.id',
				StartTime BIGINT        '$.attributes.createdAt',
				EndTime   BIGINT        '$.attributes.finishedAt',
				UserID    NVARCHAR(100) '$.relationships.user.data.id',
				TaskID    NVARCHAR(50)  '$.relationships.task.data.id'
			)
			WHERE DataType = 'taskWorks'
		) twCalc;

		INSERT INTO [dbo].[tblTaskHistory] (
			[SiteCode], [TaskID], [TaskName], [TaskDescription],
			[CreateDate], [Deadline], [FinishDate], [TotalWork], [Priority]
		)
		SELECT
			@SiteCode,
			t.TaskID,
			t.TaskName,
			t.TaskDescription,
			t.CreatedAt,
			t.DeadlineAt,
			twAgg.MaxEndDate,
			twAgg.TotalWorkTime,
			t.Priority
		FROM @Tasks t
		OUTER APPLY (
			SELECT
				MAX(tw.EndDate)  AS MaxEndDate,
				SUM(tw.WorkTime) AS TotalWorkTime
			FROM @TaskWork tw
			WHERE tw.TaskID = t.TaskID
		) twAgg
		WHERE NOT EXISTS (SELECT 1 FROM tblTaskHistory th WHERE th.TaskID = t.TaskID);

		INSERT INTO [dbo].[tblTaskWorkHistory] (
			[SiteCode], [TaskID], [WorkID], [StartDate], [EndDate], [WorkTime], [UserID]
		)
		SELECT
			@SiteCode,
			tw.TaskID,
			tw.WorkID,
			tw.StartDate,
			tw.EndDate,
			tw.WorkTime,
			tw.UserID
		FROM @TaskWork tw
		WHERE NOT EXISTS (SELECT 1 FROM tblTaskWorkHistory twh WHERE twh.WorkID = tw.WorkID);

		IF (@Page = 1)
		BEGIN
			SELECT @MaxPage = PageNo
			FROM OPENJSON(@Msg)
			WITH (
				PageNo SMALLINT '$.meta.pagination.pageTotal'
			);

			IF (@MaxPage > 1)
			BEGIN
				SET @Page = @Page + 1;
				WHILE (@Page <= @MaxPage)
				BEGIN
					EXECUTE [dbo].[spListTasks]
						@SiteCode   = @SiteCode,
						@Days       = @Days,
						@Page       = @Page,
						@SuccessFlg = @SuccessFlg OUT;
					SET @Page = @Page + 1;
				END
			END
		END

		INSERT INTO tblLog (SPName, Inparams, Outparams, Msg, SuccessFlg, ProcessID)
		SELECT 'spListTasks', '@SiteCode=' + ISNULL(@SiteCode, '') + ',@Page=' + CAST(@Page AS VARCHAR(10)), '', @Msg, 1, 28;
		SET @SuccessFlg = 1;
	END TRY
	BEGIN CATCH
		SELECT @Msg = ERROR_MESSAGE();
		INSERT INTO tblLog (SPName, Inparams, Outparams, Msg, SuccessFlg, ProcessID)
		SELECT 'spListTasks', '@SiteCode=' + ISNULL(@SiteCode, '') + ',@Page=' + CAST(@Page AS VARCHAR(10)), '', @Msg, 0, 28;
		SET @SuccessFlg = 0;
	END CATCH
END
GO

/*==============================================================================
  STEP 5: RECREATE SQL AGENT JOB [Collect Stat data] FOR [Middleware_dev]
==============================================================================*/

USE [msdb]
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Collect Stat data')
BEGIN
	EXEC msdb.dbo.sp_delete_job @job_name = N'Collect Stat data', @delete_unused_schedule = 1;
END
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Collect Stat data', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Collect GLABs station history, task history, and weekly personal statistics.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'HU-VP-MID01\pulsator1', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [Collect data] ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect data', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @SiteCode VARCHAR(10),
		@StationID VARCHAR(50),
		@RowID INT,
		@SuccessFlg BIT;

DECLARE @History TABLE (
	RowID INT IDENTITY(1,1) PRIMARY KEY,
	SiteCode VARCHAR(10),
	StationID VARCHAR(50)
);

INSERT INTO @History (SiteCode, StationID)
SELECT DISTINCT ts.SiteCode, ts.StationID
FROM tblShipment ts
INNER JOIN tblClientParams cp ON cp.SiteCode = ts.SiteCode
WHERE ts.HistoryFlg IS NULL
  AND ts.ShipmentStatus = 5
  AND ts.StationID IS NOT NULL
  AND LTRIM(RTRIM(ts.StationID)) <> ''''
  AND cp.ActiveFlg = 1;

WHILE EXISTS (SELECT 1 FROM @History)
BEGIN
	SELECT TOP 1
		@RowID     = h.RowID,
		@SiteCode  = h.SiteCode,
		@StationID = h.StationID
	FROM @History h
	ORDER BY h.RowID ASC;

	EXECUTE [dbo].[spGetStationHistory] 
		@SiteCode   = @SiteCode,
		@StationID  = @StationID,
		@Page       = 1,
		@SuccessFlg = @SuccessFlg OUT;

	IF (@SuccessFlg = 1)
	BEGIN
		EXECUTE [dbo].[spSaveStationHistory]
			@StationID = @StationID;
	END

	DELETE FROM @History WHERE RowID = @RowID;
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [Task History] ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Task History', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @SiteCode VARCHAR(10),
		@SuccessFlg BIT;

DECLARE @Site TABLE (
	SiteCode VARCHAR(10) PRIMARY KEY
);

INSERT INTO @Site (SiteCode)
SELECT SiteCode
FROM tblClientParams
WHERE ActiveFlg = 1;

WHILE EXISTS (SELECT 1 FROM @Site)
BEGIN
	SELECT TOP 1 @SiteCode = s.SiteCode
	FROM @Site s
	ORDER BY s.SiteCode ASC;

	EXECUTE [dbo].[spListTasks] 
		@SiteCode   = @SiteCode,
		@Days       = 7,
		@Page       = 1,
		@SuccessFlg = @SuccessFlg OUT;

	DELETE FROM @Site WHERE SiteCode = @SiteCode;
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

/****** Object:  Step [Add personal stats on Sunday] ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Add personal stats on Sunday', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

-- Language-independent Sunday check ((DATEPART(WEEKDAY, GETDATE()) + @@DATEFIRST - 1) % 7 = 0 is always Sunday)
IF ((DATEPART(WEEKDAY, GETDATE()) + @@DATEFIRST - 1) % 7 = 0)
BEGIN
	-- 1. Insert new stations since last run into tmpStat1 using set-based OUTER APPLY
	INSERT INTO tmpStat1 (
		SiteCode, Picker, Loader, StationID, ShipmentDate,
		Weight, Package, PackagePrepared, TransportID, WeekNo, Year, WeightPrepared
	)
	SELECT
		tss.SiteCode,
		pck.UserID AS Picker,
		ldr.UserID AS Loader,
		tss.StationID,
		tss.ShipmentDate,
		(ISNULL(tss.WeightIn, 0) + ISNULL(tss.WeightOut, 0)) / 1000.0 AS Weight,
		ISNULL(tss.ColliIn, 0) + ISNULL(tss.ColliOut, 0) AS Package,
		tss.PackagePrepared,
		ts.TransportID,
		DATEPART(WEEK, tss.ShipmentDate) AS WeekNo,
		YEAR(tss.ShipmentDate) AS [Year],
		ISNULL(wp.WeightPrep, 0) AS WeightPrepared
	FROM tblShipmentStat tss
	INNER JOIN tblShipment ts
		ON ts.StationID = tss.StationID
	OUTER APPLY (
		SELECT TOP 1 sl.UserID
		FROM tblShipmentLog sl
		WHERE sl.StationID = tss.StationID
		  AND sl.PickingFlg = 1
		ORDER BY sl.id ASC
	) pck
	OUTER APPLY (
		SELECT TOP 1 sl.UserID
		FROM tblShipmentLog sl
		WHERE sl.StationID = tss.StationID
		  AND sl.LoadingFlg = 1
		ORDER BY sl.id ASC
	) ldr
	OUTER APPLY (
		SELECT SUM(tci.GrossWeight) / 1000.0 AS WeightPrep
		FROM tblCargo tc
		INNER JOIN tblCargoItem tci
			ON tci.DeliveryNo = tc.DeliveryNo
		   AND tci.TransportID = tc.TransportID
		WHERE tc.TransportID = ts.TransportID
		  AND tci.PickingFlg = 1
	) wp
	WHERE tss.ShipmentDate > ''2023-06-01''
	  AND NOT EXISTS (
		  SELECT 1
		  FROM tmpStat1 s1
		  WHERE s1.StationID = tss.StationID
	  );

	-- 2. Rebuild tmpStat2 (rows where Picker = Loader) without dropping table/indexes
	TRUNCATE TABLE tmpStat2;

	INSERT INTO tmpStat2 (
		SiteCode, Picker, Loader, StationID, ShipmentDate,
		Weight, Package, PackagePrepared, TransportID, WeekNo, Year, WeightPrepared
	)
	SELECT
		SiteCode, Picker, Loader, StationID, ShipmentDate,
		Weight, Package, PackagePrepared, TransportID, WeekNo, [Year], WeightPrepared
	FROM tmpStat1 s1
	WHERE s1.ShipmentDate > ''2023-06-01''
	  AND s1.Picker = s1.Loader;

	-- 3. Rebuild tmpStat3 (active users per week/year/site without self-picked+loaded shipments)
	TRUNCATE TABLE tmpStat3;

	INSERT INTO tmpStat3 (UserID, WeekNo, Year, SiteCode)
	SELECT u.UserID, u.WeekNo, u.[Year], u.SiteCode
	FROM (
		SELECT Picker AS UserID, WeekNo, [Year], SiteCode
		FROM tmpStat1
		WHERE Picker IS NOT NULL
		UNION
		SELECT Loader AS UserID, WeekNo, [Year], SiteCode
		FROM tmpStat1
		WHERE Loader IS NOT NULL
	) u
	WHERE NOT EXISTS (
		SELECT 1
		FROM tmpStat2 ts2
		WHERE (ts2.Picker = u.UserID OR ts2.Loader = u.UserID)
		  AND ts2.[Year] = u.[Year]
		  AND ts2.WeekNo = u.WeekNo
		  AND ts2.SiteCode = u.SiteCode
	);

	-- 4. Insert placeholder GENERATED rows into tmpStat1 (avoiding duplicates if re-run)
	INSERT INTO tmpStat1 (
		SiteCode, Picker, Loader, StationID, ShipmentDate,
		Weight, Package, PackagePrepared, TransportID, WeekNo, Year, WeightPrepared
	)
	SELECT
		ts3.SiteCode,
		ts3.UserID,
		NULL,
		''GENERATED'',
		DATEADD(WEEK, DATEDIFF(WEEK, 6, ''1/1/'' + CAST(ts3.[Year] AS VARCHAR(4))) + (ts3.WeekNo - 1), 6),
		0, 0, 0, ''0'',
		ts3.WeekNo,
		ts3.[Year],
		0
	FROM tmpStat3 ts3
	WHERE NOT EXISTS (
		SELECT 1
		FROM tmpStat1 s1
		WHERE s1.StationID = ''GENERATED''
		  AND s1.SiteCode  = ts3.SiteCode
		  AND s1.Picker    = ts3.UserID
		  AND s1.WeekNo    = ts3.WeekNo
		  AND s1.[Year]    = ts3.[Year]
	);
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily Stat collection', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220906, 
		@active_end_date=99991231, 
		@active_start_time=211000, 
		@active_end_time=235959, 
		@schedule_uid=N'20964446-32c6-45d2-b89f-7bbcf677fc7e'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
