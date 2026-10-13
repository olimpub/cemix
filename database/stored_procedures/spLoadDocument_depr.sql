/****** Object:  StoredProcedure [dbo].[spLoadDocument_depr]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spLoadDocument_depr](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
AS
BEGIN
DECLARE @Msg NVARCHAR(MAX), @TransportNo VARCHAR(20),@DeliveryNo VARCHAR(20)

SELECT	
	@TransportNo =  td.TransportNo,
	@DeliveryNo = td.DeliveryNo
FROM [dbo].[tblTransferTransportDocument] td
WHERE td.TransferID=@TransferID

BEGIN TRY

	INSERT INTO [dbo].[tblShipmentDocument]
			   ([TransportID]
			   ,[DeliveryNo]
			   ,[GLABsID]
			   ,[PDFData]
			   ,[CreateDate]
			   ,[Status])
	SELECT	
		td.TransportNo,
		td.DeliveryNo,
		[dbo].[fnGetDocumentTypev225](td.DocType,ts.SiteCode,ts.SelfOrganized),
		td.PDFData,
		GETDATE(),
		0
	FROM [dbo].[tblTransferTransportDocument] td
	INNER JOIN [dbo].[tblTransport]  ts ON ts.TransportNo=td.TransportNo
	WHERE td.TransferID=@TransferID

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
	SELECT 'spLoadDocument','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,1,@TransferID,@TransportNo,@DeliveryNo,21
	
	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	UPDATE tblTransferTransportDocument
	SET LoadFlg=0
	WHERE id=@TransferID

	SELECT @Msg=ERROR_MESSAGE()
	--SET @Msg='SAP Load failure'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, TransferIn,TransportNo,DeliveryNo,ProcessID)
	SELECT 'spLoadDocument','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,@TransferID,@TransportNo,@DeliveryNo,21

	SET @SuccessFlg=0
END CATCH

END
GO
