/****** Object:  StoredProcedure [dbo].[spLoadDocumentS4]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[spLoadDocumentS4](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
AS
BEGIN
DECLARE @Msg NVARCHAR(MAX), @TransportNo VARCHAR(20),@DeliveryNo VARCHAR(20), @FileID INT, @PdfUrl VARCHAR(1000), @GLABSID VARCHAR(100);

SELECT	
	@FileID= td.id,
	@TransportNo =  td.TransportNo,
	@DeliveryNo = td.DeliveryNo,
	@PdfUrl = td.PDFData
FROM [dbo].[tblTransferTransportDocument] td
WHERE td.TransferID=@TransferID

		
	SELECT 
		@GLABsID = [dbo].[fnGetDocumentTypev225](td.DocType,ts.SiteCode,ts.SelfOrganized)
	FROM [dbo].[tblTransferTransportDocument] td
	INNER JOIN [dbo].[tblTransport]  ts ON ts.TransportNo=td.TransportNo
	WHERE td.TransferID=@TransferID

BEGIN TRY

	--Step 1: Download file

	DECLARE @DecodedUrl VARCHAR(1000);
	DECLARE @OutputPath VARCHAR(255);
	DECLARE @CurlCommand VARCHAR(8000);
	DECLARE @ResponseText VARCHAR(MAX);
	DECLARE @DecodedBinary VARBINARY(MAX);
	DECLARE @TempTxtFile NVARCHAR(255);
	DECLARE @SQL NVARCHAR(MAX);

	-- Set the local output path where you want to save the PDF
	SELECT @OutputPath = 'C:\SAPFiles\'+CAST(@FileID AS VARCHAR(20))+'.pdf';
	SELECT @TempTxtFile = 'C:\SAPFiles\'+CAST(@FileID AS VARCHAR(20))+'.txt';
	SET @DecodedBinary = dbo.fnBase64DecodeXML(@PdfUrl);

	-- Convert VARBINARY to NVARCHAR
	SELECT @DecodedUrl= CAST(CAST(@DecodedBinary AS VARCHAR(MAX)) AS NVARCHAR(MAX));


	--SET @CurlCommand = 'curl -s -v -o "' + @OutputPath + '" "' + REPLACE(@PdfUrl, '&amp;', '&') + '"';
	SET @CurlCommand = 'curl -s -v -o "' + @OutputPath + '" "' + @DecodedUrl + '"';


	-- Execute the curl command and capture the output
	EXEC @ResponseText = xp_cmdshell @CurlCommand;

	-- Displaying the response CHECK RESPONSE and file
	PRINT @ResponseText;

	---Check if file exists????

	-----------------------------------
	--Step 2: Load data from file

    DECLARE @PdfBase64 TABLE(
        ID INT IDENTITY(1,1) PRIMARY KEY,
        Base64String NVARCHAR(MAX)
    );


-- Create temp table to hold command output lines
	DECLARE @CmdOutput TABLE(
		Output NVARCHAR(MAX)
	);

	DECLARE @CmdShell NVARCHAR(2000)



	-- Build the PowerShell command to read the file and convert to Base64
	SET @CmdShell = 'powershell -Command "$path = ''' + REPLACE(@OutputPath, '\', '\\') + '''; ' +
					 '$bytes = [System.IO.File]::ReadAllBytes($path); ' +
					 '$base64 = [Convert]::ToBase64String($bytes); ' +
					 '$base64 | Out-File -FilePath ''' + @TempTxtFile + ''' -Encoding UTF8; "';

	-- Execute the command
	EXEC xp_cmdshell @CmdShell;
	--DELETE first
	DELETE FROM dbo.PdfBase64;

	
	-- Prepare dynamic SQL to read from the temporary file
	SET @SQL = 'INSERT INTO dbo.PdfBase64 (Base64String) ' +
				'SELECT * FROM OPENROWSET(BULK ''' + @TempTxtFile + ''', SINGLE_CLOB) AS Source;';

	-- Execute the dynamic SQL
	EXEC sp_executesql @SQL;
	--SELECT TOP 1 * FROM dbo.PdfBase64  order by id desc


	-----------------------------------
	--Step 3: Insert data to Shipment document
	INSERT INTO [dbo].[tblShipmentDocument]
           ([TransportID]
           ,[DeliveryNo]
           ,[GLABsID]
           ,[PDFData]
           ,[CreateDate]
           ,[Status]
           ,[DocumentID]
           ,[DocumentStatus])
	SELECT TOP 1
			   @TransportNo,
			   @DeliveryNo,
			   @GLABSID,
				Base64String,
				GETDATE(),
				0,
				NULL,
				NULL
	FROM dbo.PdfBase64  order by id DESC


	UPDATE ts
	SET ts.DeliveryNo=(SELECT MIN(tc.DeliveryNo) FROM tblCargo tc WHERE tc.TransportID=ts.TransportID )
	FROM tblShipmentDocument ts
	WHERE --ts.TransportID=@TransportNo AND 
	ts.DeliveryNo=''

	UPDATE tblTransferTransportDocument
	SET LoadFlg=1
	WHERE id=@TransferID

	INSERT INTO [dbo].[tblTransferTransportDocumentArchive]
			   ([id]
			   ,[TransferID]
			   ,[TransportNo]
			   ,[DeliveryNo]
			   ,[DocType]
			   ,[PDFData]
			   ,[CreateDate]
			   ,[LoadFlg])
	SELECT
				[id]
			   ,[TransferID]
			   ,[TransportNo]
			   ,[DeliveryNo]
			   ,[DocType]
			   ,[PDFData]
			   ,[CreateDate]
			   ,[LoadFlg]
	FROm [dbo].[tblTransferTransportDocument]
	WHERE TransFerID=@TransferID

	--Delete
	DELETE FROM tblTransferTransportDocument WHERE TransferID=@TransferID

	SET @Msg='SAP document load success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, TransferIn,TransportNo,DeliveryNo,ProcessID)
	SELECT 'spLoadDocumentS4','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,1,@TransferID,@TransportNo,@DeliveryNo,21
	
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tblTransferTransportDocument
	SET LoadFlg=0
	WHERE TransferID=@TransferID

	SELECT @Msg=ERROR_MESSAGE()
	--SET @Msg='SAP Load failure'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, TransferIn,TransportNo,DeliveryNo,ProcessID)
	SELECT 'spLoadDocumentS4','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,@TransferID,@TransportNo,@DeliveryNo,21

	SET @SuccessFlg=0
END CATCH

END
GO
