/****** Object:  StoredProcedure [dbo].[spCreateFileBody_depr]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spCreateFileBody_depr](
	@TransferID INT,
	@DocumentID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

--SELECT * FROM tblShipmentDocument 
--SELECT * FROm tblXrefDocumentType

DECLARE @TransportExists BIT, @TransportID VARCHAR(100), @DeliveryNo VARCHAR(100), @Content NVARCHAR(MAX), @CargoID VARCHAR(30), @DocumentType VARCHAR(50), @ExportType VARCHAR(20),@DocumentName VARCHAR(100)
SELECT @TransportID= sd.TransportID, @DeliveryNo = sd.DeliveryNo, @Content=sd.PDFData, @DocumentType = sd.GLABsID--, @ExportType=xd.SAPID 
FROM tblShipmentDocument sd
--LEFT OUTER JOIN tblXrefDocumentType xd ON xd.GLABsID=sd.GLABsID
WHERE sd.id=@DocumentID
IF EXISTS(SELECT * FROM tblXrefDocumentType xd WHERE xd.GLABsID=@DocumentType AND xd.SAPID='CMR')
BEGIN
	SET @DocumentName='CMR_'+@TransportID+'_'+CAST(@DocumentID AS varchar(10))
END
ELSE
BEGIN
	SET @DocumentName='DN_'+@DeliveryNo+'_'+CAST(@DocumentID AS varchar(10))
END
/*
IF(ISNULL(@ExportType,'')='DLV')
BEGIN
	SET @DocumentName='DN'+@DeliveryNo
END
ELSE IF((ISNULL(@ExportType,'')='CRM'))
BEGIN
	SET @DocumentName='CRM'+@TransportID
END
ELSE
BEGIN
	SET @DocumentName='NA'+@DeliveryNo
END
*/
--SET @DocumentName=CAST(@DocumentID AS varchar(10))+'_'+@TransportID


SELECT @CargoID = MAX(tc.GLABsID) FROM tblShipment ts
INNER JOIN tblTransport tts ON tts.TransportNo=ts.TransportID
INNER JOIN tblClientParams cp ON cp.SiteCode=ts.SiteCode
INNER JOIN tblCargo tc ON tc.TransportID=tts.TransportNo AND tc.SourceSiteCode=ts.SiteCode 
LEFT OUTER JOIN tblShipmentDocument tsd ON tsd.TransportID=tc.TransportID AND tsd.DeliveryNo=tc.DeliveryNo
WHERE tsd.id=@DocumentID

--SELECT @ShipmentID, @Direction,@NoOfItems,@DeliveryNo

DELETE FROM JSONText WHERE TransferID=@TransferID

INSERT INTO JSONText
SELECT @TransferID,'data.type','''cargoDocuments''',''

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.name',''''+@DocumentName+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.targets','''organizer''','' 
/*
INSERT INTO JSONText
SELECT @TransferID,'data.attributes.targets','''carrier''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.targets','''partner''','' 
*/
INSERT INTO JSONText
SELECT @TransferID,'data.attributes.comment','''''','' 


INSERT INTO JSONText
SELECT @TransferID,'data.relationships.cargo.data.type','''shipmentCargos''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.cargo.data.id',''''+@CargoID+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.types.data.type','''documentTypes''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.types.data.id',''''+@DocumentType+'@rep''','' 

--ADD
SELECT * FROM JSONText WHERE TransferID=@TransferID

DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL=COALESCE(@SQL, '','') +js.JsonText +' AS "' +js.JsonField +'",' FROM JSONText js
WHERE js.TransferID=@TransferID
ORDER BY js.RowID


SELECT @SQL=N'SELECT @JSON=(SELECT '+LEFT(@SQL,LEN(@SQL)-1)+' FOR JSON PATH)'
PRINT @SQL
DECLARE @params NVARCHAR(250)
SET @Params='@JSON NVARCHAR(MAX) OUTPUT'

EXEC sp_executesql @SQL,@Params, @JSON=@Body OUTPUT

SELECT @Body=LEFT(@Body,LEN(@Body)-1)
SELECT @Body=RIGHT(@Body,LEN(@Body)-1)
SELECT @Body=REPLACE(@Body,'\/','/')

SELECT @Body=REPLACE(@Body,'"targets":"organizer"','"targets":["organizer", "carrier", "partner"]')
SELECT @Body=REPLACE(@Body,'"types":{"data":{','"types":{"data":[{')
SELECT @Body=REPLACE(@Body,'@rep"}','"}]')

-----
PRINT @Body

SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SET @SuccessFlg=0
END CATCH
END
GO
