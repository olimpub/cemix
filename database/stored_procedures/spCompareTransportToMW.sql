/****** Object:  StoredProcedure [dbo].[spCompareTransportToMW]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCompareTransportToMW](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
AS
BEGIN
DECLARE @Msg NVARCHAR(MAX)

BEGIN TRY
	--Load to table variable
	DECLARE @tblShipment TABLE(
	[CompareStatus] [varchar](100) NULL,
	[TransportID] [varchar](100) NOT NULL,
	[Priority] [varchar](50) NOT NULL,
	[CarrierID] [varchar](50) NULL, --Needs for included
	[ShipmentRule] [varchar] (50) NULL,  --Needs for included
	[SelfOrganized] [bit] NULL,
	[PickupDate] [varchar] (20) NULL,
	[SiteCode] [varchar] (10) NULL,
	[OrganizerID] [varchar] (50) NULL
) 




	INSERT INTO @tblShipment
	(
		[TransportID],
		[Priority],
		[CarrierID], 
		[ShipmentRule],  
		[SelfOrganized],
		[PickupDate],
		[SiteCode],
		[OrganizerID]
	)
	SELECT 
		ttd.TransportNo,
		[dbo].[fnGetServiceLevel](ttd.[Priority]),
		[dbo].[fnGetCarrierCode](ttd.CarrierCode,ttd.PlantCode),
		[dbo].[fnGetShipmentRule](ttd.TruckType),
		[dbo].[fnGetShipmentOrganizer](ttd.ShipmentType),
		[dbo].[fnGetLatestPickupDate](@TransferID),
		ttd.PlantCode,
		CASE WHEN [dbo].[fnGetShipmentOrganizer](ttd.ShipmentType)=0 THEN [dbo].[fnGetCarrierCode](ttd.OrganizerCode,ttd.PlantCode) ELSE NULL END
	FROM [dbo].[tblTransferTransport] ttd 
	WHERE ttd.TransferID=@TransferID

	DECLARE @tblCargo TABLE(
		[CompareStatus] [varchar](100)  NULL,
		[DeliveryNo] [varchar](100) NOT NULL,
		[Weight] [numeric](9,2) NOT NULL,
		[Colli] [smallint] NOT NULL,
		[Comment] [nvarchar](500) NULL,
		[DeliveryDate] [varchar](20),
		[PickupDate] [varchar](20),
		[SourcePartnerID] [varchar](50),
		[DestinationPartnerID] [varchar](50),
		[ContactInfo] [nvarchar](300) NULL,
		[Direction] [bit] NULL
		)
	INSERT INTO @tblCargo(
		[DeliveryNo],
		[Weight],
		[Colli],
		[Comment],
		[DeliveryDate],
		[PickupDate],
		[SourcePartnerID],
		[DestinationPartnerID],
		[ContactInfo],
		[Direction]
	)
	SELECT
		ttd.DeliveryNo,
		ttd.Weight,
		0, --Caluclate later on
		ttd.Comment,
		[dbo].[fnConvertToDate](ttd.DeliveryDate),
		[dbo].[fnConvertToDatetime](ttd.PickupDate),
		CASE ttd.Direction WHEN 1 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.AddressCode) END,
		CASE ttd.Direction WHEN 0 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.AddressCode) END,
		ttd.ContactInfo,
		ttd.Direction
	FROM tblTransferTransportDelivery ttd 
	INNER JOIN tblTransferTransport tt ON tt.TransferID=ttd.TransferID
	WHERE ttd.TransferID=@TransferID


	DECLARE @tblCargoItem TABLE(
		[CompareStatus] [varchar](100) NULL,
		[DeliveryNo] [varchar](100) NOT NULL,
		[ItemNo] [varchar](10) NOT NULL,
		[ItemCode] [nvarchar](50) NOT NULL,
		[ItemName] [nvarchar](300) NOT NULL,
		[OrderNo] [varchar](100) NOT NULL,
		[Qty] [numeric](9,2) NOT NULL,
		[QtyUnit] [varchar](10) NOT NULL,
		[QtyUnitID] [varchar](50) NOT NULL,
		[PalletQty] [numeric](9,2) NULL,
		[PickingFlg] [bit] NULL,
		[Comment] [nvarchar](500)  NULL
	)

	INSERT INTO @tblCargoItem
	(
		[DeliveryNo],
		[ItemNo],
		[ItemCode],
		[ItemName],
		[OrderNo],
		[Qty],
		[QtyUnit],
		[QtyUnitID],
		[PalletQty],
		[PickingFlg],
		[Comment]

	)
	SELECT 
		tdi.DeliveryNo,
		tdi.ItemNo,
		tdi.ItemCode,
		tdi.ItemName,
		tdi.OrderNo,
		tdi.Qty,
		tdi.QtyUnit,
		[dbo].[fnGetQtyUnit](tdi.QtyUnit),
		ISNULL(PalletQty,0),
		CASE WHEN (ROUND(ISNULL(PalletQty,1),0) = ISNULL(PalletQty,1)) THEN 0 ELSE 1 END,
		ISNULL(tdi.Comment,'')
	FROM tblTransferTransportDeliveryItem tdi
	WHERE tdi.TransferID=@TransferID
	AND [dbo].[fnGetValidTaxCode](tdi.TaxCode)=1
	AND tdi.Qty>0


	--Update Collidata
	UPDATE t
	SET t.Colli=ISNULL((SELECT SUM(it.PalletQty) FROM @tblCargoItem it WHERE it.DeliveryNo=t.DeliveryNo),0)
	FROM @tblCargo t


SELECT * FROM tblShipment

	--Compare
	IF EXISTS(SELECT ts.TransportID FROm tblShipment ts INNER JOIN @tblShipment tts ON tts.TransportID=ts.TransportID               )
	BEGIN
		UPDATE ts
		SET ts.CompareStatus='Changed Shipment'
		FROM @tblShipment ts INNER JOIN tblShipment tts ON tts.TransportID=ts.TransportID
		AND (tts.Priority<>ts.Priority OR tts.PickupDate<>ts.PickupDate OR tts.ShipmentRule<>ts.ShipmentRule OR tts.CarrierID<>ts.CarrierID OR tts.OrganizerID<>ts.OrganizerID)

		UPDATE ts
		SET ts.CompareStatus='Same Shimpment'
		FROM @tblShipment ts INNER JOIN tblShipment tts ON tts.TransportID=ts.TransportID
		AND (tts.Priority=ts.Priority AND tts.PickupDate=ts.PickupDate AND tts.ShipmentRule=ts.ShipmentRule AND tts.CarrierID=ts.CarrierID AND tts.OrganizerID=ts.OrganizerID)
	END
	ELSE
	BEGIN
		UPDATE tts
		SET tts.CompareStatus='New Shipment'
		FROM @tblShipment tts
	END

	--Update Cargos
	UPDATE tc
	SET tc.CompareStatus='Changed Cargo'
	FROM @tblCargo tc INNER JOIN tblCargo tcc ON tcc.DeliveryNo=tc.DeliveryNo
	AND (tc.Comment<>tcc.Comment OR tc.ContactInfo<>tcc.ContactInfo OR tc.PickupDate<>tcc.PickupDate OR tc.Colli<>tcc.Colli OR tc.DeliveryDate<>tcc.DeliveryDate)

		UPDATE tc
	SET tc.CompareStatus='Same Cargo'
	FROM @tblCargo tc INNER JOIN tblCargo tcc ON tcc.DeliveryNo=tc.DeliveryNo
	AND (tc.Comment=tcc.Comment AND tc.ContactInfo=tcc.ContactInfo AND tc.PickupDate=tcc.PickupDate AND tc.Colli=tcc.Colli OR tc.DeliveryDate=tcc.DeliveryDate)

	--Insert Cargo
	DECLARE @TransportID VARCHAR(50)
	SELECT @TransportID=ts.TransportID FROM @tblShipment ts

	UPDATE tcc
	SET tcc.CompareStatus='New Cargo'
	FROM @tblCargo tcc 
	WHERE NOT EXISTS(SELECT * FROM tblCargo tc WHERE tc.DeliveryNo=tcc.DeliveryNo AND tc.TransportID=@TransportID)



	--Items
	UPDATE tci
	SET tci.CompareStatus='Changed Row'
	FROM @tblCargoItem tci INNER JOIN tblCargoItem tcci ON tcci.DeliveryNo=tci.DeliveryNo AND tcci.ItemNo=tci.ItemNo
	AND (tci.Qty<>tcci.Qty OR tci.PalletQty<>tcci.PalletQty OR tci.QtyUnitID<>tcci.QtyUnitID OR tci.PickingFlg<>tcci.PickingFlg)

	UPDATE tci
	SET tci.CompareStatus='Same Row'
	FROM @tblCargoItem tci INNER JOIN tblCargoItem tcci ON tcci.DeliveryNo=tci.DeliveryNo AND tcci.ItemNo=tci.ItemNo
	AND (tci.Qty=tcci.Qty AND tci.PalletQty=tcci.PalletQty AND tci.QtyUnitID=tcci.QtyUnitID AND tci.PickingFlg=tcci.PickingFlg)

	UPDATE tci
	SET tci.CompareStatus='New Row'
	FROM @tblCargoItem tci 
	WHERE NOT EXISTS(
	SELECT * FROM tblCargoItem tcci WHERE tcci.DeliveryNo=tci.DeliveryNo AND tcci.ItemNo=tci.ItemNo
	)
	/*
	SELECT * FROM @tblShipment
	SELECT * FROM @tblCargo
	SELECT * FROM @tblCargoItem
	*/
	

	UPDATE tc
	SET tc.Status=-1
	FROM tblCargo tc 
	WHERE tc.TransportID=@TransportID 
	AND NOT EXISTS(SELECT * FROM @tblCargo tcc WHERE tcc.DeliveryNo=tc.DeliveryNo)

	UPDATE tci
	SET tci.Status=-1
	FROM tblCargoItem tci 
	WHERE tci.DeliveryNo IN(SELECT tc.DeliveryNo FROM @tblCargo tc )
	AND NOT EXISTS(SELECT * FROM @tblCargoItem tcci WHERE tcci.DeliveryNo=tci.DeliveryNo AND tcci.ItemNo=tci.ItemNo)

	SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SELECT  
    ERROR_NUMBER() AS ErrorNumber  
    ,ERROR_SEVERITY() AS ErrorSeverity  
    ,ERROR_STATE() AS ErrorState  
    ,ERROR_PROCEDURE() AS ErrorProcedure  
    ,ERROR_LINE() AS ErrorLine  
    ,ERROR_MESSAGE() AS ErrorMessage;  
	SET @SuccessFlg=0
END CATCH

END
GO
