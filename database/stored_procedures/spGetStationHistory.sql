/****** Object:  StoredProcedure [dbo].[spGetStationHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spGetStationHistory](
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
