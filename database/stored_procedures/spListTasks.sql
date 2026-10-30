/****** Object:  StoredProcedure [dbo].[spListTasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spListTasks](
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
