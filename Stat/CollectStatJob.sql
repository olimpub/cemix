USE [msdb]
GO

/****** Object:  Job [Collect Stat data]    Script Date: 2026. 10. 29. 13:02:00 ******/
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Collect Stat data')
BEGIN
	EXEC msdb.dbo.sp_delete_job @job_name = N'Collect Stat data', @delete_unused_schedule = 1;
END
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]] ******/
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
