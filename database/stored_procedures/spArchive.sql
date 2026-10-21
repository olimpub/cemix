/****** Object:  StoredProcedure [dbo].[spArchive]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spArchive](
	@SuccessFlg BIT OUT
)
/*
Version 1.01

1.01	:		Changed by Daniel Bakos, add SAPTemplateID on 2023/02/19
*/
AS
BEGIN
DECLARE @Msg NVARCHAR(MAX)	
BEGIN TRY 
	BEGIN TRANSACTION

	INSERT INTO [dbo].[tblTransportArchive]
			   ([id]
			   ,[TransportNo]
			   ,[GLABsID]
			   ,[CarrierID]
			   ,[SelfOrganized]
			   ,[SiteCode]
			   ,[LicensePlate1]
			   ,[LicensePlate2]
			   ,[DelegateFlg]
			   ,[DriverPhone]
			   ,[OrganizerID]
			   ,[MergeTransportNo]
			   ,[Status])
	SELECT 
				[id]
			   ,[TransportNo]
			   ,[GLABsID]
			   ,[CarrierID]
			   ,[SelfOrganized]
			   ,[SiteCode]
			   ,[LicensePlate1]
			   ,[LicensePlate2]
			   ,[DelegateFlg]
			   ,[DriverPhone]
			   ,[OrganizerID]
			   ,[MergeTransportNo]
			   ,[Status]
	FROM tblTransport tra WHERE  tra.Status=3

	DELETE FROM tblTransport WHERE Status=3

	INSERT INTO [dbo].[tblShipmentArchive]
           ([id]
           ,[TransportID]
           ,[Priority]
           ,[ShipmentRule]
           ,[PickupDate]
           ,[StationID]
           ,[Status]
           ,[SiteCode]
           ,[ShipmentStatus]
           ,[SAPStatus]
           ,[BookingDate]
           ,[DelegateFlg]
           ,[AutoEntryFlg]
           ,[AutoCheckOutFlg]
           ,[CallID]
           ,[OrderID]
           ,[RampID]
           ,[CallStatus]
		   ,[CheckOutBlock]
           ,[CheckOutAllow]
		   ,[SAPTemplateID]) --v1.01
	SELECT
			[id]
           ,[TransportID]
           ,[Priority]
           ,[ShipmentRule]
           ,[PickupDate]
           ,[StationID]
           ,[Status]
           ,[SiteCode]
           ,[ShipmentStatus]
           ,[SAPStatus]
           ,[BookingDate]
           ,[DelegateFlg]
           ,[AutoEntryFlg]
           ,[AutoCheckOutFlg]
           ,[CallID]
           ,[OrderID]
           ,[RampID]
           ,[CallStatus]
		   ,[CheckOutBlock]
           ,[CheckOutAllow]
		   ,[SAPTemplateID] --v1.01
	FROM tblShipment WHERE [Status]=3
	
	DELETE tblShipment WHERE [Status]=3

	INSERT INTO [dbo].[tblCargoArchive]
           ([id]
           ,[TransportID]
           ,[DeliveryNo]
           ,[Weight]
           ,[Colli]
           ,[Comment]
           ,[DeliveryDate]
           ,[PickupDate]
           ,[SourcePartnerID]
           ,[DestinationPartnerID]
           ,[ContactInfo]
           ,[GLABsID]
           ,[Status]
           ,[Direction]
           ,[CargoOperationsID]
           ,[StageNo]
           ,[ArrivalDate]
           ,[ContactPhone]
           ,[QtyMismatchFlg]
           ,[SourceSiteCode]
           ,[DestinationSiteCode]
		   ,[BorderCrossingID]
		   )
	SELECT
			[id]
           ,[TransportID]
           ,[DeliveryNo]
           ,[Weight]
           ,[Colli]
           ,[Comment]
           ,[DeliveryDate]
           ,[PickupDate]
           ,[SourcePartnerID]
           ,[DestinationPartnerID]
           ,[ContactInfo]
           ,[GLABsID]
           ,[Status]
           ,[Direction]
           ,[CargoOperationsID]
           ,[StageNo]
           ,[ArrivalDate]
           ,[ContactPhone]
           ,[QtyMismatchFlg]
           ,[SourceSiteCode]
           ,[DestinationSiteCode]
		   ,[BorderCrossingID]
	FROM tblCargo WHERE [Status]=3

	DELETE FROM tblCargo WHERE [Status]=3
	
	INSERT INTO [dbo].[tblCargoItemArchive]
           ([id]
           ,[DeliveryNo]
           ,[ItemNo]
           ,[ItemCode]
           ,[ItemName]
           ,[OrderNo]
           ,[Qty]
           ,[QtyUnit]
           ,[QtyUnitID]
           ,[PalletQty]
           ,[PickingFlg]
           ,[Comment]
           ,[SourceGLABsID]
           ,[SourceStatus]
           ,[IncludedText]
           ,[StockQty]
           ,[TransportID]
           ,[DestinationGLABsID]
           ,[DestinationStatus]
		   ,[NetWeight]
		   ,[GrossWeight]
		   ,[BatchFlg])
		SELECT
			[id]
           ,[DeliveryNo]
           ,[ItemNo]
           ,[ItemCode]
           ,[ItemName]
           ,[OrderNo]
           ,[Qty]
           ,[QtyUnit]
           ,[QtyUnitID]
           ,[PalletQty]
           ,[PickingFlg]
           ,[Comment]
           ,[SourceGLABsID]
           ,[SourceStatus]
           ,[IncludedText]
           ,[StockQty]
           ,[TransportID]
           ,[DestinationGLABsID]
           ,[DestinationStatus]
		   ,[NetWeight]
		   ,[GrossWeight]
		   ,[BatchFlg]
	FROM tblCargoItem ci WHERE (ci.[SourceStatus]=3 OR ci.DestinationStatus=3)

	DELETE ci FROM tblCargoItem ci WHERE ci.[SourceStatus]=3 OR ci.DestinationStatus=3

	COMMIT TRANSACTION

	SET @SuccessFlg=1
	SET @Msg='OK'

	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spArchive','','',@Msg,@SuccessFlg	

END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION

	SET @SuccessFlg=0
	SET @Msg=ERROR_MESSAGE()

	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg)
	SELECT 'spArchive','','',@Msg,@SuccessFlg	
END CATCH
END
GO
