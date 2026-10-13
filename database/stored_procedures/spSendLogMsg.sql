/****** Object:  StoredProcedure [dbo].[spSendLogMsg]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spSendLogMsg]
(
	@LogID	INT
)
AS 
BEGIN

BEGIN TRY

DECLARE @TransferID         BIGINT,
        @InvoiceNo          VARCHAR(50),
        @LogDate          VARCHAR(50),
        @ActionName        VARCHAR(100),
        @SPName		     VARCHAR(200),
		@InParams		VARCHAR(1000),
		@OutParams		VARCHAR(1000),
        @Message            NVARCHAR(MAX),
		@TransportNo		VARCHAR(100),
		@DeliveryNo			VARCHAR(100),
		@ItemNo				VARCHAR(10),
		@PartnerID			VARCHAR(10),
		@TransferIn			INT,
		@TransferOut		INT,
        @Attachments        VARCHAR(500),
        @EmailGroup         VARCHAR(10),
        @TransactionID      INT,
		@Folder         VARCHAR(200),
		@FileName       VARCHAR(200),
		@DBName         VARCHAR(50),
		@ServerName     VARCHAR(50),
		@Path           VARCHAR(500),
		@BCP            VARCHAR(1000),
		@Recipients	 VARCHAR(2000),
		@Subject		VARCHAR(200),
		@BodyMessage  NVARCHAR(MAX),
		@BodyMessage1 NVARCHAR(1000),
		@BodyMessage2 NVARCHAR(1000),
		@BodyMessage3 NVARCHAR(1000),
		@Importance  VARCHAR(10),
		@SourceSystem VARCHAR(100),
		@TargetSystem VARCHAR(100),
		@SuccessFlg	BIT,
		@SuccessMessage VARCHAR(100)

SELECT @ActionName = tlo.ActionName, @SPName = tl.SPName, @InParams = tl.Inparams, @OutParams = tl.Outparams,  @Message = tl.Msg, @TransportNo = tl.TransportNo, 
@DeliveryNo = tl.DeliveryNo, @ItemNo = tl.ItemNo, @PartnerID = tl.PartnerID,  @TransferIn = tl.TransferIn, @TransferOut =  tl.TransferOut, @LogDate = tl.LogDate, @SuccessFlg=tl.SuccessFlg,
@Recipients=CASE tl.SuccessFlg WHEN 1 THEN tlo.SuccessRecipients ELSE tlo.FailRecipients END
FROM tblLog tl
LEFT OUTER JOIN tblLogProcess tlo ON tlo.id=tl.ProcessID
WHERE tl.id=@LogID 

IF (@SuccessFlg=1)
BEGIN
	SET @SuccessMessage='Success'
END
ELSE
BEGIN
	SET @SuccessMessage='Failure'
END

SELECT @BodyMessage1='
Dear User,<br><br>
the following Middleware process result is: <b>'+@SuccessMessage+'</b>. <br><br>'

SELECT @ServerName=@@SERVERNAME, @DBName=DB_NAME()

IF(@DBName='Middleware_prod')
BEGIN
	SELECT @Subject ='Middleware Run '+@SuccessMessage +' '+CAST(@LogID AS VARCHAR(100))
END
ELSE
BEGIN
	SELECT @Subject ='TEST Middleware Run '+@SuccessMessage +' '+CAST(@LogID AS VARCHAR(100))
END

SELECT @BodyMessage2='
You can find details below: <br>
Action Name:<b>'+ISNULL(@ActionName,'')+'</b><br>
Procedure Name:<b>'+ISNULL(@SPName,'')+'</b><br>
Inbound params:<b>'+ISNULL(@InParams,'')+'</b><br>
Outbound params:<b>'+ISNULL(@OutParams,'')+'</b><br>
Message:<b>'+ISNULL(@Message,'')+'</b><br>
Log Date:<b>'+ISNULL(@LogDate,'')+'</b><br>'

IF(@TransportNo IS NOT NULL)
BEGIN
SET @BodyMessage2=@BodyMessage2+'
Transport No:<b>'+@TransportNo+'</b><br>'
END

IF(@DeliveryNo IS NOT NULL)
BEGIN
SET @BodyMessage2=@BodyMessage2+'
Delivery No:<b>'+@DeliveryNo+'</b><br>'
END

IF(@ItemNo IS NOT NULL)
BEGIN
SET @BodyMessage2=@BodyMessage2+'
Item No:<b>'+@ItemNo+'</b><br>'
END

IF(@PartnerID IS NOT NULL)
BEGIN
SET @BodyMessage2=@BodyMessage2+'
Partner ID:<b>'+CAST(@PartnerID AS VARCHAR(10))+'</b><br>'
END

SET @BodyMessage3='

<br>More details can be found in the attachment(s):<br><br>

Regards,<br>
Middleware Message Center
'



DECLARE @ResultTable TABLE(
		Result VARCHAR(MAX)
	)

DECLARE @FileID INT,@Body NVARCHAR(MAX),@Response NVARCHAR(MAX), @Header VARCHAR(500),@URL VARCHAR(1000), @Status VARCHAR(100), @StatusCode VARCHAR(200)
SET @Folder='C:\Export\'
SET @Attachments=''
IF(@TransferOut IS NOT NULL)
BEGIN
	SELECT @URL = tou.URL,@Header=tou.Header, @Status = tou.StatusDesc, @StatusCode = tou.StatusCode FROM tblTransferOut tou WHERE tou.id=@TransferOut
	SELECT @BodyMessage2=@BodyMessage2+'
<br>-------------------------------<br>
File details below: <br>
URL:<b>'+ISNULL(@URL,'')+'</b><br>
Header:<b>'+ISNULL(@Header,'')+'</b><br>
Status code:<b>'+ISNULL(@StatusCode,'')+'</b><br>
Status:<b>'+ISNULL(@Status,'')+'</b><br><br>'

	SELECT @FileName='Msg_'+CAST(@TransferOut AS VARCHAR(10))+'.json'
	SET @Path=@Folder+@FileName
	
	SET @BCP='bcp "SELECT tou.Body FROM '+@DBName+'.dbo.tblTransferOut tou WHERE tou.id='+CAST(@TransferOut AS VARCHAR(10))+'" queryout '+@Path+' -S'+@ServerName+' -c -t , -T -C1250'  

	SET @Attachments=@Attachments+@Path+';'
	--PRINT @BCP
	INSERT INTO @ResultTable
	(
		Result
	)
	EXEC master..xp_cmdshell @BCP

	SELECT @FileName='Response_'+CAST(@TransferOut AS VARCHAR(10))+'.json'
	SET @Path=@Folder+@FileName
	SET @BCP='bcp "SELECT tou.ReturnMsg FROM '+@DBName+'.dbo.tblTransferOut tou WHERE tou.id='+CAST(@TransferOut AS VARCHAR(10))+'" queryout '+@Path+' -S'+@ServerName+' -c -t , -T -C1250'  

	--PRINT @BCP
	INSERT INTO @ResultTable
	(
		Result
	)
	EXEC master..xp_cmdshell @BCP
	
	
	SET @Attachments=@Attachments+@Path+';'
	SELECT @Attachments=LEFT(@Attachments,LEN(@Attachments)-1)
END

IF(@TransferIn IS NOT NULL)
BEGIN
	SELECT @FileName='XMLData_'+CAST(@TransferIn AS VARCHAR(10))+'.xml'
	SET @Path=@Folder+@FileName

	SET @BCP='bcp "SELECT tin.BodyXML FROM '+@DBName+'.dbo.tblTransferIn tin WHERE tin.id='+CAST(@TransferIn AS VARCHAR(10))+'" queryout '+@Path+' -S'+@ServerName+' -c -t , -T -C1250'  
	PRINT @BCP
	INSERT INTO @ResultTable
	(
		Result
	)
	EXEC master..xp_cmdshell @BCP

	SET @Attachments=@Attachments+@Path+';'
	SELECT @Attachments=LEFT(@Attachments,LEN(@Attachments)-1)
END

SELECT @Attachments

SELECT @BodyMessage=@BodyMessage1+@BodyMessage2+@BodyMessage3
SELECT @Attachments AS 'Attachments', @BodyMessage1, @BodyMessage2, @BodyMessage3, @BodyMessage

	EXEC msdb.dbo.sp_send_dbmail
	@profile_name = 'Lasselsberger SMTP',
    @recipients = @Recipients,
    @body_format = 'HTML',
    @body = @BodyMessage,
    @subject = @Subject,
    @file_attachments=@Attachments
 --   @blind_copy_recipients='bakos.daniel@pulsator.hu',
 --   @importance ='HIGH' 

	--Update 
	UPDATE tl
	SET tl.NotificationFlg=1
	FROM tblLog tl
	WHERE tl.id=@LogID
END TRY
BEGIN CATCH
	--Update 
	UPDATE tl
	SET tl.NotificationFlg=0
	FROM tblLog tl
	WHERE tl.id=@LogID
END CATCH
END
GO
