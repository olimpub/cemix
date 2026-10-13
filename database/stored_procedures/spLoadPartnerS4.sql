/****** Object:  StoredProcedure [dbo].[spLoadPartnerS4]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE  PROCEDURE [dbo].[spLoadPartnerS4](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
AS
BEGIN

DECLARE @Msg NVARCHAR(MAX), @SiteCode VARCHAR(20),@SelfOrganized BIT, @TransportNo VARCHAR(30)

BEGIN TRY

SELECT @SiteCode=ttt.PlantCode, @SelfOrganized=	[dbo].[fnGetShipmentOrganizer](ttt.ShipmentType), @TransportNo=ttt.TransportNo FROM tblTransferTransport ttt WHERE TransferID=@TransferID

--Create temp table
DECLARE @Partner TABLE(
	[PartnerType] [smallint] NOT NULL,
	[PartnerCode] [varchar](50) NULL,
	[PartnerName] [nvarchar](300) NULL,
	[PartnerCountry] [varchar](3) NULL,
	[PartnerCity] [nvarchar](150) NULL,
	[PartnerAddress] [nvarchar](1000) NULL,
	[PartnerPhone] [varchar](100) NULL,
	[PartnerMail] [varchar](500) NULL,
	[PartnerZIP] [varchar](15) NULL,
	[PartnerTaxID] [varchar](30) NULL,
	[SiteCode] [varchar](15) NULL,
	[PlantCode] [varchar](50) NULL,
	[ProfileFlg] [bit] NULL,
	[GLABsID] [varchar](50) NULL,
	[ExistsOnDifferentPlantFlg] [bit] NULL
)


INSERT INTO @Partner(
	        [PartnerType]
           ,[PartnerCode]
           ,[PartnerName]
           ,[PartnerCountry]
           ,[PartnerCity]
           ,[PartnerAddress]
           ,[PartnerPhone]
           ,[PartnerMail]
		   ,[PartnerZIP]
		   ,[PartnerTaxID]
		   ,[SiteCode]
		   ,[PlantCode]
		   ,[ProfileFlg]
		   )
SELECT DISTINCT
			1,--Hardcoded BP
			ttd.PartnerCode,
			ttd.PartnerName,
			ttd.PartnerCountry,
			ttd.PartnerCity,
			ttd.PartnerAddress,
			(SELECT TOP 1 ttdd.PartnerPhone FROM [dbo].[tblTransferTransportDelivery] ttdd WHERE ttdd.TransferID=@TransferID AND ttdd.PartnerCode=ttd.PartnerCode AND ISNULL(ttdd.AddressCode,'')=ISNULL(ttd.AddressCode,'')),
			(SELECT TOP 1 ttdd.PartnerMail FROM [dbo].[tblTransferTransportDelivery] ttdd WHERE ttdd.TransferID=@TransferID AND ttdd.PartnerCode=ttd.PartnerCode AND ISNULL(ttdd.AddressCode,'')=ISNULL(ttd.AddressCode,'')),
			ttd.PartnerZIP,
			ttd.PartnerTaxID,
			ttd.SiteID,
			ttd.AddressCode, --PlantCode
			NULL --ProfileFlg
FROM [dbo].[tblTransferTransportDelivery] ttd 
WHERE ttd.TransferID=@TransferID
AND ttd.PartnerCode IS NOT NULL


--If not self organized, then OrganizerID
IF(@SelfOrganized=0)
BEGIN
	INSERT INTO @Partner(
				[PartnerType]
			   ,[PartnerCode]
			   ,[PartnerName]
			   ,[PartnerCountry]
			   ,[PartnerCity]
			   ,[PartnerAddress]
			   ,[PartnerPhone]
			   ,[PartnerMail]
			   ,[PartnerZIP]
			   ,[PartnerTaxID]
			   ,[SiteCode]
			   ,[PlantCode]
			   ,[ProfileFlg]
			   )
	SELECT 
				DISTINCT
				3,--Hardcoded Carrier
				tt.OrganizerCode,
				tt.OrganizerName,
				tt.OrganizerCountryCode,
				tt.OrganizerCity,
				tt.OrganizerAddress,
				tt.OrganizerPhone,
				tt.OrganizerMail,
				tt.OrganizerZIP,
				tt.OrganizerTaxID,
				tt.PlantCode,
				'', --PlantCode
				NULL --ProfileFlg
	FROM [dbo].[tblTransferTransport] tt 
	WHERE tt.TransferID=@TransferID
	AND tt.OrganizerCode IS NOT NULL
END

--Add carriers
INSERT INTO @Partner(
	        [PartnerType]
           ,[PartnerCode]
           ,[PartnerName]
           ,[PartnerCountry]
           ,[PartnerCity]
           ,[PartnerAddress]
           ,[PartnerPhone]
           ,[PartnerMail]
		   ,[PartnerZIP]
		   ,[PartnerTaxID]
		   ,[SiteCode]
		   ,[PlantCode]
		   ,[ProfileFlg]
		   )
SELECT 
			3,--Hardcoded Carrier
			tt.CarrierCode,
			tt.CarrierName,
			tt.CountryCode,
			tt.CarrierCity,
			tt.CarrierAddress,
			tt.CarrierPhone,
			tt.CarrierMail,
			tt.CarrierZIP,
			tt.CarrierTaxID,
			tt.PlantCode,
			'', --PlantCode
			NULL --ProfileFlg
FROM [dbo].[tblTransferTransport] tt 
WHERE tt.TransferID=@TransferID
AND NOT EXISTS(SELECT * FROM @Partner pp WHERE pp.PartnerCode=tt.CarrierCode AND pp.PartnerType=3)
AND tt.CarrierCode IS NOT NULL

--Update if exists
UPDATE p
SET p.GLABsID=ISNULL(tp.GLABsID,CAST(tp.id AS VARCHAR(20)))
FROM @Partner p
INNER JOIN tblPartner tp ON tp.PartnerCode=p.PartnerCode AND tp.SiteCode=p.SiteCode AND tp.PartnerType=p.PartnerType-- AND tp.PartnerCity=p.PartnerCity AND tp.PartnerName=p.PartnerName AND tp.PartnerAddress=p.PartnerAddress
WHERE p.PartnerCode NOT IN('LHU01','CLHU01') AND tp.Status=1

--------Compare with existing DB
UPDATE p
SET p.GLABsID=ISNULL(tp.GLABsID,CAST(tp.id AS VARCHAR(20)))
FROM @Partner p
INNER JOIN tblPartner tp ON tp.PartnerCode=p.PartnerCode AND tp.PartnerType=p.PartnerType AND tp.SiteCode=p.SiteCode
WHERE p.PartnerType=1 AND p.PlantCode IS NULL AND p.GLABsID IS NULL AND tp.Status=1

UPDATE p
SET p.GLABsID=ISNULL(tp.GLABsID,CAST(tp.id AS VARCHAR(20)))
FROM @Partner p
INNER JOIN tblPartner tp ON tp.PartnerCode=p.PartnerCode AND tp.PartnerType=p.PartnerType AND tp.SiteCode=p.SiteCode
WHERE p.PartnerType=3 AND p.PlantCode IS NULL AND p.GLABsID IS NULL AND tp.Status=1

--Still in Queue
DELETE p FROM @Partner p
INNER JOIN tblPartner tp ON tp.PartnerCode=p.PartnerCode AND tp.PartnerType=p.PartnerType AND tp.SiteCode=p.SiteCode
WHERE tp.Status=0


/*
UPDATE p
SET p.GLABsID=ISNULL(tp.GLABsID,CAST(tp.id AS VARCHAR(20))),p.ExistsOnDifferentTypeFlg=1
FROM @Partner p
INNER JOIN tblPartner tp ON tp.PartnerCode=p.PartnerCode AND tp.PartnerType<>p.PartnerType
WHERE p.PlantCode IS NULL
*/
/*
--With PlantCode
UPDATE p
SET p.GLABsID=ISNULL(tp.GLABsID,CAST(tp.id AS VARCHAR(20)))
FROM @Partner p
INNER JOIN tblPartner tp ON tp.PartnerCode=p.PartnerCode AND tp.PartnerType=p.PartnerType AND tp.PlantCode=p.PlantCode 
WHERE p.PartnerType=1 AND p.PlantCode IS NOT NULL AND p.GLABsID IS NULL

UPDATE p
SET p.GLABsID=ISNULL(tp.GLABsID,CAST(tp.id AS VARCHAR(20)))
FROM @Partner p
INNER JOIN tblPartner tp ON tp.PartnerCode=p.PartnerCode AND tp.PartnerType=p.PartnerType AND tp.PlantCode=p.PlantCode
WHERE p.PartnerType=3 AND p.PlantCode IS NOT NULL AND p.GLABsID IS NULL

UPDATE p
SET p.GLABsID=ISNULL(tp.GLABsID,CAST(tp.id AS VARCHAR(20))),p.ExistsOnDifferentTypeFlg=1
FROM @Partner p
INNER JOIN tblPartner tp ON tp.PartnerCode=p.PartnerCode AND tp.PartnerType<>p.PartnerType AND tp.PlantCode=p.PlantCode
WHERE p.PlantCode IS NOT NULL
*/


IF(@SelfOrganized=1)
BEGIN
	--If Self organized and not exists and partner-> create without profile
	UPDATE @Partner
	SET ProfileFlg=0
	WHERE PartnerType=1 AND GLABsID IS NULL

	--If Self organized and not exists and carrier-> create with profile
	UPDATE @Partner
	SET ProfileFlg=1
	WHERE PartnerType=3 AND GLABsID IS NULL
END


IF(@SelfOrganized=0)
BEGIN
	--If not self organized and not exists and partner--> create as partner with profile
	UPDATE @Partner
	SET ProfileFlg=0
	WHERE PartnerType=1 AND GLABsID IS NULL

	--If not self organized and not exists and partner--> create as carrier with profile
	UPDATE @Partner
	SET ProfileFlg=1
	WHERE PartnerType=3 AND GLABsID IS NULL
END


----SEND A NOTIFICATION
UPDATE @Partner
SET PartnerMail='glabs@cemix.hu'
WHERE ProfileFlg=1 AND PartnerMail IS NULL

INSERT INTO [dbo].[tblPartner]
           ([GLABsID]
           ,[PartnerType]
           ,[PartnerCode]
           ,[PartnerName]
           ,[PartnerCountry]
           ,[PartnerCity]
           ,[PartnerAddress]
           ,[PartnerPhone]
           ,[PartnerMail]
		   ,[PartnerZIP]
		   ,[TaxID]
		   ,[SiteCode]
		   ,[PlantCode]
		   ,[ProfileFlg]
		   ,[Status])
		SELECT DISTINCT
			NULL, --GLABsID
			ttd.PartnerType,--Hardcoded Carrier
			ttd.PartnerCode,
			ttd.PartnerName,
			ttd.PartnerCountry,
			ttd.PartnerCity,
			ttd.PartnerAddress,
			ttd.PartnerPhone,
			ttd.PartnerMail,
			ttd.PartnerZIP,
			ttd.PartnerTaxID,
			ttd.SiteCode,
			ttd.PlantCode,
			ttd.ProfileFlg,
			0--Status		
		FROM @Partner ttd
		WHERE ttd.GLABsID IS NULL AND ttd.ProfileFlg IS NOT NULL

		UPDATE tblTransferIn
		SET PartnerFlg=1
		WHERE id=@TransferID

		SET @Msg='Success'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransportNo,TransferIn)
		SELECT 'spLoadPartner','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,1,2,@TransportNo,@TransferID
	
		SET @SuccessFlg=1

END TRY
BEGIN CATCH
	UPDATE tblTransferIn
	SET PartnerFlg=0
	WHERE id=@TransferID

	SELECT @Msg=ERROR_MESSAGE()
	--SET @Msg='SAP Partner Load failure'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,ProcessID,TransportNo,TransferIn)
	SELECT 'spLoadPartner','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,2,@TransportNo,@TransferID

	SET @SuccessFlg=0
END CATCH
END
GO
