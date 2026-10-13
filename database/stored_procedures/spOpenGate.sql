/****** Object:  StoredProcedure [dbo].[spOpenGate]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spOpenGate](
	@GateID INT,
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
		@Filter NVARCHAR(500),
		@CurrentDate VARCHAR(30)
		
SELECT @URL=tg.GateAddress+'api2.cgi?p='+tg.Password+'&t0=2&sw='+tg.GateNo+'&v=1' FROM tblGate tg WHERE tg.id=@GateID
	

--Create Header
SET @Header=''
--Other data
SET @ResponseAccept=''
SET @MsgType=''
SET @Body=''
SET @MsgMethod='GET'

SET @TransferID=97   ----NEED TO ADD
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
	SELECT 'spOpenGate','@GateNo='+CAST(@GateID AS varchar(10)),'',@Msg,0,22,@TransferID

	RETURN
END
ELSE
BEGIN
		DECLARE @MaxPage SMALLINT
		SELECT @Msg=tou.ReturnMsg FROM tblTransferOut tou WHERE id=@TransferID
		
		PRINT @Msg
END
 	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spOpenGate','@GateNo='+CAST(@GateID AS varchar(10)),'',@Msg,1,22,@TransferID

	SET @SuccessFlg=1

END TRY
BEGIN CATCH
	SELECT @Msg=ERROR_MESSAGE()
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransferOut)
	SELECT 'spOpenGate','@GateNo='+CAST(@GateID AS varchar(10)),'',@Msg,0,22,@TransferID
	SET @SuccessFlg=0
END CATCH
END
GO
