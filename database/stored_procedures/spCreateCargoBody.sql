/****** Object:  StoredProcedure [dbo].[spCreateCargoBody]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




--Requires functions
--CargoNew
----type
----attributes
--Relationships
----SourcePartnerOrigin
----Destination
----station
----shipment
----items
--CargoIncluded
----StationNew
----ShipmentNew
----ItemsNew
-----------------------------
--Partner
----type
----attributes
----profile
---------------------------------
/*URL includes Shipment*/
--CargoAdd
----type
----attributes
--Relationships
----Source
----Destination
----station
----shipment
----items
--CargoIncluded
----ItemsNew

CREATE PROCEDURE [dbo].[spCreateCargoBody](
	@TransferID INT,
	@CargoID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

DECLARE @TransportExists BIT, @TransportID VARCHAR(100), @DeliveryNo VARCHAR(100),@Colli SMALLINT, @Comment NVARCHAR(500),@Direction BIT, 
@SourcePartnerID VARCHAR(50), @DestinationPartnerID VARCHAR(50), @NoOfItems SMALLINT, @ShipmentID VARCHAR(50), @StationID VARCHAR(50), @IncludedText VARCHAR(100),@ShipmentRule VARCHAR(50),@CarrierID VARCHAR(50)
SELECT @TransportID = tc.TransportID, @DeliveryNo=tc.DeliveryNo, @Colli = tc.Colli, @Comment=tc.Comment, @Direction=tc.Direction, @SourcePartnerID=tc.SourcePartnerID, @DestinationPartnerID= tc.DestinationPartnerID  FROM tblCargo tc WHERE id=@CargoID
SELECT @NoOfItems = COUNT(*) FROM tblCargoItem WHERE DeliveryNo=@DeliveryNo
SELECT @ShipmentID=ts.GLABsID, @StationID = ts.StationID, @ShipmentRule=ts.ShipmentRule,@CarrierID=ts.CarrierID FROM tblShipment ts WHERE ts.TransportID=@TransportID

--SELECT @ShipmentID, @Direction,@NoOfItems,@DeliveryNo

DELETE FROM JSONText WHERE TransferID=@TransferID

INSERT INTO JSONText
SELECT @TransferID,'data.type','''shipmentCargos''',''

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.number',''''+@DeliveryNo+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.colli',''''+CAST(@Colli AS varchar(10))+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.comment',''''+@Comment+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.ekaerCode','''''','' 

--Partners
IF(@ShipmentID IS NULL)
BEGIN

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.sourcePartnerOrigin.data.type','''partners''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.sourcePartnerOrigin.data.id',''''+@SourcePartnerID+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.destinationPartnerOrigin.data.type','''partners''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.destinationPartnerOrigin.data.id',''''+@DestinationPartnerID+'''','' 
END
ELSE
BEGIN
	IF(@Direction=1)
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationPartnerOrigin.data.type','''partners''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationPartnerOrigin.data.id',''''+@DestinationPartnerID+'''','' 
	END
	ELSE
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourcePartnerOrigin.data.type','''partners''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourcePartnerOrigin.data.id',''''+@SourcePartnerID+'''','' 
	END
END

--Station
IF(@StationID IS NULL)
BEGIN
	IF(@Direction=1)
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceStation.data.pointer','''/included/0''','' 
	END
	ELSE
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationStation.data.pointer','''/included/0''','' 
	END
END
ELSE
BEGIN
	IF(@Direction=1)
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceStation.data.type','''shipmentStations''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceStation.data.id',''''+@StationID+'''','' 
	END
	ELSE
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationStation.data.type','''shipmentStations''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationStation.data.id',''''+@StationID+'''','' 
	END
END

--Shipment
IF(@ShipmentID IS NULL)
BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.shipment.data.pointer','''/included/1''','' 
END
ELSE
BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.shipment.data.type','''shipments''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.shipment.data.id',''''+@ShipmentID+'''','' 
END

--Items
DECLARE @Pos SMALLINT
IF(@ShipmentID IS NULL)
BEGIN
	SET @Pos=2
END
ELSE
BEGIN
	SET @Pos=0
END 

UPDATE ci
SET ci.IncludedText=(SELECT '/included/'+CAST(COUNT(*)+@Pos AS varchar(5)) FROM [dbo].[tblCargoItem] cii WHERE cii.ItemNo<ci.ItemNo AND cii.DeliveryNo=ci.DeliveryNo)
FROM  [dbo].[tblCargoItem] ci
WHERE ci.DeliveryNo=@DeliveryNo

DECLARE @IncludedTextTable TABLE(
	IncludedText VARCHAR(100)
)

INSERT INTO @IncludedTextTable
SELECT ci.IncludedText
FROM  [dbo].[tblCargoItem] ci
WHERE ci.DeliveryNo=@DeliveryNo



WHILE EXISTS(SELECT * FROM @IncludedTextTable)
BEGIN
	SELECT TOP 1 @IncludedText =  it.IncludedText FROM @IncludedTextTable it

	INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.items.data.s@.r@',''''+@IncludedText+'''','pointer' 

	DELETE FROM @IncludedTextTable WHERE IncludedText=@IncludedText 
END

DECLARE @MaxID INT
SELECT @MaxID=MAX(RowID)+1 FROM JSONText js
WHERE js.TransferID=@TransferID

DECLARE @RemoveSegmentList TABLE(
	RemoveSegment VARCHAR(500)
)



--INCLUDED PART
IF(@StationID IS NULL)
BEGIN
	INSERT INTO JSONText
		SELECT @TransferID,'included.included0.type','''shipmentStations''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included0.relationships.shipmentRuleOrigin.data.type','''shipmentRules''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included0.relationships.shipmentRuleOrigin.data.id',''''+@ShipmentRule+'''','' 

	INSERT INTO @RemoveSegmentList
	SELECT 'included0'
END


IF(@ShipmentID IS NULL)
BEGIN
	INSERT INTO JSONText
		SELECT @TransferID,'included.included1.type','''shipments''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included1.attributes.transportId',''''+[dbo].[fnCutLeadZeros](@TransportID)+'''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included1.relationships.carrierOrigin.data.type','''carriers''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included1.relationships.carrierOrigin.data.id',''''+@CarrierID+'''','' 

	INSERT INTO @RemoveSegmentList
	SELECT 'included1'
END


DECLARE @Items TABLE(
	RowID INT
)
INSERT INTO @Items
SELECT id FROM tblCargoItem WHERE DeliveryNo=@DeliveryNo
DECLARE @RowID INT, @ItemCode VARCHAR(20),@ItemName NVARCHAR(300),@Qty NUMERIC(9,2),@RowComment NVARCHAR(1000),@Picking VARCHAR(10),@QtyUnit VARCHAR(50), @ItemSegment VARCHAR(20)
WHILE EXISTS(SELECT * FROM @Items)
BEGIN
	SELECT TOP 1  @RowID = RowID FROM @Items ORDER BY RowID

	SELECT  @ItemCode=ci.ItemCode,@ItemName = ci.ItemName, @Qty = ci.Qty, @RowComment =  ci.Comment, @Picking = ci.PickingFlg /*CASE ci.PickingFlg WHEN 1 THEN 'true' ELSE 'false' END*/,@QtyUnit = ci.QtyUnitID, @ItemSegment = REPLACE(ci.IncludedText,'/','') FROM tblCargoItem ci WHERE ci.id=@RowID

	INSERT INTO JSONText
		SELECT @TransferID,'included.'+@ItemSegment+'.type','''cargoItems''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.'+@ItemSegment+'.attributes.code',''''+@ItemCode+'''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.'+@ItemSegment+'.attributes.name',''''+@ItemName+'''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.'+@ItemSegment+'.attributes.quantity',CAST(@Qty AS varchar(10)),'' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.'+@ItemSegment+'.attributes.comment',''''+@RowComment+'''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.'+@ItemSegment+'.attributes.picking.required','CAST('+CAST(@Picking AS varchar(10))+'AS BIT)','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.'+@ItemSegment+'.relationships.quantityUnit.data.type','''quantityUnits''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.'+@ItemSegment+'.relationships.quantityUnit.data.id',''''+@QtyUnit+'''','' 

	INSERT INTO @RemoveSegmentList
	SELECT @ItemSegment

	DELETE FROM @Items WHERE RowID=@RowID
END

UPDATE js
SET js.JsonField=REPLACE(JsonField,'@',CAST(js.RowID AS varchar(10)))
FROM JSONText js
WHERE js.TransferID=@TransferID
--ADD
--SELECT * FROM JSONText WHERE TransferID=@TransferID

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

WHILE EXISTS(SELECT * FROM @Replace)
BEGIN
	

	SELECT TOP 1 @From=RowID,@To='"'+ReplaceText+'"' FROM @Replace
	SELECT @Body=REPLACE(@Body,('"r'+@From+'"'),@To)
	SELECT @Body=REPLACE(@Body,('"s'+@From+'":'),'')
	DELETE @Replace WHERE RowID=@From
END
SELECT @Body=REPLACE(@Body,'"items":{"data":{','"items":{"data":[')
DECLARE @MaxIncluded VARCHAR(2000),@MaxRep VARCHAR(2000)
SELECT @MaxIncluded=REPLACE(js.JsonText,'''','"')
FROM JSONText js
WHERE js.TransferID=@TransferID AND js.JsonSQL='pointer'
AND js.RowID=(SELECT MAX(jss.RowID) FROM JSONText jss WHERE jss.TransferID=@TransferID AND jss.JsonSQL='pointer')
SELECT @MaxRep=@MaxIncluded+'}}'

PRINT @MaxRep
PRINT @MaxIncluded

SELECT @Body=REPLACE(@Body,@MaxRep,@MaxIncluded+'}]')


INSERT INTO @Replace
SELECT '',RemoveSegment FROM @RemoveSegmentList

WHILE EXISTS(SELECT * FROM @Replace)
BEGIN
	SELECT TOP 1 @From=ReplaceText FROM @Replace
	SELECT @Body=REPLACE(@Body,('"'+@From+'":'),'')
	DELETE @Replace WHERE ReplaceText=@From
END

--Fix Array
SELECT @Body=REPLACE(@Body,'"included":{','"included":[')
SELECT @Body=LEFT(@Body,(LEN(@Body)-2))+']}'
-----
PRINT @Body

SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SET @SuccessFlg=0
END CATCH
END
GO
