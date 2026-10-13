/****** Object:  StoredProcedure [dbo].[spUploadFileBody]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spUploadFileBody](
	@DocumentID INT,
	@Body VARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

DECLARE @TransportExists BIT, @TransportID VARCHAR(100), @DeliveryNo VARCHAR(100), @Content NVARCHAR(MAX),@PDFData VARCHAR(MAX)
SELECT @TransportID= sd.TransportID, @DeliveryNo = sd.DeliveryNo, @Content=sd.PDFData FROM tblShipmentDocument sd WHERE sd.id=@DocumentID

/*
EXECUTE  [dbo].[spBase64Decode]
				@InText=@Content,
				@OutText=@PDFData OUT
*/				

--SELECT @PDFData=dbo.fnBase64DecodeCLR(@Content)
--SELECT @PDFData

SELECT @Body=@TransportID+@DeliveryNo+'_'+CAST(@DocumentID AS VARCHAR(20))+';'+@Content
-----
PRINT @Body

SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SET @SuccessFlg=0
END CATCH
END
GO
