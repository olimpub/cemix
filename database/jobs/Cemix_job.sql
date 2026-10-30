USE [msdb]
GO

/****** Object:  Job [Middleware Core Dev]    Script Date: 2026. 10. 13. 8:29:19 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 2026. 10. 13. 8:29:19 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Middleware Core Dev', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'HU-VP-MID01\pulsator1', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 0: Copy files from Test]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 0: Copy files from Test', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=2, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @CurrentID INT, @MaxID INT
SELECT @CurrentID=CurrentID FROM tblCurrentTestID
SELECT @MaxID=MAX(id) FROM [Middleware_test].dbo.tblTransferIn

SELECT @CurrentID,@MaxID

IF(@MaxID>@CurrentID)
BEGIN
	INSERT INTO tblTransferIn(TransferDate,TransferStatus,Body)
	SELECT TransferDate,TransferStatus,Body FROM [Middleware_test].dbo.tblTransferIn
	WHERE id>@CurrentID

	UPDATE tblCurrentTestID
	SET CurrentID=@MaxID
END', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Process SAP files]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Process SAP files', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=3, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @TransferID INT, @SuccessFlg BIT, @Body NVARCHAR(MAX)


WHILE EXISTS(SELECT * FROM tblTransferIn WHERE LoadFlg IS NULL)
BEGIN
	SELECT @TransferID = MIN(id) FROM tblTransferIn WHERE LoadFlg IS NULL
	SELECT @Body=Body  FROM tblTransferIn WHERE id=@TransferID

	EXECUTE spLoadSAPFilevS4
		@TransferID=@TransferID,
		@SuccessFlg=@SuccessFlg OUT


	SELECT @SuccessFlg
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Load partner data to MW]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load partner data to MW', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Step 2: Load Transport partners
DECLARE @TransferID INT, @SuccessFlg BIT
WHILE EXISTS(SELECT * FROM tblTransferIn WHERE PartnerFlg IS NULL AND LoadFlg=1 AND FileType=1)
BEGIN
	SELECT @TransferID = MIN(id) FROM tblTransferIn WHERE PartnerFlg IS NULL AND LoadFlg=1 AND FileType=1

	EXECUTE spLoadPartnerS4
		@TransferID=@TransferID,
		@SuccessFlg=@SuccessFlg OUT

	SELECT @TransferID,@SuccessFlg	

END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Create partners in GLABs]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Create partners in GLABs', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE 	
	@SiteCode VARCHAR(15),
	@PartnerID INT,
	@GLABsID VARCHAR(50),
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	SiteCode VARCHAR(15),
	PartnerID INT
)

INSERT INTO @ProcessTable
SELECT TOP 100 tp.SiteCode,id FROM tblPartner tp INNER JOIN tblClientParams cp ON cp.SiteCode=tp.SiteCode 
WHERE tp.Status=0 AND cp.ActiveFlg=1

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @PartnerID=PartnerID FROM @ProcessTable ORDER BY PartnerID

	EXECUTE spCreatePartner
	@SiteCode=@SiteCode,
	@PartnerID=@PartnerID,
	@GLABsID=@GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT @SiteCode,@PartnerID,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE PartnerID=@PartnerID AND SiteCode=@SiteCode

END', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Load transports to MW]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load transports to MW', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE 	
	@TransferID INT,
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	TransferID INT
)

INSERT INTO @ProcessTable
SELECT id FROM tblTransferIn WHERE TransformFlg IS NULL AND LoadFlg=1 AND PartnerFlg=1 AND FileType=1


WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @TransferID=TransferID FROM @ProcessTable ORDER BY TransferID

	EXECUTE spLoadTransportToMWv234
	@TransferID=@TransferID,
	@SuccessFlg=@SuccessFlg OUT

	SELECT @TransferID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE TransferID=@TransferID

END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Load documents to MW]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load documents to MW', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
DECLARE @TransferID INT,
		@SuccessFlg BIT,
		@DocumentType VARCHAR(50)

DECLARE @Process TABLE(
	TransferID INT,
	DocumentType VARCHAR(50)
)

INSERT INTO @Process(TransferID,DocumentType)
SELECT TransferID,DocType FROM tblTransferTransportDocument WHERE LoadFlg IS NULL

SELECT * FROm @Process

WHILE EXISTS(SELECT * FROM @Process)
BEGIN
	SELECT TOP 1 @TransferID = p.TransferID, @DocumentType=p.DocumentType FROM @Process p ORDER BY p.TransferID

		EXECUTE [dbo].[spLoadDocumentS4] 
		   @TransferID=@TransferID
		  ,@SuccessFlg=@SuccessFlg OUTPUT

	  SELECT @TransferID,@SuccessFlg

	DELETE p FROM @Process p WHERE p.TransferID=@TransferID
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Manage delete shipments]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Manage delete shipments', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Delete Shipments
DECLARE @GLABSID VARCHAR(20), @MergeTransportID VARCHAR(20), @MergedGLABsID VARCHAR(20), @ID INT, @Mode SMALLINT, @SuccessFlg BIT,@SiteCode VARCHAR(15),@DeliveryID INT

DECLARE @Table TABLE(
	ID INT,
	TransportNo VARCHAR(20),
	SiteCode VARCHAR(10),
	GLABSID VARCHAR(20),
	MergeTransportNo VARCHAR(20),
	MergeGLABSID VARCHAR(20),
	Mode SMALLINT
)

DECLARE @DN TABLE(
	TransportID INT,
	DelveryID INT,
	SiteCode VARCHAR(10)
)


INSERT INTO @Table(ID,TransportNo,SiteCode,GLABSID,MergeTransportNo)
SELECT ts.id, ts.TransportNo, ts.SiteCode, ts.GLABsID, ts.MergeTransportNo FROM tblTransport ts
INNER JOIN tblShipment tss ON tss.TransportID=ts.TransportNo
WHERE ts.Status=-1
AND ISNULL(tss.PickupDate,GETDATE()-15)>GETDATE()-14

--Update Mode
/*
0=Just set status 3 as not exists in GLABs
1=Just delete from GLABs and set status to 3(not merged)
2=Delete and set status to merge(0)--- Currently not merged, but need to be added
3=Delete Cargos(currently merged) --so just cargos delete and set  to everything
*/

UPDATE t
SET t.MergeGLABsID=(SELECT ts.GLABsID FROm tblTransport ts WHERE ts.TransportNo=t.MergeTransportNo)
FROM @Table t
WHERE t.MergeTransportNo IS NOT NULL

--UPDATE Modes
UPDATE t
SET t.Mode=0
FROM @Table t
WHERE t.GLABSID IS NULL

UPDATE t
SET t.Mode=1
FROM @Table t
WHERE t.GLABSID IS NOT NULL AND t.MergeTransportNo IS NULL

UPDATE t
SET t.Mode=2
FROM @Table t
WHERE t.GLABSID IS NOT NULL AND t.MergeTransportNo IS NOT NULL AND t.MergeGLABSID<>t.GLABSID

UPDATE t
SET t.Mode=3
FROM @Table t
WHERE t.GLABSID IS NOT NULL AND t.MergeTransportNo IS NOT NULL AND t.MergeGLABSID=t.GLABSID

INSERT INTO @DN(TransportID,DelveryID,SiteCode)
SELECT t.ID, tc.id, t.SiteCode FROM @Table t
INNER JOIN tblCargo tc ON tc.TransportID=t.TransportNo

SELECT * FROM @Table

WHILE EXISTS(SELECT * FROM @Table)
BEGIN
	SELECT TOP 1 @ID=t.ID,@Mode=t.Mode,@SiteCode=t.SiteCode FROM @Table t

	IF(@Mode=0)
	BEGIN
		UPDATE ts
		SET ts.Status=3
		FROM tblTransport ts
		WHERE ts.id=@ID
		
		UPDATE tc
		SET tc.Status=3,tc.GLABsID=NULL
		FROM tblCargo tc INNER JOIN  tblTransport  ts
		ON ts.TransportNo=tc.TransportID
		WHERE ts.id=@ID

		UPDATE tci
		SET tci.SourceStatus=3, tci.DestinationStatus=3, tci.SourceGLABsID=NULL,tci.DestinationGLABsID=NULL
		FROM tblCargoItem tci 
		INNER JOIN tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo
		INNER JOIN tblTransport ts
		ON ts.TransportNo=tc.TransportID
		WHERE ts.id=@ID
	END

	IF(@Mode IN(1,2))
	BEGIN
		-- TODO: Set parameter values here.
		EXECUTE [dbo].[spDeleteTransportv223] 
		   @SiteCode=@SiteCode
		  ,@TransportID=@ID
		  ,@GLABsID=@GLABSID OUTPUT
		  ,@SuccessFlg=@SuccessFlg OUTPUT

		IF(@Mode=2 AND @SuccessFlg=1)
		BEGIN
			UPDATE ts
			SET ts.Status=0, GLABsID=NULL
			FROM tblTransport ts
			WHERE ts.id=@ID
		
			UPDATE ts
			SET ts.StationID=NULL, ts.Status=0
			FROM tblShipment ts INNER JOIN tblTransport tt ON tt.TransportNo=ts.TransportID
			WHERE tt.id=@ID

			UPDATE tc
			SET tc.Status=0,tc.GLABsID=NULL
			FROM tblCargo tc INNER JOIN  tblTransport  ts
			ON ts.TransportNo=tc.TransportID
			WHERE ts.id=@ID

			UPDATE tci
			SET tci.SourceStatus=0, tci.DestinationStatus=0, tci.SourceGLABsID=NULL,tci.DestinationGLABsID=NULL
			FROM tblCargoItem tci 
			INNER JOIN tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo
			INNER JOIN tblTransport ts
			ON ts.TransportNo=tc.TransportID
			WHERE ts.id=@ID
		END
	END

	IF(@Mode=3)
	BEGIN
		WHILE EXISTS(SELECT * FROm @DN dn WHERE dn.TransportID=@ID)
		BEGIN
			SELECT TOP 1 @SiteCode= dn.SiteCode, @DeliveryID = dn.DelveryID FROM @DN dn WHERE dn.TransportID=@ID

			EXECUTE [dbo].[spDeleteCargov223] 
				@SiteCode=@SiteCode
				,@CargoID=@DeliveryID
				,@GLABsID=@GLABSID OUTPUT
				,@SuccessFlg=@SuccessFlg OUTPUT

			DELETE dn FROM @DN dn WHERE dn.DelveryID=@DeliveryID
		END
	END

	DELETE t FROM @Table t WHERE t.ID=@ID 
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Manage deliveries in GLABs]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Manage deliveries in GLABs', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Step 6: Create Cargos in GLABs
--Modified by DB on 2022.09.07. to add new site logic
DECLARE 	
	@SiteCode VARCHAR(15),
	@CargoID INT,
	@GLABsID VARCHAR(50),
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	SiteCode VARCHAR(15),
	CargoID INT
)


INSERT INTO @ProcessTable
SELECT [dbo].[fnGetCargoSite](tc.id),tc.id FROM tblCargo tc
INNER JOIN tblClientParams cp ON cp.SiteCode=[dbo].[fnGetCargoSite](tc.id)
WHERE tc.GLABsID IS NULL AND tc.Status=0 AND cp.ActiveFlg=1
ORDER BY tc.id

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @CargoID=CargoID FROM @ProcessTable ORDER BY CargoID

	--If requires to update partner
	--EXECUTE [dbo].[spChangePartner]
	--	@CargoID=@CargoID 

	--Create Cargo
	EXECUTE spCreateCargov223
	@SiteCode=@SiteCode,
	@CargoID=@CargoID ,
	@GLABsID=@GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT @SiteCode,@CargoID,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE CargoID=@CargoID

END


INSERT INTO @ProcessTable
SELECT [dbo].[fnGetCargoSite](tc.id),tc.id FROM tblCargo tc
INNER JOIN tblClientParams cp ON cp.SiteCode=[dbo].[fnGetCargoSite](tc.id)
WHERE tc.GLABsID IS NOT NULL AND tc.Status=0 AND cp.ActiveFlg=1
ORDER BY tc.id

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @CargoID=CargoID FROM @ProcessTable ORDER BY CargoID

	--Create Cargo
	EXECUTE spUpdateCargov223
	@SiteCode=@SiteCode,
	@CargoID=@CargoID ,
	@GLABsID=@GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT @SiteCode,@CargoID,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE CargoID=@CargoID

END


--Delete Cargo
INSERT INTO @ProcessTable
SELECT [dbo].[fnGetCargoSite](tc.id),tc.id FROM tblCargo tc
INNER JOIN tblClientParams cp ON cp.SiteCode=[dbo].[fnGetCargoSite](tc.id)
WHERE tc.GLABsID IS NOT NULL AND tc.Status=-1 AND cp.ActiveFlg=1
ORDER BY tc.id

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @CargoID=CargoID FROM @ProcessTable ORDER BY CargoID

	--Create Cargo
	EXECUTE spDeleteCargov223
	@SiteCode=@SiteCode,
	@CargoID=@CargoID ,
	@GLABsID=@GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT @SiteCode,@CargoID,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE CargoID=@CargoID

END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Check Status of inProgress items]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check Status of inProgress items', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE 
	@SiteCode VARCHAR(15),
	@StationID VARCHAR(30),
	@SuccessFlg BIT,
	@InProgressFlg BIT


DECLARE @ProcessTable TABLE(
	SiteCode VARCHAR(15),
	StationID VARCHAR(30)
)

INSERT INTO @ProcessTable
SELECT DISTINCT ts.SiteCode, ts.StationID FROM tblCargoItem cti INNER JOIN tblCargo tc
ON tc.DeliveryNo=cti.DeliveryNo AND tc.TransportID=cti.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.SourceSiteCode
INNER JOIN tblShipment ts ON ts.SiteCode=tc.SourceSiteCode AND ts.TransportID=tc.TransportID
WHERE tc.GLABsID IS NOT NULL AND cti.SourceGLABsID IS NOT NULL AND cti.SourceStatus=2 AND  cp.ItemsFlg=1 AND cti.SourceInProgressFlg=1
UNION
SELECT  DISTINCT ts.SiteCode, ts.StationID FROM tblCargoItem cti INNER JOIN tblCargo tc
ON tc.DeliveryNo=cti.DeliveryNo AND tc.TransportID=cti.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.DestinationSiteCode
INNER JOIN tblShipment ts ON ts.SiteCode=tc.DestinationSiteCode AND ts.TransportID=tc.TransportID
WHERE tc.GLABsID IS NOT NULL AND cti.DestinationGLABsID IS NOT NULL AND cti.DestinationStatus=2 AND cp.ItemsFlg=1 AND cti.DestinationInProgressFlg=1
UNION
SELECT  DISTINCT ts.SiteCode, ts.StationID FROM tblCargoItem tci 
INNER JOIN tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo AND tc.TransportID=tci.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.SourceSiteCode
INNER JOIN tblShipment ts ON ts.SiteCode=tc.SourceSiteCode AND ts.TransportID=tc.TransportID
WHERE tc.GLABsID IS NOT NULL AND tci.SourceGLABsID IS NULL AND tci.SourceStatus=2 AND  cp.ItemsFlg=1 AND tci.SourceInProgressFlg=1
UNION
SELECT DISTINCT ts.SiteCode, ts.StationID FROM tblCargoItem tci 
INNER JOIN tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo AND tc.TransportID=tci.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.DestinationSiteCode
INNER JOIN tblShipment ts ON ts.SiteCode=tc.DestinationSiteCode AND ts.TransportID=tc.TransportID
WHERE tc.GLABsID IS NOT NULL AND tci.DestinationGLABsID IS NULL AND tci.DestinationStatus=2 AND cp.ItemsFlg=1 AND tci.DestinationInProgressFlg=1



WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @StationID=StationID FROM @ProcessTable ORDER BY StationID

	EXECUTE [dbo].[spGetStationInProgress] 
	   @SiteCode
	  ,@StationID
	  ,@SuccessFlg=@SuccessFlg OUTPUT
	  ,@InProgressFlg=@InProgressFlg OUTPUT

	SELECT ''StationData'',@SiteCode,@StationID, @SuccessFlg, @InProgressFlg

	IF(@InProgressFlg=0)
	BEGIN
		UPDATE cti
		SET cti.SourceStatus=0, cti.SourceInProgressFlg=0
		FROM tblCargoItem cti INNER JOIN tblCargo tc
		ON tc.DeliveryNo=cti.DeliveryNo AND tc.TransportID=cti.TransportID
		INNER JOIN tblClientParams cp ON cp.SiteCode=tc.SourceSiteCode
		INNER JOIN tblShipment ts ON ts.SiteCode=tc.SourceSiteCode AND ts.TransportID=tc.TransportID
		WHERE cti.SourceStatus=2 AND  cp.ItemsFlg=1 AND cti.SourceInProgressFlg=1 AND ts.StationID=@StationID

		UPDATE cti
		SET cti.DestinationStatus=0, cti.DestinationInProgressFlg=0
		FROM tblCargoItem cti INNER JOIN tblCargo tc
		ON tc.DeliveryNo=cti.DeliveryNo AND tc.TransportID=cti.TransportID
		INNER JOIN tblClientParams cp ON cp.SiteCode=tc.DestinationSiteCode
		INNER JOIN tblShipment ts ON ts.SiteCode=tc.DestinationSiteCode AND ts.TransportID=tc.TransportID
		WHERE cti.DestinationStatus=2 AND cp.ItemsFlg=1 AND cti.DestinationInProgressFlg=1 AND ts.StationID=@StationID
	END

	DELETE FROM @ProcessTable WHERE StationID=@StationID AND SiteCode=@SiteCode

END', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Manage delivery items in GLABs]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Manage delivery items in GLABs', 
		@step_id=10, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Step 7:Manage Items in GLABs 

DECLARE 	
	@SiteCode VARCHAR(15),
	@CargoItemID INT,
	@GLABsID VARCHAR(50),
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	SiteCode VARCHAR(15),
	CargoItemID INT
)

--Add new items
INSERT INTO @ProcessTable
SELECT  tc.SourceSiteCode, tci.id FROM tblCargoItem tci 
INNER JOIN tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo AND tc.TransportID=tci.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.SourceSiteCode
WHERE tc.GLABsID IS NOT NULL AND tci.SourceGLABsID IS NULL AND tci.SourceStatus=0 AND cp.ItemsFlg=1
UNION
SELECT tc.DestinationSiteCode, tci.id FROM tblCargoItem tci 
INNER JOIN tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo AND tc.TransportID=tci.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.DestinationSiteCode
WHERE tc.GLABsID IS NOT NULL AND tci.DestinationGLABsID IS NULL AND tci.DestinationStatus=0 AND cp.ItemsFlg=1

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @CargoItemID=CargoItemID FROM @ProcessTable ORDER BY CargoItemID

	EXECUTE [dbo].[spAddCargoItemv223]
	@SiteCode=@SiteCode,
	@CargoItemID=@CargoItemID ,
	@GLABsID=@GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT ''CargoItemAdd'',@SiteCode,@CargoItemID,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE CargoItemID=@CargoItemID AND SiteCode=@SiteCode

END

--Modify items
INSERT INTO @ProcessTable
SELEct tc.SourceSiteCode, cti.id FROM tblCargoItem cti INNER JOIN tblCargo tc
ON tc.DeliveryNo=cti.DeliveryNo AND tc.TransportID=cti.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.SourceSiteCode
WHERE tc.GLABsID IS NOT NULL AND cti.SourceGLABsID IS NOT NULL AND cti.SourceStatus=0 AND  cp.ItemsFlg=1
UNION
SELEct tc.DestinationSiteCode, cti.id FROM tblCargoItem cti INNER JOIN tblCargo tc
ON tc.DeliveryNo=cti.DeliveryNo AND tc.TransportID=cti.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.DestinationSiteCode
WHERE tc.GLABsID IS NOT NULL AND cti.DestinationGLABsID IS NOT NULL AND cti.DestinationStatus=0 AND cp.ItemsFlg=1

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @CargoItemID=CargoItemID FROM @ProcessTable ORDER BY CargoItemID

	EXECUTE [dbo].[spUpdateCargoItemv223]
	@SiteCode=@SiteCode,
	@CargoItemID=@CargoItemID ,
	@GLABsID=@GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT ''CargoItemModify'',@SiteCode,@CargoItemID,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE CargoItemID=@CargoItemID AND SiteCode=@SiteCode

END


--Delete items
INSERT INTO @ProcessTable
SELEct tc.SourceSiteCode, tci.id FROM tblCargoItem tci INNER JOIN tblCargo tc
ON tc.DeliveryNo=tci.DeliveryNo AND tc.TransportID=tci.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.SourceSiteCode
WHERE tc.GLABsID IS NOT NULL AND tci.SourceGLABsID IS NOT NULL AND tci.SourceStatus=-1 AND cp.ItemsFlg=1
UNION
SELEct tc.DestinationSiteCode, tci.id FROM tblCargoItem tci INNER JOIN tblCargo tc
ON tc.DeliveryNo=tci.DeliveryNo AND tc.TransportID=tci.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=tc.DestinationSiteCode
WHERE tc.GLABsID IS NOT NULL AND tci.DestinationGLABsID IS NOT NULL AND tci.DestinationStatus=-1 AND cp.ItemsFlg=1


WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @CargoItemID=CargoItemID FROM @ProcessTable ORDER BY CargoItemID

	EXECUTE [dbo].[spDeleteCargoItemv223]
	@SiteCode=@SiteCode,
	@CargoItemID=@CargoItemID ,
	@GLABsID=@GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT ''CargoItemDelete'',@SiteCode,@CargoItemID,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE CargoItemID=@CargoItemID AND SiteCode=@SiteCode

END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Delegate shipment in GLABs]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Delegate shipment in GLABs', 
		@step_id=11, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE 	
	@SiteCode VARCHAR(15),
	@TransportID INT,
	@GLABsID VARCHAR(50),
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	SiteCode VARCHAR(15),
	TransportID INT
)

INSERT INTO @ProcessTable
SELEct  ts.SiteCode, ts.id FROM tblTransport ts
INNER JOIN tblClientParams cp ON cp.SiteCode=ts.SiteCode
WHERE ts.DelegateFlg IS NULL  AND ts.Status=1 AND cp.ActiveFlg=1

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @TransportID=TransportID FROM @ProcessTable ORDER BY TransportID

	EXECUTE [dbo].[spCreateDelegation]
	@SiteCode=@SiteCode,
	@TransportID=@TransportID,
	@GLABsID = @GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT @SiteCode,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE TransportID=@TransportID

END', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Request status from GLABs]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Request status from GLABs', 
		@step_id=12, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE 	
	@SiteCode VARCHAR(15),
	@Status SMALLINT,
	@Page SMALLINT,
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	StatusID SMALLINT,
	SiteCode VARCHAR(10)
)

INSERT INTO @ProcessTable
SELEct DISTINCT tss.id,tpc.SiteCode FROM [dbo].[tblShipmentStatus] tss CROSS JOIN tblClientParams tpc
WHERE tpc.QueryFlg=1 AND tss.QueryFlg=1
ORDER BY tss.id

SET @Page=1

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @Status=StatusID, @SiteCode=SiteCode FROM @ProcessTable ORDER BY StatusID

	EXECUTE [dbo].[spListCargoS4]
		@SiteCode = @SiteCode,
		@Status = @Status,
		@Page = @Page,
		@SuccessFlg = @SuccessFlg OUT
	
	SELECT ''ListCargo'',@SiteCode,@Status,@Page,@SuccessFlg 

	DELETE FROM @ProcessTable WHERE StatusID=@Status AND SiteCode=@SiteCode
END', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Set update queue in MW]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Set update queue in MW', 
		@step_id=13, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @StatusUpdate TABLE(
	StationID VARCHAR(50),
	CurrentStatusID SMALLINT
)

INSERT INTO @StatusUpdate(StationID,CurrentStatusID)
SELECT StationID, MIN(tss.CurrentStatus)
FROM tblShipmentStatusQueue tss 
WHERE tss.ProcessStatus=0
GROUP BY StationID

DELETE su FROM @StatusUpdate su INNER JOIN tblShipment ts ON ts.StationID=su.StationID
WHERE SAPStatus<>1 AND  ts.ShipmentStatus<>su.CurrentStatusID

UPDATE ts
SET ts.ShipmentStatus=su.CurrentStatusID, ts.SAPStatus=CASE tss.AutoSAPCompleteFlg WHEN 0 THEN 0 ELSE 1 END
FROM tblShipment ts
INNER JOIN @StatusUpdate su ON su.StationID=ts.StationID
INNER JOIN tblShipmentStatus tss ON tss.id=su.CurrentStatusID AND tss.TemplateID= ISNULL(ts.SAPTemplateID,1)
--INNER JOIN tblTransport tr ON tr.TransportNo=ts.TransportID AND tr.SiteCode=ts.SiteCode
WHERE ts.ShipmentStatus<>su.CurrentStatusID

/*
UPDATE ts
SET ts.ShipmentStatus=su.CurrentStatusID, ts.SAPStatus=1 --Fixed Done, if it is not the organizer sitecode
FROM tblShipment ts
INNER JOIN @StatusUpdate su ON su.StationID=ts.StationID
INNER JOIN tblShipmentStatus tss ON tss.id=su.CurrentStatusID AND tss.TemplateID= ISNULL(ts.SAPTemplateID,1)
INNER JOIN tblTransport tr ON tr.TransportNo=ts.TransportID AND tr.SiteCode<>ts.SiteCode
WHERE ts.ShipmentStatus<>su.CurrentStatusID
*/
UPDATE tss
SET tss.ProcessStatus=1
FROM tblShipmentStatusQueue tss 
INNER JOIN @StatusUpdate su ON su.StationID=tss.StationID AND su.CurrentStatusID=tss.CurrentStatus', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Update SAP from MW]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Update SAP from MW', 
		@step_id=14, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Step 12: Set Status in SAP


UPDATE ts
SET SAPStatus=NULL
FROM tblShipment ts WHERE ts.ShipmentStatus=5 AND SAPStatus=0 AND ts.SAPTemplateID=1
AND NOT EXISTS(SELECT * FROM tblCargo tc WHERE tc.TransportID=ts.TransportID AND tc.Direction=1)

--Fix if autocomplete is not working
UPDATE ts
SET ts.SAPStatus=1
FROM tblShipment ts 
INNER JOIN tblShipmentStatus tss ON tss.id=ts.ShipmentStatus AND tss.TemplateID=ts.SAPTemplateID
WHERE tss.AutoSAPCompleteFlg=1 AND ts.SAPStatus=0


DECLARE @Shipments TABLE(
	ShipmentID INT
)

INSERT INTO @Shipments
SELECT  ts.id FROM tblShipment ts 
INNER JOIN tblShipmentStatus tss ON tss.id=ts.ShipmentStatus AND tss.TemplateID=ts.SAPTemplateID
WHERE tss.AutoSAPCompleteFlg=0 AND ts.SAPStatus=0


DECLARE  @SuccessFlg BIT, @ShipmentID INT

WHILE EXISTS(SELECT * FROM @Shipments)
BEGIN
	SELECT TOP 1 @ShipmentID =s.ShipmentID FROM @Shipments s ORDER BY s.ShipmentID

	EXECUTE [dbo].[spSAPUpdateS4]
		@ShipmentID=@ShipmentID,
		@SuccessFlg=@SuccessFlg OUT

	SELECT ''SAPUpdate'', @ShipmentID AS ShipmentID,@SuccessFlg AS SuccessFlg

	DELETE  FROM @Shipments WHERE ShipmentID=@ShipmentID
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [AutoEntry trucks]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'AutoEntry trucks', 
		@step_id=15, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE 	
	@SiteCode VARCHAR(15),
	@TransportID INT,
	@GLABsID VARCHAR(50),
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	SiteCode VARCHAR(15),
	TransportID INT
)

INSERT INTO @ProcessTable
SELEct ts.SiteCode, ts.id FROM tblShipment ts
INNER JOIN tblClientParams cp ON cp.SiteCode=ts.SiteCode
WHERE ts.AutoEntryFlg IS NULL AND ts.ShipmentStatus IN (3,4) AND cp.AutoEntryFlg=1
UNION
SELEct ts.SiteCode, ts.id FROM tblShipment ts
INNER JOIN tblClientParams cp ON cp.SiteCode=ts.SiteCode
WHERE ts.AutoExitFlg IS NULL AND ts.ShipmentStatus=5 AND cp.AutoExitFlg=1

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @TransportID=TransportID FROM @ProcessTable ORDER BY TransportID

	EXECUTE [dbo].[spCreateEntry]
	@SiteCode=@SiteCode,
	@TransportID=@TransportID,
	@GLABsID = @GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT @SiteCode,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE TransportID=@TransportID

END', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Request ramp calls]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Request ramp calls', 
		@step_id=16, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Step 14: Request ramp calls

DECLARE @Sites TABLE(
	SiteCode VARCHAR(10)
	)

DECLARE @SiteCode varchar(10)
DECLARE @Page smallint
DECLARE @SuccessFlg bit

INSERT INTO @Sites
SELECT DISTINCT tr.SiteCode FROM tblRamp tr INNER JOIN tblClientParams tc ON tc.SiteCode=tr.SiteCode 
WHERE tc.ActiveFlg=1 AND tc.PreCallFlg=1

SET @Page=1

WHILE EXISTS(SELECT * FROM @Sites) 
BEGIN
	SELECT TOP 1 @SiteCode = s.SiteCode FROM @Sites s

	EXECUTE  [dbo].[spListRamps] 
	   @SiteCode
	  ,@Page
	  ,@SuccessFlg=@SuccessFlg OUTPUT

	SELECT @SiteCode,@SuccessFlg

	DELETE s FROM @Sites s WHERE s.SiteCode=@SiteCode 
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Delete Calls]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Delete Calls', 
		@step_id=17, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
--Step 15: Delete Calls
DECLARE @Calls TABLE(
	SiteCode VARCHAR(10),
	StationID VARCHAR(50)
)

INSERT INTO @Calls(SiteCode,StationID)
SELECT ts.SiteCode, ts.StationID FROM tblShipment ts INNER JOIN tblRamp tr ON tr.CallID=ts.CallID
INNER JOIN tblClientParams cp ON cp.SiteCode=ts.SiteCode
WHERE ts.ShipmentStatus<>2 AND cp.PreCallFlg=1 AND ts.CallStatus<>2

DECLARE @SiteCode VARCHAR(10),@StationID VARCHAR(50), @SuccessFlg BIT

WHILE EXISTS(SELECT * FROM @Calls)
BEGIN
	SELECT @SiteCode = cl.SiteCode,@StationID = cl.StationID FROM @Calls cl

	-- TODO: Set parameter values here.

	EXECUTE [dbo].[spDeleteCall] 
	   @SiteCode
	  ,@StationID
	  ,@SuccessFlg=@SuccessFlg OUT

	  SELECT @StationID, @SuccessFlg

	DELETE cl FROM @Calls cl WHERE StationID=@StationID 
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Request Calling sequence from GLABs]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Request Calling sequence from GLABs', 
		@step_id=18, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
DECLARE @Ramps TABLE(
	SiteCode VARCHAR(10),
	Cntr SMALLINT
)

INSERT INTO @Ramps(SiteCode,Cntr)
SELECT tr.SiteCode,COUNT(*) FROM tblRamp tr
INNER JOIN tblClientParams cp ON cp.SiteCode=tr.SiteCode
WHERE CallID IS NULL  AND cp.PreCallFlg=1
GROUP BY tr.SiteCode



DECLARE @SiteCode VARCHAR(10), @Cntr SMALLINT, @SuccessFlg BIT

IF EXISTS(SELECT * FROM tblRamp tr WHERE CallID IS NULL)
BEGIN
	SELECT TOP 1 @SiteCode = r.SiteCode, @Cntr = r.Cntr FROM @Ramps r 

	EXECUTE [dbo].[spListLoadingOrder] 
		   @SiteCode=@SiteCode
		  ,@Page=1
		  ,@OrderNo=@Cntr
		  ,@SuccessFlg=@SuccessFlg OUTPUT

		SELECT @SuccessFlg
	
	DELETE FROM @Ramps WHERE SiteCode=@SiteCode
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Manage pre-calls from GLABs]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Manage pre-calls from GLABs', 
		@step_id=19, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
--Step 17: Manage pre-calls in GLABs

DECLARE @Calls TABLE(
	SiteCode VARCHAR(10),
	StationID VARCHAR(50)
)

INSERT INTO @Calls(SiteCode,StationID)
SELECT DISTINCT ts.SiteCode, ts.StationID FROM tblShipment ts
INNER JOIN tblClientParams cp ON cp.SiteCode=ts.SiteCode
WHERE ts.CallStatus=0 AND RampID IS NULL AND cp.PreCallFlg=1

DECLARE @ShipmentID INT, @SiteCode VARCHAR(10), @StationID VARCHAR(50), @CallID VARCHAR(50), @SuccessFlg BIT

WHILE EXISTS(SELECT * FROM @Calls)
BEGIN
	SELECT TOP 1 @SiteCode = ca.SiteCode, @StationID = ca.StationID FROM @Calls ca 
	
	UPDATE ts
	SET ts.RampID=(SELECT TOP 1 tr.id FROM tblRamp tr WHERE tr.SiteCode=@SiteCode AND tr.CallID IS NULL)
	FROM tblShipment ts
	WHERE ts.StationID=@StationID


	--Manage Call
	EXECUTE [dbo].[spCreateCall] 
	   @SiteCode=@SiteCode
	  ,@StationID=@StationID
	  ,@GLABsID=@CallID OUTPUT
	  ,@SuccessFlg=@SuccessFlg OUTPUT

	SELECT @StationID, @CallID, @SuccessFlg
	
	DELETE ca FROM @Calls ca WHERE ca.StationID=@StationID

END', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Load documents to GLABs]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load documents to GLABs', 
		@step_id=20, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
DECLARE @DocumentID INT,
		@GLABsID varchar(50),
		@SuccessFlg bit

DECLARE @Documents TABLE(
	DocumentID INT
)

INSERT INTO @Documents
SELECT tsd.id
FROM tblShipmentDocument tsd
INNER JOIN tblCargo tc ON tc.DeliveryNo=tsd.DeliveryNo
WHERE tsd.[Status]=0 AND tc.GLABsID IS NOT NULL

WHILE EXISTS(SELECT * FROM @Documents)
BEGIN
	SELECT @DocumentID = MIN(DocumentID) FROM @Documents

	--Create document
	EXECUTE [dbo].[spCreateFileS4] 
	   @DocumentID
	  ,@GLABsID=@GLABsID OUTPUT
	  ,@SuccessFlg=@SuccessFlg OUTPUT
	
	SELECT ''Create file'' AS Act, @GLABsID, @SuccessFlg

	IF(@SuccessFlg=1)
	BEGIN
		--Upload File

		EXECUTE [dbo].[spUploadFileS4] 
			@DocumentID
			,@GLABsID=@GLABsID OUTPUT
			,@SuccessFlg=@SuccessFlg OUTPUT

	SELECT ''Upload file'' AS Act, @GLABsID, @SuccessFlg
	END


	DELETE FROM @Documents WHERE DocumentID=@DocumentID
END', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Update Intercompany stations]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Update Intercompany stations', 
		@step_id=21, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @Stations TABLE(
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

', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Manage unblock and auto check-out]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Manage unblock and auto check-out', 
		@step_id=22, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=24, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
--Step 18: Auto check-out for inbound shipments
DECLARE 	
	@SiteCode VARCHAR(15),
	@StationID VARCHAR(50),
	@CheckOutFlg BIT,
	@GLABsID VARCHAR(50),
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	SiteCode VARCHAR(15),
	ID INT,
	StationID VARCHAR(50),
	DeliveryNo VARCHAR(50),
	TransportNo VARCHAR(50),
	DirectionFlg BIT,
	CheckOutBlock BIT,
	CheckOutAllow BIT,
	DocumentStatus SMALLINT
)

DECLARE @Process TABLE(
	SiteCode VARCHAR(15),
	StationID VARCHAR(50),
	CheckOutFlg BIT
)


INSERT INTO @ProcessTable
SELEct ts.SiteCode, ts.id, ts.StationID, tc.DeliveryNo, ts.TransportID,1, ts.CheckOutBlock, ts.CheckOutAllow, tsd.DocumentStatus FROM tblShipment ts
INNER JOIN tblTransport tts ON tts.TransportNo=ts.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=ts.SiteCode
INNER JOIN tblCargo tc ON tc.TransportID=tts.TransportNo AND tc.SourceSiteCode=ts.SiteCode 
LEFT OUTER JOIN tblShipmentDocument tsd ON tsd.TransportID=tc.TransportID AND tsd.DeliveryNo=tc.DeliveryNo AND tc.Status=1 
WHERE ts.ShipmentStatus=4 --AND ts.id=1111

INSERT INTO @ProcessTable
SELEct ts.SiteCode, ts.id,ts.StationID, tc.DeliveryNo, ts.TransportID,0, ts.CheckOutBlock, ts.CheckOutAllow, tsd.DocumentStatus FROM tblShipment ts
INNER JOIN tblTransport tts ON tts.TransportNo=ts.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=ts.SiteCode
INNER JOIN tblCargo tc ON tc.TransportID=tts.TransportNo AND tc.DestinationSiteCode=ts.SiteCode 
LEFT OUTER JOIN tblShipmentDocument tsd ON tsd.TransportID=tc.TransportID AND tsd.DeliveryNo=tc.DeliveryNo AND tc.Status=1 
WHERE ts.ShipmentStatus=4 AND ISNULL(ts.AutoCheckOutFlg,0)<>1 
----------------------------------------------

SELECT * FROm @ProcessTable

--Collect Unblock where only incoming(this should be unblocked and check-out)
INSERT INTO @Process
SELECT pt.SiteCode, pt.StationID,ISNULL(cp.AutoCheckOutFlg,0) FROM @ProcessTable pt
INNER JOIN tblClientParams cp ON cp.SiteCode=pt.SiteCode
WHERE NOT EXISTS(SELECT * FROM @ProcessTable pt2 WHERE pt2.StationID=pt.StationID AND DirectionFlg=1)
AND pt.CheckOutBlock=1 AND pt.CheckOutAllow IS NULL
GROUP BY pt.SiteCode,StationID,ISNULL(cp.AutoCheckOutFlg,0)


--Collect unblock for outgoing(this should checkout only)
INSERT INTO @Process
SELECT p.SiteCode, p.StationID,0 FROM @ProcessTable p 
INNER JOIN tblClientParams cp ON cp.SiteCode=p.SiteCode
WHERE DocumentStatus=1 AND CheckOutAllow IS NULL AND p.CheckOutBlock=1 
AND NOT EXISTS(
SELECT * FROM @ProcessTable p2 WHERE p2.StationID=p.StationID AND ISNULL(p2.DocumentStatus,0)<>1 AND p2.DirectionFlg=1)
AND EXISTS(SELECT * FROM @ProcessTable pt2 WHERE pt2.StationID=p.StationID AND DirectionFlg=1)
GROUP BY p.SiteCode,p.StationID


SELECT * FROm @Process


WHILE EXISTS(SELECT * FROM @Process)
BEGIN
	SELECT TOP 1 @SiteCode = p.SiteCode, @StationID = p.StationID, @CheckOutFlg=p.CheckOutFlg FROM @Process p

	EXECUTE [dbo].[spUpdateStationv232] 
	   @SiteCode
	  ,@StationID
	  ,@BlockFlg=0
	  ,@SuccessFlg=@SuccessFlg OUTPUT

	SELECT ''Unblock'',@SiteCode,@StationID, @SuccessFlg
	IF(@SuccessFlg=1 AND @CheckOutFlg=1)
	BEGIN
			EXECUTE [dbo].[spCreateCheckOutv223]
				@SiteCode=@SiteCode,
				@StationID=@StationID,
				@GLABsID = @GLABsID OUT,
				@SuccessFlg=@SuccessFlg OUT

		SELECT ''CheckOut'',@SiteCode,@StationID, @SuccessFlg
	END

	DELETE p FROM @Process p WHERE p.StationID=@StationID
END
GO
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Send out error notificartions]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Send out error notificartions', 
		@step_id=23, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
DECLARE @LogID INT

DECLARE @Logs TABLE(
	ID INT
)

INSERT INTO @Logs
SELECT tl.id FROM [dbo].[tblLog] tl
INNER JOIN [dbo].[tblLogProcess] tlp ON tlp.id=tl.ProcessID
WHERE tl.SuccessFlg=0 AND tl.NotificationFlg IS NULL AND tlp.NotifyFailFlg=1
UNION
SELECT tl.id FROM [dbo].[tblLog] tl
INNER JOIN [dbo].[tblLogProcess] tlp ON tlp.id=tl.ProcessID
WHERE tl.SuccessFlg=1 AND tl.NotificationFlg IS NULL AND tlp.NotifySuccessFlg=1

WHILE EXISTS(SELECT * FROM @Logs)
BEGIN
	SELECT TOP 1 @LogID= l.ID FROM @Logs l ORDER BY id

	EXECUTE [dbo].[spSendLogMsg] @LogID=@LogID

	DELETE FROM @Logs WHERE id=@LogID
END
', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Archive Process]    Script Date: 2026. 10. 13. 8:29:19 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Archive Process', 
		@step_id=24, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @SuccessFlg BIT

EXECUTE  [dbo].[spArchive] @SuccessFlg=@SuccessFlg OUT

SELECT @SuccessFlg', 
		@database_name=N'Middleware_dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'3 minutes schedule', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=62, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20251017, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=175959, 
		@schedule_uid=N'3fe355f5-c240-426f-ba3a-88199968c964'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Night schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220504, 
		@active_end_date=99991231, 
		@active_start_time=180100, 
		@active_end_time=235959, 
		@schedule_uid=N'55e444f6-5d96-4ac5-ba54-115bd96a0f27'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Night schedule 2', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220504, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=55959, 
		@schedule_uid=N'0d97ff10-44e0-44dc-8daa-db9253776424'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

