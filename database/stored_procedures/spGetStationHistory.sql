/****** Object:  StoredProcedure [dbo].[spGetStationHistory]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spGetStationHistory](
	@SiteCode VARCHAR(10),
	@StationID VARCHAR(30),
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
		@CargoID VARCHAR(50),
		@RowID VARCHAR(50),
		@Filter NVARCHAR(200)

SELECT @URL=tcpr.[url]+'api/'+tcpr.[profile id]+'/stations/'+@StationID+'?include=stages,pickingWorks,stages.creator,pickingWorks.creator,currentBooking,currentBooking.creator' FROM [dbo].[tblClientParams] tcpr WHERE tcpr.SiteCode=@SiteCode

--TOKEN
EXECUTE spGetToken
	@SiteCode=@SiteCode,
	@Token=@Token OUT,
	@SuccessFlg=@SuccessFlg OUT

IF(@SuccessFlg=0) -- No Token
BEGIN
	SET @Msg='Token Request Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID)
	SELECT 'spGetStationHistory','@SiteCode='+@SiteCode+',@StationID='+@StationID+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,28
	RETURN
END

--Create Header
SET @Header='Authorization: Bearer '+@Token+'&'
--Other data
SET @ResponseAccept='application/json'
SET @MsgType=''
SET @MsgMethod='GET'

SELECT @TransferType = 23

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
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID)
	SELECT 'spGetStationHistory','@SiteCode='+@SiteCode+',@StationID='+@StationID+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,28
END
ELSE
BEGIN
		DECLARE @MaxPage SMALLINT,@Stage VARCHAR(50)
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID

		DECLARE @Changes TABLE(
			DataType VARCHAR(50),
			ID VARCHAR(50),
			AttributeName VARCHAR(30),
			CreatedAt BIGINT,
			ChangeDate DATETIME,
			Revoked NVARCHAR(50),
			UserID VARCHAR(50)
		)

		INSERT INTO @Changes(DataType,ID,AttributeName,CreatedAt,Revoked,UserID)
		SELECT DataType, ID, AttributeName,CreatedAt,Revoked,UserID
			FROM OPENJSON(@Msg,'$.included')
			WITH (
				DataType VARCHAR(50) '$.type',
				ID VARCHAR(50) '$.id',
				AttributeName VARCHAR(30) '$.attributes.name',
				CreatedAt NVARCHAR(50) '$.attributes.createdAt',
				Revoked NVARCHAR(50) '$.attributes.revoked',
				UserID VARCHAR(50) '$.relationships.creator.data.id'

			)
			WHERE DataType<>'ProfileUsers'
		
			UPDATE @Changes
			SET ChangeDate= dateadd(S, CreatedAt, '1970-01-01') AT TIME ZONE 'Central European Standard Time'

			UPDATE @Changes
			SET ChangeDate =DATEADD(hour,DATEDIFF(hour,GETUTCDATE(), GETDATE()),  ChangeDate );

			DECLARE @User TABLE(
				DataType VARCHAR(50),
				ID VARCHAR(50),
				FirstName NVARCHAR(200),
				LastName NVARCHAR(200),
				Email NVARCHAR(200),
				Position NVARCHAR(200)
		)	
			INSERT INTO @User(DataType,ID,FirstName,LastName,Email,Position)
			SELECT DataType, ID, FirstName,LastName, Email,Position
			FROM OPENJSON(@Msg,'$.included')
			WITH (
				DataType VARCHAR(50) '$.type',
				ID VARCHAR(50) '$.id',
				FirstName NVARCHAR(200) '$.attributes.firstName',
				LastName NVARCHAR(200) '$.attributes.lastName',
				Email NVARCHAR(200) '$.attributes.email',
				Position NVARCHAR(200) '$.attributes.position'

			)
			WHERE DataType='ProfileUsers'

		--Update History
		DELETE FROM tblShipmentHistory WHERE StationID=@StationID

		INSERT INTO tblShipmentHistory(SiteCode,StationID,ChangeID,StageFlg, ChangeDate, UserID,Status)
		SELECT @SiteCode,@StationID,c.ID, CASE c.DataType WHEN 'stationStages' THEN 1 ELSE 0 END, c.ChangeDate, c.UserID, c.AttributeName FROM @Changes c
		WHERE ISNULL(c.Revoked,'')<>'true'
		ORDER BY c.ChangeDate

		--Update Users
		INSERT INTO tblUsers(SiteCode, ProfileUserID, FirstName, LastName, Position, Email)
		SELECT @SiteCode, u.ID, u.FirstName, u.LastName, u.Position, u.Email FROM @User u 
		WHERE NOT EXISTS(SELECT * FROM tblUsers tu WHERE tu.ProfileUserID=u.ID)

		UPDATE tu
		SET tu.FirstName=us.FirstName, tu.LastName=us.LastName, tu.Position=us.Position, tu.Email=us.Email
		FROM tblUsers tu INNER JOIN @User us ON us.ID=tu.ProfileUserID
		WHERE (tu.FirstName<>us.FirstName OR tu.LastName<>us.LastName OR tu.Position<>us.Position OR tu.Email<>us.Email)
END
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID)
	SELECT 'spGetStationHistory','@SiteCode='+@SiteCode+',@StationID='+@StationID+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,1,28
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID)
	SELECT 'spGetStationHistory','@SiteCode='+@SiteCode+',@StationID='+@StationID+',@Page='+CAST(@Page AS varchar(10)),'',@Msg,0,28
	SET @SuccessFlg=0
END CATCH
END
GO
