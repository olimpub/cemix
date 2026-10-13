/****** Object:  StoredProcedure [dbo].[spValidateLicensePlateNo]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spValidateLicensePlateNo](
	@SiteCode VARCHAR(10),
	@LicensePlate  VARCHAR(20),
	@GateNo VARCHAR(10),
	@SuccessFlg BIT OUT
	
)
AS 
BEGIN

	DECLARE @GateID INT, @OpenFlg BIT, @CmdNotEnter VARCHAR(200), @CmdEnter VARCHAR(200), @LogID INT
	SELECT @SiteCode=CASE @SiteCode 
			WHEN 'H6K1' THEN 'H311'
			WHEN 'H6K2' THEN 'H312'
			WHEN 'H6K4' THEN 'H314'
			WHEN 'H6K5' THEN 'H315'
			ELSE @SiteCode
		END
	
	INSERT INTO [dbo].[tblGateLog]
           ([LicensePlate]
           ,[SiteCode]
           ,[GateNo])
	SELECT 
			@LicensePlate,
			@SiteCode,
			@GateNo

	
	SELECT @LogID=SCOPE_IDENTITY();
	

	DECLARE @CmdRes TABLE(
		Result VARCHAR(2000)
		)
	

	BEGIN TRY

	SELECT @LicensePlate=[dbo].[FnRemoveSpecialCharacters](@LicensePlate)

	SELECT @GateID=tg.id, @CmdNotEnter=tg.CmdNotEnter, @CmdEnter=tg.CmdEnter
	FROM tblGate tg WHERE tg.SiteCode=@SiteCode AND tg.GateNo=@GateNo
	
	UPDATE [dbo].[tblGateLog]
	SET GateID=@GateID
	WHERE id=@LogID
	
	--
	DELETE FROM tblActivePlates WHERE SiteCode=@SiteCode


	--Here to write out LP
	--EXEC dbo.sp_start_job N'Job name' ;

	EXECUTE [dbo].[spGetCalls] @SiteCode=@SiteCode, @Page=1, @SuccessFlg=@SuccessFlg OUT
	EXECUTE [dbo].[spGetUnplanned] @SiteCode=@SiteCode, @Page=1, @SuccessFlg=@SuccessFlg OUT
	EXECUTE [dbo].[spGetEntryPermission] @SiteCode=@SiteCode, @Page=1, @SuccessFlg=@SuccessFlg OUT

	-----
	IF EXISTS(SELECT * FROM tblActivePlates WHERE PlateNo=@LicensePlate AND SiteCode=@SiteCode)
	BEGIN
			SET @SuccessFlg=1
				
			UPDATE [dbo].[tblGateLog]
			SET PermissionFlg=@SuccessFlg
			WHERE id=@LogID
			
			--Check Gate
			
			EXECUTE [dbo].[spCheckGate]
				@GateID=@GateID,
				@OpenFlg=@OpenFlg OUT
			
			UPDATE [dbo].[tblGateLog]
			SET AlreadyOpenFlg=@OpenFlg
			WHERE id=@LogID
		
			IF(@OpenFlg=0)
			BEGIN
				EXECUTE [dbo].[spOpenGate]
					@GateID=@GateID,
					@SuccessFlg=@SuccessFlg OUT
			
				UPDATE [dbo].[tblGateLog]
				SET OpenSuccessFlg=@SuccessFlg
				WHERE id=@LogID
				
			END
			
			
			--SELECT @SuccessFlg, @CmdEnter,@CmdNotEnter
			IF(@CmdEnter IS NOT NULL)
			BEGIN
				INSERT INTO @CmdRes
				EXEC xp_cmdshell @CmdEnter
				
				UPDATE [dbo].[tblGateLog]
				SET CmdCall=@CmdEnter
				WHERE id=@LogID

				INSERT INTO [dbo].[tblGateCmdLog](
					[LogID],
					[Result]
				)
				SELECT @LogID, Result
				FROM @CmdRes
				
			END
			
	END
	ELSE
	BEGIN
		SET @SuccessFlg=0
		
		UPDATE [dbo].[tblGateLog]
		SET PermissionFlg=@SuccessFlg
		WHERE id=@LogID
		
		IF(@CmdNotEnter IS NOT NULL)
		BEGIN
			INSERT INTO @CmdRes
			EXEC xp_cmdshell @CmdNotEnter
			
			UPDATE [dbo].[tblGateLog]
			SET CmdCall=@CmdNotEnter
			WHERE id=@LogID

			INSERT INTO [dbo].[tblGateCmdLog](
				[LogID],
				[Result]
			)
			SELECT @LogID, Result
			FROM @CmdRes
			
		END
		
	END


	END TRY
	BEGIN CATCH
		SET @SuccessFlg=0
		
		IF(@CmdNotEnter IS NOT NULL)
		BEGIN
			INSERT INTO @CmdRes
			EXEC xp_cmdshell @CmdNotEnter
			
			UPDATE [dbo].[tblGateLog]
			SET CmdCall=@CmdNotEnter
			WHERE id=@LogID

			INSERT INTO [dbo].[tblGateCmdLog](
				[LogID],
				[Result]
			)
			SELECT @LogID, Result
			FROM @CmdRes
			
		END
		
	END CATCH
END
GO
