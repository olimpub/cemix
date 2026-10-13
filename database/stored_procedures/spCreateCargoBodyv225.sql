/****** Object:  StoredProcedure [dbo].[spCreateCargoBodyv225]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCreateCargoBodyv225](
	@TransferID INT,
	@CargoID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

DECLARE @TransportExists BIT, @TransportID VARCHAR(100), @DeliveryNo VARCHAR(100),@Colli SMALLINT, @Comment NVARCHAR(500),@Direction BIT,  @SourcePriority VARCHAR(50), @DestinationPriority VARCHAR(50),@DirectionText VARCHAR(10),
@SourcePickupDate DATETIME,@DestinationPickupDate DATETIME, @UnixSourcePickupDate INT,@UnixDestinationPickupDate INT,
@SourcePartnerID VARCHAR(50), @DestinationPartnerID VARCHAR(50), @NoOfItems SMALLINT, @ShipmentID VARCHAR(50), @SourceStationID VARCHAR(50), @DestinationStationID VARCHAR(50),@SourceSiteID VARCHAR(15), @DestinationSiteID VARCHAR(15),
@IncludedText VARCHAR(100),@SourceShipmentRule VARCHAR(50), @DestinationShipmentRule VARCHAR(50),@CarrierID VARCHAR(50),@SourceCargoOperationsID VARCHAR(50), @DestinationCargoOperationsID VARCHAR(50), @Cntr SMALLINT,@Weight NUMERIC(9,3), @CargoGLABsID VARCHAR(50),
@ReferenceNo VARCHAR(100), @ContactName NVARCHAR(200),@ContactPhone VARCHAR(50), @ContactPhoneCountry VARCHAR(3),
@ContactPhoneNumber VARCHAR(20), @LicensePlate1 VARCHAR(50), @LicensePlate2 VARCHAR(50), @TransportNo2 VARCHAR(100),@IncludedCtr SMALLINT, @SourceGroupingFlg BIT, @DestinationGroupingFlg BIT


DECLARE @References TABLE(
	ReferenceNo VARCHAR(50)	
)



DECLARE @IncludedTbl TABLE(
	RowID INT IDENTITY(1,1),
	IncludedType VARCHAR(100)
)


SELECT @CargoGLABsID =  tc.GLABsID , @TransportID =tc.TransportID, @DeliveryNo=tc.DeliveryNo, @Colli = tc.Colli, @Comment=tc.Comment, @Direction=tc.Direction, @SourcePartnerID=tc.SourcePartnerID, @DestinationPartnerID= tc.DestinationPartnerID, 
@SourceSiteID=tc.SourceSiteCode, @DestinationSiteID=tc.DestinationSiteCode,@ContactName=ISNULL(tc.ContactInfo,''), @ContactPhone=[dbo].[FnRemoveNonNumCharacters](tc.ContactPhone), @Weight=(tc.Weight/1000),
@SourceCargoOperationsID = tc.SourceOperationsID, @DestinationCargoOperationsID =tc.DestinationOperationsID
FROM tblCargo tc WHERE id=@CargoID

SELECT @NoOfItems = COUNT(*) FROM tblCargoItem WHERE DeliveryNo=@DeliveryNo

SELECT @ShipmentID=tss.GLABsID,@CarrierID=tss.CarrierID , @LicensePlate1=tss.LicensePlate1, @LicensePlate2 = tss. LicensePlate2, @TransportNo2=tss.MergeTransportNo FROM tblShipment ts
INNER JOIN tblTransport tss ON tss.TransportNo=ts.TransportID
WHERE tss.TransportNo=@TransportID

IF(ISNULL(@SourceSiteID,'')<>'')
BEGIN
	SELECT @SourceShipmentRule = ts.ShipmentRule, @SourcePriority = ts.Priority, @SourcePickupDate = ts.PickupDate, @SourceStationID= ts.StationID FROm tblShipment ts WHERE ts.TransportID=@TransportID AND ts.SiteCode=@SourceSiteID
END

IF(ISNULL(@DestinationSiteID,'')<>'')
BEGIN
	SELECT @DestinationShipmentRule = ts.ShipmentRule, @DestinationPriority = ts.Priority, @DestinationPickupDate =   ts.PickupDate, @DestinationStationID= ts.StationID FROm tblShipment ts WHERE ts.TransportID=@TransportID AND ts.SiteCode=@DestinationSiteID
END


--NEED TO MANAGE!!!!

IF(@TransportNo2 IS NOT NULL)
BEGIN
	SELECT @ShipmentID=tss.GLABsID,@CarrierID=tss.CarrierID , @LicensePlate1=tss.LicensePlate1, @LicensePlate2 = tss. LicensePlate2 FROM tblShipment ts
	INNER JOIN tblTransport tss ON tss.TransportNo=ts.TransportID
	WHERE tss.TransportNo=@TransportNo2

	IF EXISTS(SELECT * FROm tblShipment ts WHERE ts.SiteCode=@SourceSiteID AND ts.TransportID=@TransportNo2)
	BEGIN
		SELECT @SourceShipmentRule = ts.ShipmentRule, @SourcePriority = ts.Priority, @SourcePickupDate = ts.PickupDate, @SourceStationID= ts.StationID 
		FROm tblShipment ts WHERE ts.TransportID=@TransportNo2 AND ts.SiteCode=@SourceSiteID
	END

	IF EXISTS(SELECT * FROm tblShipment ts WHERE ts.SiteCode=@DestinationSiteID AND ts.TransportID=@TransportNo2)
	BEGIN
		SELECT @DestinationShipmentRule = ts.ShipmentRule, @DestinationPriority = ts.Priority, @DestinationPickupDate =   ts.PickupDate, @DestinationStationID= ts.StationID FROm tblShipment ts WHERE ts.TransportID=@TransportNo2 AND ts.SiteCode=@DestinationSiteID
	END	
END

IF(ISNULL(@SourcePickupDate,'')<>'' )
BEGIN
	SELECT @UnixSourcePickupDate=[dbo].[spGetUnixTimestamp](@SourcePickupDate)
END
IF(ISNULL(@DestinationPickupDate,'')<>'' )
BEGIN
	SELECT @UnixDestinationPickupDate=[dbo].[spGetUnixTimestamp](@DestinationPickupDate)
END


INSERT INTO @References
SELECT DISTINCT ci.OrderNo FROM tblCargoItem ci WHERE ci.DeliveryNo=@DeliveryNo

IF((SELECT COUNT(*) FROM @References)=0)
BEGIN
	SELECT @ReferenceNo='-'
END
ELSE IF((SELECT COUNT(*) FROM @References)=1)
BEGIN
	SELECT @ReferenceNo = rf.ReferenceNo FROM @References rf
END
ELSE
BEGIN
	SELECT @ReferenceNo='MULTIPLE'
END

IF (LEN(@ContactPhone)<3)
BEGIN
	SET @ContactPhone=NULL
END
ELSE
BEGIN
	IF(LEFT(@ContactPhone,2)='06')
	BEGIN
		SET @ContactPhoneCountry='+36'
	END
	ELSE
	BEGIN
		SET @ContactPhoneCountry= '+'+LEFT(@ContactPhone,2)
	END

	SELECT @ContactPhoneNumber=RIGHT(@ContactPhone,(LEN(@ContactPhone)-2))

END
/*
IF(@Direction=1)
BEGIN
	SET @DirectionText='out'
END
ELSE
BEGIN
	SET @DirectionText='in'
END
*/
--SELECT @ShipmentID, @Direction,@NoOfItems,@DeliveryNo

DELETE FROM JSONText WHERE TransferID=@TransferID

INSERT INTO JSONText
SELECT @TransferID,'data.type','''shipmentCargos''',''

IF(@CargoGLABsID IS NOT NULL)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.id',''''+@CargoGLABsID+'''','' 
END

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.number',''''+@DeliveryNo+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.colli',''''+CAST(@Colli AS varchar(10))+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.comment',''''+@Comment+'''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.ekaerCode','''''','' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.totalWeight',CAST(@Weight AS varchar(20)),'' 

INSERT INTO JSONText
SELECT @TransferID,'data.attributes.referenceNumber',''''+@ReferenceNo+'''','' 

IF(ISNULL(@ContactName,'')<>'')
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.contactName',''''+@ContactName+'''',''
END

IF(ISNULL(@ContactPhone,'')<>'')
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.contactPhone.countryCode',''''+@ContactPhoneCountry+'''',''

	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.contactPhone.number',''''+@ContactPhoneNumber+'''',''
END


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
	IF(ISNULL(@SourceSiteID,'')<>'' AND ISNULL(@DestinationSiteID,'')='')
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationPartnerOrigin.data.type','''partners''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationPartnerOrigin.data.id',''''+@DestinationPartnerID+'''','' 
	END
	
	IF(ISNULL(@SourceSiteID,'')='' AND ISNULL(@DestinationSiteID,'')<>'')
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourcePartnerOrigin.data.type','''partners''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourcePartnerOrigin.data.id',''''+@SourcePartnerID+'''','' 
	END

	IF(ISNULL(@DestinationSiteID,'')<>'' AND ISNULL(@SourceSiteID,'')<>'')
	BEGIN
		IF(ISNULL(@SourceStationID,'')='')
		BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.sourcePartnerOrigin.data.type','''partners''','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.sourcePartnerOrigin.data.id',''''+@SourcePartnerID+'''','' 
		END

		IF(ISNULL(@DestinationStationID,'')='')
		BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.destinationPartnerOrigin.data.type','''partners''','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.destinationPartnerOrigin.data.id',''''+@DestinationPartnerID+'''','' 
		END
	END

END

--Station
IF(ISNULL(@SourceSiteID,'')<>'')
BEGIN
	IF(@SourceStationID IS NULL)
	BEGIN
		INSERT INTO @IncludedTbl(IncludedType)
		SELECT 'sourceStation'

		SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='sourceStation'



		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceStation.data.pointer','''/included/'+CAST(@IncludedCtr AS VARCHAR(2))+'''','' 
	END
	ELSE
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceStation.data.type','''shipmentStations''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceStation.data.id',''''+@SourceStationID+'''','' 
	END
END

IF(ISNULL(@DestinationSiteID,'')<>'')
BEGIN
	IF(@DestinationStationID IS NULL)
	BEGIN
		INSERT INTO @IncludedTbl(IncludedType)
		SELECT 'destinationStation'

		SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='destinationStation'


		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationStation.data.pointer','''/included/'+CAST(@IncludedCtr AS VARCHAR(2))+'''','' 
	END
	ELSE
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationStation.data.type','''shipmentStations''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationStation.data.id',''''+@DestinationStationID+'''','' 
	END
END



/*
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

*/

--Shipment
IF(@ShipmentID IS NULL)
BEGIN
		INSERT INTO @IncludedTbl(IncludedType)
		SELECT 'shipment'

		SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='shipment'

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.shipment.data.pointer','''/included/'+CAST(@IncludedCtr AS VARCHAR(2))+'''','' 
END
ELSE
BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.shipment.data.type','''shipments''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.shipment.data.id',''''+@ShipmentID+'''','' 
END


--CargoOperations
IF(ISNULL(@SourceSiteID,'')<>'')
BEGIN
	IF(ISNULL(@SourceCargoOperationsID,'') ='')-- AND ISNULL(@UnixSourcePickupDate,0)<>0)
	BEGIN
			IF(ISNULL(@UnixSourcePickupDate,0)<>0)
			BEGIN
			INSERT INTO @IncludedTbl(IncludedType)
			SELECT 'sourceOperation'

			SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='sourceOperation'

			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.sourceOperation.data.pointer','''/included/'+CAST(@IncludedCtr AS VARCHAR(2))+'''','' 
		END
	END
	ELSE
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceOperation.data.type','''cargoOperations''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceOperation.data.id',''''+@SourceCargoOperationsID+'''','' 
	END
END

IF(ISNULL(@DestinationSiteID,'')<>'')
BEGIN
	IF(ISNULL(@DestinationCargoOperationsID,'') ='' )
	BEGIN
		IF(ISNULL(@UnixDestinationPickupDate,0)<>0)
		BEGIN
			INSERT INTO @IncludedTbl(IncludedType)
			SELECT 'destinationOperation'

			SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='destinationOperation'

			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.destinationOperation.data.pointer','''/included/'+CAST(@IncludedCtr AS VARCHAR(2))+'''',''
		END
	END
	ELSE
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationOperation.data.type','''cargoOperations''',''  

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationOperation.data.id',''''+@DestinationCargoOperationsID+'''','' 
	END
END

/*
IF(@CargoOperationsID IS NULL)
BEGIN
	IF(@Direction=1)
	BEGIN
		IF(@ShipmentID IS NULL)
		BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.sourceOperation.data.pointer','''/included/2''','' 
		END
		ELSE
		BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.sourceOperation.data.pointer','''/included/0''','' 
		END
	END
	ELSE
	BEGIN
		IF(@ShipmentID IS NULL)
		BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.destinationOperation.data.pointer','''/included/2''',''
		END
		ELSE
		BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.destinationOperation.data.pointer','''/included/0''',''
		END
	END
END
ELSE
BEGIN
	IF(@Direction=1)
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceOperation.data.type','''cargoOperations''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.sourceOperation.data.id',''''+@CargoOperationsID+'''','' 
	END
	ELSE
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationOperation.data.type','''cargoOperations''',''  

		INSERT INTO JSONText
		SELECT @TransferID,'data.relationships.destinationOperation.data.id',''''+@CargoOperationsID+'''','' 
	END
END
*/
--Items
/*
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
*/
DECLARE @MaxID INT
SELECT @MaxID=MAX(RowID)+1 FROM JSONText js
WHERE js.TransferID=@TransferID

DECLARE @RemoveSegmentList TABLE(
	RemoveSegment VARCHAR(500)
)



--INCLUDED PART
IF EXISTS(SELECT * FROM @IncludedTbl WHERE IncludedType='sourceStation')
BEGIN
	SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='sourceStation'

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.type','''shipmentStations''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.attributes.specials.cargoGrouping','CAST(1 AS BIT)','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.relationships.shipmentRuleOrigin.data.type','''shipmentRules''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.relationships.shipmentRuleOrigin.data.id',''''+@SourceShipmentRule+'''','' 

	IF(ISNULL(@SourcePriority,'')<>'')
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.relationships.priority.data.type','''priorities''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.relationships.priority.data.id',''''+@SourcePriority+'''','' 
	END	
	INSERT INTO @RemoveSegmentList
	SELECT 'included'+CAST(@IncludedCtr AS VARCHAR(2))
END


IF EXISTS(SELECT * FROM @IncludedTbl WHERE IncludedType='destinationStation')
BEGIN
	SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='destinationStation'

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.type','''shipmentStations''','' 
	/*
	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.attributes.specials.cargoGrouping','CAST(1 AS BIT)','' 
	*/
	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.relationships.shipmentRuleOrigin.data.type','''shipmentRules''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.relationships.shipmentRuleOrigin.data.id',''''+@DestinationShipmentRule+'''','' 

	IF(ISNULL(@DestinationPriority,'')<>'' AND (ISNULL(@SourceSiteID,'')=''))
	BEGIN
		INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.relationships.priority.data.type','''priorities''','' 

		INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.relationships.priority.data.id',''''+@DestinationPriority+'''','' 
	END	
	INSERT INTO @RemoveSegmentList
	SELECT 'included'+CAST(@IncludedCtr AS VARCHAR(2))
END


IF EXISTS(SELECT * FROM @IncludedTbl WHERE IncludedType='shipment')
BEGIN
	SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='shipment'

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.type','''shipments''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.attributes.transportId',''''+[dbo].[fnCutLeadZeros](@TransportID)+'''','' 

	IF(@LicensePlate1 IS NOT NULL)
	BEGIN
		INSERT INTO JSONText
			SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.attributes.vehicleIds.plate1',''''+@LicensePlate1+'@pl1'+'''','' 
	END

	IF(@LicensePlate2 IS NOT NULL)
	BEGIN
		INSERT INTO JSONText
			SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.attributes.vehicleIds.plate2',''''+@LicensePlate2+'@pl2'+'''','' 
	END


	INSERT INTO @RemoveSegmentList
	SELECT 'included'+CAST(@IncludedCtr AS VARCHAR(2))
END



IF EXISTS(SELECT * FROM @IncludedTbl WHERE IncludedType='sourceOperation')
BEGIN
	SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='sourceOperation'

	INSERT INTO JSONText
	SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.type','''cargoOperations''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.attributes.readyForLoading',+CAST(@UnixSourcePickupDate AS VARCHAR(20)),'' 


	INSERT INTO @RemoveSegmentList
	SELECT 'included'+CAST(@IncludedCtr AS VARCHAR(2))
END

IF EXISTS(SELECT * FROM @IncludedTbl WHERE IncludedType='destinationOperation')
BEGIN
	SELECT @IncludedCtr=(RowID-1) FROM @IncludedTbl WHERE IncludedType='destinationOperation'

	INSERT INTO JSONText
	SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.type','''cargoOperations''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'included.included'+CAST(@IncludedCtr AS VARCHAR(2))+'.attributes.readyForLoading',+CAST(@UnixDestinationPickupDate AS VARCHAR(20)),'' 


	INSERT INTO @RemoveSegmentList
	SELECT 'included'+CAST(@IncludedCtr AS VARCHAR(2))
END
/*
IF(@CargoOperationsID IS NULL)
BEGIN
	INSERT INTO JSONText
		SELECT @TransferID,'included.included2.type','''cargoOperations''','' 
	/*
	INSERT INTO JSONText
		SELECT @TransferID,'included.included2.attributes.direction',''''+@DirectionText+'''','' 
	*/
	INSERT INTO JSONText
		SELECT @TransferID,'included.included2.attributes.readyForLoading',+CAST(@UnixPickupDate AS VARCHAR(20)),'' 


	INSERT INTO @RemoveSegmentList
	SELECT 'included2'
END
  */
/*
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
*/


UPDATE js
SET js.JsonField=REPLACE(JsonField,'@',CAST(js.RowID AS varchar(10)))
FROM JSONText js
WHERE js.TransferID=@TransferID
--ADD

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

--Fix Plate
SELECT @Body=REPLACE(@Body,'"plate1":','')
SELECT @Body=REPLACE(@Body,'"plate2":','')
SELECT @Body=REPLACE(@Body,'@pl1",','",')
SELECT @Body=REPLACE(@Body,'@pl1"}','"]')
SELECT @Body=REPLACE(@Body,'@pl2",','",')
SELECT @Body=REPLACE(@Body,'@pl2"}','"]')
SELECT @Body=REPLACE(@Body,'"vehicleIds":{','"vehicleIds":[')
--Fix Array
SELECT @Body=REPLACE(@Body,'"included":{','"included":[')
IF(@Cntr>0)
BEGIN
	SELECT @Body=LEFT(@Body,(LEN(@Body)-2))+']}'
END
PRINT 'Final'
PRINT '----------------------'
PRINT @Body
/*



SELECT @Body=REPLACE(@Body,'"items":{"data":{','"items":{"data":[')
DECLARE @MaxIncluded VARCHAR(2000),@MaxRep VARCHAR(2000)
SELECT @MaxIncluded=REPLACE(js.JsonText,'''','"')
FROM JSONText js
WHERE js.TransferID=@TransferID AND js.JsonSQL='pointer'
AND js.RowID=(SELECT MAX(jss.RowID) FROM JSONText jss WHERE jss.TransferID=@TransferID AND jss.JsonSQL='pointer')
SELECT @MaxRep=@MaxIncluded+'}}'

SELECT  @MaxRep
SELECT @MaxIncluded

SELECT @Body=REPLACE(@Body,@MaxRep,@MaxIncluded+'}]')

*/


-----


SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SET @SuccessFlg=0
END CATCH
END
GO
