/****** Object:  StoredProcedure [dbo].[spCheckGate]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spCheckGate](
	@GateID INT,
	@OpenFlg BIT OUT
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
		@TransferID INT,
		@CurrentDate VARCHAR(30), 
		@SuccessFlg BIT,
		@RowText VARCHAR(500)

SELECT @URL=tg.GateAddress+'api2.cgi?p='+tg.Password+'&sw='+tg.GateNo FROM tblGate tg WHERE tg.id=@GateID
	
--SELECT @URL='http://10.180.80.104/api2.cgi?p=pulsator1234&t0=2&sw='+@GateNo+'&v=1'
--SELECT @URL='http://10.180.80.104/api2.cgi?p=pulsator1234&sw='+@GateNo

--TOKEN

--Create Header
SET @Header=''
--Other data
SET @ResponseAccept=''
SET @MsgType=''
SET @Body=''
SET @MsgMethod='GET'

SET @TransferType=34

BEGIN TRY
--Insert Transfer
INSERT INTO tblTransferOut(TransferType,URL,Header,Body,MsgType,MsgMethod,ResponseAccept,Status)
SELECT @TransferType,@URL,@Header,@Body,@MsgType,@MsgMethod,@ResponseAccept,0

SELECT @TransferID=SCOPE_IDENTITY()

--Execute Webrequest
EXECUTE spSendWebRequest @TransferID=@TransferID, @SuccessFlg=@SuccessFlg OUT

--SELECT @TransferID

IF(@SuccessFlg=0)
BEGIN
	SET @Msg='WebRequest Failed'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spCheckGate','@GateID='+CAST(@GateID AS varchar(10)),'',@Msg,0,22,@TransferID

	RETURN
END
ELSE
BEGIN
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		
		DECLARE @IText TABLE(
			RowID INT IDENTITY(1,1),
			ResponseText NVARCHAR(1000)
		)

		DECLARE @RText TABLE(
			RowID INT IDENTITY(1,1),
			RowText VARCHAR(100)
		)

		INSERT INTO @IText(ResponseText)
		SELECT value FROM STRING_SPLIT(@Msg,CHAR(10))
		WHERE RTRIM(value) <> '';


		SELECT @RowText=ResponseText FROM @IText WHERE RowID=4

		INSERT INTO @RText(RowText)
		SELECT value FROM STRING_SPLIT(@RowText,CHAR(63))
		WHERE RTRIM(value) <> '';

		IF EXISTS(SELECT * FROM @RText WHERE RowID=@GateID AND LEFT(RowText,2)='ON')
		BEGIN
			SET @OpenFlg=1
		END
		ELSE
		BEGIN
			SET @OpenFlg=0
		END


END
 	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spCheckGate','@GateID='+CAST(@GateID AS varchar(10)),'',@Msg,1,22,@TransferID

	SET @SuccessFlg=1

END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spCheckGate','@GateID='+CAST(@GateID AS varchar(10)),'',@Msg,0,22,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
