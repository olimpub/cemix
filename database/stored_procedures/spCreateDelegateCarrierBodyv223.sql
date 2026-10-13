/****** Object:  StoredProcedure [dbo].[spCreateDelegateCarrierBodyv223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCreateDelegateCarrierBodyv223](
	@TransferID INT,
	@TransportID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

DECLARE @ShipmentNo VARCHAR(50), @SelfOrganized BIT, @PartnerID VARCHAR(50), @CarrierID VARCHAR(50), @PartnetCounter SMALLINT, @DelegateType SMALLINT,@Cntr SMALLINT

SELECT @ShipmentNo=ts.GLABsID, @CarrierID=ts.CarrierID FROM tblTransport ts WHERE ts.id=@TransportID

DELETE FROM JSONText WHERE TransferID=@TransferID

INSERT INTO JSONText
SELECT @TransferID,'data.type','''shipments''',''

INSERT INTO JSONText
SELECT @TransferID,'data.id',''''+@ShipmentNo+'''','' 


INSERT INTO JSONText
SELECT @TransferID,'data.relationships.carrierDelegation.data.pointer','''/included/0''','' 

DECLARE @MaxID INT
SELECT @MaxID=MAX(RowID)+1 FROM JSONText js
WHERE js.TransferID=@TransferID

DECLARE @RemoveSegmentList TABLE(
	RemoveSegment VARCHAR(500)
)



--INCLUDED PART
INSERT INTO JSONText
	SELECT @TransferID,'included.included0.type','''shipmentDelegations''','' 

INSERT INTO JSONText
	SELECT @TransferID,'included.included0.relationships.partnerOrigin.data.type','''partners''','' 

INSERT INTO JSONText
		SELECT @TransferID,'included.included0.relationships.partnerOrigin.data.id',''''+@CarrierID+'''','' 

INSERT INTO @RemoveSegmentList
SELECT 'included0'


UPDATE js
SET js.JsonField=REPLACE(JsonField,'@',CAST(js.RowID AS varchar(10)))
FROM JSONText js
WHERE js.TransferID=@TransferID
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

DECLARE @Replace TABLE(
	RowID VARCHAR(10),
	ReplaceText VARCHAR(100)
)

INSERT INTO @Replace
SELECT CAST(js.RowID AS varchar(9)),js.JsonSQL FROM JSONText js
WHERE js.TransferID=@TransferID
AND JsonSQL<>''


DECLARE @From VARCHAR(10),@To VARCHAR(100)

INSERT INTO @Replace
SELECT '',RemoveSegment FROM @RemoveSegmentList

SELECT @Cntr= COUNT(*) FROM @Replace

WHILE EXISTS(SELECT * FROM @Replace)
BEGIN
	SELECT TOP 1 @From=ReplaceText FROM @Replace
	SELECT @Body=REPLACE(@Body,('"'+@From+'":'),'')
	DELETE @Replace WHERE ReplaceText=@From
END


--Fix Array
SELECT @Body=REPLACE(@Body,'"included":{','"included":[')
IF(@Cntr>0)
BEGIN
	SELECT @Body=LEFT(@Body,(LEN(@Body)-2))+']}'
END
PRINT 'Final'
PRINT '----------------------'
PRINT @Body

SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SET @SuccessFlg=0
END CATCH
END
GO
