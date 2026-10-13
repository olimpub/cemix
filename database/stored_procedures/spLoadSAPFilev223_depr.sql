/****** Object:  StoredProcedure [dbo].[spLoadSAPFilev223_depr]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[spLoadSAPFilev223_depr](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
AS
BEGIN

BEGIN TRY
DECLARE @XML XML, @Direction VARCHAR(100),@AddressCode VARCHAR(10),@InOut SMALLINT,@ID INT,@Msg VARCHAR(MAX),@DocType VARCHAR(10),@OrganizerAddressCode VARCHAR(10), @TransportNo VARCHAR(20), @SAPAddressQualifier VARCHAR(10), @Action VARCHAR(10), @PickupQualifier VARCHAR(10)


UPDATE tblTransferIn
SET BodyXML=[dbo].[fnClearSAPXML](Body)
WHERE id=@TransferID 

SELECT @XML=BodyXML FROM tblTransferIn WHERE id=@TransferID

SELECT @DocType=
	s.n.value('(DocType)[1]' ,'VARCHAR(100)')	
from @XML.nodes('SAPdocumentData') as s(n)

--LOAD DOCUMENT
IF(@DocType IS NOT NULL)
BEGIN
--Delete First
	DELETE FROM [dbo].[tblTransferTransportDocument] WHERE TransferID=@TransferID

	INSERT INTO [dbo].[tblTransferTransportDocument]
			   ([TransferID]
			   ,[TransportNo]
			   ,[DeliveryNo]
			   ,[DocType]
			   ,[PDFData]
			   ,[CreateDate])
	SELECT 	
		@TransferID,
		s.n.value('(ShipmentNo)[1]' ,'VARCHAR(100)'),
		s.n.value('(DeliveryNo)[1]' ,'VARCHAR(100)'),
		s.n.value('(DocType)[1]' ,'VARCHAR(10)'),
		s.n.value('(PDFdata)[1]' ,'NVARCHAR(MAX)'),
		GETDATE()
	from @XML.nodes('SAPdocumentData') as s(n)

	SELECT @TransportNo=
		s.n.value('(ShipmentNo)[1]' ,'VARCHAR(100)')
	from @XML.nodes('SAPdocumentData') as s(n)

	UPDATE tblTransferIn
	SET FileType=2, TransportNo=@TransportNo
	WHERE id=@TransferID
END
ELSE --Transport data
BEGIN



	--Delete first
	DELETE FROM [dbo].[tblTransferTransport] WHERE TransferID=@TransferID
	DELETE FROM [dbo].[tblTransferTransportDelivery] WHERE TransferID=@TransferID
	DELETE FROM [dbo].[tblTransferTransportDeliveryItem] WHERE TransferID=@TransferID
	DELETE FROM [dbo].[tblTransferTransportStage] WHERE TransferID=@TransferID


	DECLARE @Stages TABLE(
	StageNo VARCHAR(20),
	DeliveryNo VARCHAR(50)
	)

		DECLARE @Comments TABLE(
		DeliveryNo VARCHAR(30),
		TDID VARCHAR(10),
		Comment NVARCHAR(500)
		)
	
	DECLARE @Comments2 TABLE(
		DeliveryNo VARCHAR(30),
		Comment NVARCHAR(1000)
		)

	


	SELECT @Direction = f.m.value('(ABFER)[1]' ,'VARCHAR(5)'),--Direction
		@Action=f.m.value('(E1EDT18/QUALF)[1]' ,'VARCHAR(10)'), --Action
	@TransportNo = f.m.value('(TKNUM)[1]' ,'VARCHAR(100)')
	FROM @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20') as f(m)

	UPDATE tblTransferIn
	SET TransportNo=@TransportNo
	WHERE id=@TransferID

	IF(@Action='DEL')
	BEGIN
		UPDATE tblTransferIn
		SET FileType=3, TransportNo=@TransportNo
		WHERE id=@TransferID

		UPDATE tblTransport
		SET Status=-1
		WHERE TransportNo=@TransportNo
	END
	ELSE --Normal Transport(FileType=1)
	BEGIN
		SELECT @AddressCode = CASE WHEN @Direction IN('1','3') THEN 'WE' ELSE 'LF' END
		SELECT @OrganizerAddressCode = CASE WHEN @Direction IN('1','3') THEN 'AG' ELSE 'LF' END
		SELECT @InOut = CASE WHEN @Direction IN('1','3') THEN 1 ELSE 0 END

		INSERT INTO [dbo].[tblTransferTransport]
					(
					[TransferID]
					,[TransportNo]
					,[Priority]
					,[CarrierCode]
					,[CarrierName]
					,[CountryCode]
					,[CarrierCity]
					,[CarrierAddress]
					,[CarrierPhone]
					,[CarrierMail]
					,[CarrierZIP]
					,[CarrierTaxID]
					,[TruckType]
					,[PlantCode]
					,[PlantName]
					,[TransportDate]
					,[PrintCMR]
					,[ShipmentType]
					,[LicensePlate1]
					,[LicensePlate2]
					,[TransportNo2]
					,[DriverName]
					,[DriverPhone]
					)
		SELECT 
				@TransferID, --TransferID
				s.n.value('(TKNUM)[1]' ,'VARCHAR(100)'),  --TransportNo
				s.n.value('(BFART)[1]' ,'VARCHAR(50)'), --Service Level
				c.m.value('(PARTNER_ID)[1]' ,'VARCHAR(50)'),--TaxID/CarrierID
				c.m.value('(NAME1)[1]' ,'NVARCHAR(300)'), --CarrierName
				c.m.value('(COUNTRY1)[1]' ,'NVARCHAR(3)'), --CountryCode
				c.m.value('(CITY1)[1]' ,'NVARCHAR(150)'), --CarrierCity
				RTRIM(c.m.value('(STREET1)[1]' ,'NVARCHAR(1000)')+ ' '+ ISNULL(c.m.value('(HOUSE_SUPL)[1]' ,'NVARCHAR(1000)'),'')), --CountryAddress,
				c.m.value('(TELEPHONE1)[1]' ,'VARCHAR(100)'), --CarrierPhone
				c.m.value('(E_MAIL)[1]' ,'VARCHAR(500)'), --CarrierMail
				c.m.value('(POSTL_COD1)[1]' ,'VARCHAR(500)'), --CarrierZIP
				c.m.value('(YE1ADRM4_GLABS/STCD1)[1]' ,'VARCHAR(50)'), --CarrierTaxID
				s.n.value('(E1EDT47/E1EDT56/ADD01_BEZEI)[1]' ,'VARCHAR(500)'), --TruckType
				d.m.value('(PARTNER_ID)[1]' ,'VARCHAR(50)'), --PlantCode
				d.m.value('(NAME1)[1]' ,'NVARCHAR(300)'), --PlantName,
				dt.m.value('(NTANF)[1]' ,'NVARCHAR(100)')+dt.m.value('(NTANZ)[1]' ,'VARCHAR(100)'), --TransportDate
				s.n.value('(YE1EDT20_GLABS/PRINTCMR)[1]' ,'VARCHAR(2)'), --Print CMR
				s.n.value('(SHTYP)[1]' ,'VARCHAR(10)'), --ShipmentType
				s.n.value('(EXTI1)[1]' ,'VARCHAR(10)') ,--LicensePlate1
				s.n.value('(EXTI2)[1]' ,'VARCHAR(10)'), --LicensePlate2
				s.n.value('(E1EDT57/TNDR_TRKID)[1]' ,'VARCHAR(10)'), --TransportNo2
				s.n.value('(TPBEZ)[1]' ,'NVARCHAR(200)'),  --DriverName
				s.n.value('(SIGNI)[1]' ,'VARCHAR(100)')  --DriverPhone
		from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20') as s(n)
		CROSS APPLY @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1ADRM4') as c(m)
		CROSS APPLY @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1ADRM4') as d(m)
		--CROSS APPLY @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDT47/E1EDT56') as e(m)
		CROSS APPLY @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDT10') as dt(m)
		WHERE c.m.value('(PARTNER_Q)[1]' ,'VARCHAR(50)')='SP'
		AND d.m.value('(PARTNER_Q)[1]' ,'VARCHAR(50)')='OTP' 
		AND dt.m.value('(QUALF)[1]' ,'VARCHAR(50)')='002'

		SELECT @ID=SCOPE_IDENTITY()
		 
		 IF EXISTS(SELECT b.n.value('(NTANF)[1]' ,'VARCHAR(100)') FROM  @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as s(n)
				CROSS APPLY s.n.nodes('E1EDT13') AS b(n)
				WHERE b.n.value('(QUALF)[1]' ,'VARCHAR(50)')='006')
		 BEGIN
			SET @SAPAddressQualifier='006'
		 END
     	 ELSE IF EXISTS(SELECT b.n.value('(NTANF)[1]' ,'VARCHAR(100)') FROM  @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as s(n)
		CROSS APPLY s.n.nodes('E1EDT13') AS b(n)
		WHERE b.n.value('(QUALF)[1]' ,'VARCHAR(50)')='003')
		 BEGIN
			SET @SAPAddressQualifier='003'
		 END
		 ELSE IF EXISTS(SELECT b.n.value('(NTANF)[1]' ,'VARCHAR(100)') FROM  @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as s(n)
		CROSS APPLY s.n.nodes('E1EDT13') AS b(n)
		WHERE b.n.value('(QUALF)[1]' ,'VARCHAR(50)')='007')
		 BEGIN
			SET @SAPAddressQualifier='007'
		 END

 		 IF EXISTS(SELECT b.n.value('(NTANF)[1]' ,'VARCHAR(100)') FROM  @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as s(n)
		CROSS APPLY s.n.nodes('E1EDT13') AS b(n)
		WHERE b.n.value('(QUALF)[1]' ,'VARCHAR(50)')='003')
		 BEGIN
			SET @PickupQualifier='003'
		 END
		 ELSE IF EXISTS(SELECT b.n.value('(NTANF)[1]' ,'VARCHAR(100)') FROM  @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as s(n)
		CROSS APPLY s.n.nodes('E1EDT13') AS b(n)
		WHERE b.n.value('(QUALF)[1]' ,'VARCHAR(50)')='006')
		 BEGIN
			SET @PickupQualifier='006'
		 END
		 ELSE IF EXISTS(SELECT b.n.value('(NTANF)[1]' ,'VARCHAR(100)') FROM  @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as s(n)
		CROSS APPLY s.n.nodes('E1EDT13') AS b(n)
		WHERE b.n.value('(QUALF)[1]' ,'VARCHAR(50)')='007')
		 BEGIN
			SET @PickupQualifier='007'
		 END



		--Add Delivery Notes
		INSERT INTO [dbo].[tblTransferTransportDelivery]
				   (
				   [TransferID]
				   ,[TransportID]
				   ,[DeliveryNo]
				   ,[Direction]
				   ,[IncoTerms]
				   ,[Weight]
				   ,[Comment]
				   ,[DeliveryDate]
				   ,[PickupDate]
				   ,[PartnerCode]
				   ,[PartnerName]
				   ,[PartnerCountry]
				   ,[PartnerCity]
				   ,[PartnerAddress]
				   ,[PartnerPhone]
				   ,[PartnerMail]
				   ,[PartnerZIP]
				   ,[PartnerTaxID]
				   ,[ContactInfo]
				   ,[OrganizerCode]
				   ,[OrganizerName]
				   ,[OrganizerCountryCode]
				   ,[OrganizerCity]
				   ,[OrganizerAddress]
				   ,[OrganizerPhone]
				   ,[OrganizerMail]
				   ,[OrganizerZIP]
				   ,[OrganizerTaxID]

		)
		SELECT 
			@TransferID, --TransferID
			@ID,--TransportID
			s.n.value('(VBELN)[1]' ,'VARCHAR(100)'),  --DeliveryNo
			@InOut,  --Direction
			ISNULL((s.n.value('(INCO1)[1]' ,'VARCHAR(100)') +' ' +s.n.value('(INCO2)[1]' ,'VARCHAR(100)')),''), --IncoTerms
			s.n.value('(BTGEW)[1]' ,'NUMERIC(12,2)'), --Weight
			'',--ISNULL(s.n.value('(E1TXTH8/E1TXTP8/TDLINE)[1]' ,'VARCHAR(100)'),''), --COMMENT
			z.n.value('(NTANF)[1]' ,'VARCHAR(100)'),  --DeliveryDate
			b.n.value('(NTANF)[1]' ,'VARCHAR(100)')+b.n.value('(NTANZ)[1]' ,'VARCHAR(100)') , --PickupDate
			x.n.value('(PARTNER_ID)[1]' ,'VARCHAR(50)'), --PartnerCode
			x.n.value('(NAME1)[1]' ,'NVARCHAR(300)'), --PartnerName
			x.n.value('(COUNTRY1)[1]' ,'NVARCHAR(3)'), --PartnerCountry
			x.n.value('(CITY1)[1]' ,'NVARCHAR(150)'), --PartnerCity
			RTRIM(x.n.value('(STREET1)[1]' ,'NVARCHAR(1000)')+ ' '+ ISNULL(x.n.value('(HOUSE_SUPL)[1]' ,'NVARCHAR(1000)'),'')), --PartnerAddress, 
			ISNULL(x.n.value('(TELEPHONE2)[1]' ,'VARCHAR(100)'),x.n.value('(TELEPHONE1)[1]' ,'VARCHAR(100)')), --PartnerPhone??
			x.n.value('(E_MAIL)[1]' ,'VARCHAR(500)'), --PartnerMail??
			x.n.value('(POSTL_COD1)[1]' ,'VARCHAR(500)'), --PartnerZIP??
			x.n.value('(YE1ADRM1_GLABS/STCD1)[1]' ,'VARCHAR(50)'),--PartnerTaxID
			x.n.value('(NAME2)[1]' ,'NVARCHAR(300)'), --ContactInfo
			y.n.value('(PARTNER_ID)[1]' ,'VARCHAR(50)'),--CarrierID
			y.n.value('(NAME1)[1]' ,'NVARCHAR(300)'), --CarrierName
			y.n.value('(COUNTRY1)[1]' ,'NVARCHAR(3)'), --CountryCode
			y.n.value('(CITY1)[1]' ,'NVARCHAR(150)'), --CarrierCity
			RTRIM(y.n.value('(STREET1)[1]' ,'NVARCHAR(1000)')+ ' '+ ISNULL(y.n.value('(HOUSE_SUPL)[1]' ,'NVARCHAR(1000)'),'')), --CountryAddress
			y.n.value('(TELEPHONE1)[1]' ,'VARCHAR(100)'), --CarrierPhone
			y.n.value('(E_MAIL)[1]' ,'VARCHAR(500)'), --CarrierMail
			y.n.value('(POSTL_COD1)[1]' ,'VARCHAR(500)'), --CarrierZIP--Contact Info??
			y.n.value('(YE1ADRM1_GLABS/STCD1)[1]' ,'VARCHAR(50)') --CarrierTaxID*/
		from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as s(n)
		CROSS APPLY s.n.nodes('E1EDT13') as z(n)
		CROSS APPLY s.n.nodes('E1ADRM1') as x(n)
		CROSS APPLY s.n.nodes('E1ADRM1') as y(n)
		CROSS APPLY s.n.nodes('E1EDT13') as b(n)
		WHERE z.n.value('(QUALF)[1]' ,'VARCHAR(50)')=@SAPAddressQualifier
		AND b.n.value('(QUALF)[1]' ,'VARCHAR(50)')=@PickupQualifier
		AND x.n.value('(PARTNER_Q)[1]' ,'VARCHAR(50)')=@AddressCode
		AND y.n.value('(PARTNER_Q)[1]' ,'VARCHAR(50)')=@OrganizerAddressCode

		DECLARE @QS TABLE(
			DeliveryNo VARCHAR(50),
			Pos VARCHAR(10),
			QC VARCHAR(50)
		)

		INSERT INTO @QS(DeliveryNo,Pos,QC)
		SELECT
		b.n.value('(VBELN)[1]' ,'VARCHAR(100)'),
		s.n.value('(POSNR)[1]' ,'VARCHAR(100)'),
		z.n.value('(QUALI)[1]' ,'VARCHAR(50)')
		FROM @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as b(n)
		CROSS APPLY b.n.nodes('E1EDL24') AS s(n)
		CROSS APPLY s.n.nodes('E1EDL41') AS z(n)
		WHERE z.n.value('(QUALI)[1]' ,'VARCHAR(100)')='002'


		INSERT INTO [dbo].[tblTransferTransportDeliveryItem]
				   (
				   [TransferID]
				   ,[TransportID]
				   ,[DeliveryNo]
				   ,[ItemNo]
				   ,[ItemCode]
				   ,[ItemName]
				   ,[OrderNo]
				   ,[Qty]
				   ,[QtyUnit]
				   ,[PalletQty]
				   ,[TaxCode]
				   ,[Comment]
				   ,[StockQty]
				   ,[NetWeight]
				   ,[GrossWeight]
				   ,[WeightUnit])
		SELECT
			@TransferID, --TransferID
			@ID, --TransportNo
			b.n.value('(VBELN)[1]' ,'VARCHAR(100)'), --DeliveryNo
			s.n.value('(POSNR)[1]' ,'VARCHAR(100)'),  --ItemNo
			s.n.value('(MATNR)[1]' ,'VARCHAR(100)'),  --ItemCode
			ISNULL(s.n.value('(YE1EDL24_GLABS/MAKTX_HU)[1]' ,'VARCHAR(300)'),s.n.value('(ARKTX)[1]' ,'VARCHAR(300)')),  --ItemName MAKTX_HU
			CASE WHEN ISNULL(z.n.value('(BSTNR)[1]' ,'VARCHAR(100)'),'') LIKE 'ECO%' THEN ISNULL(s.n.value('(VGBEL)[1]' ,'VARCHAR(100)'),'')
			ELSE ISNULL(z.n.value('(BSTNR)[1]' ,'VARCHAR(100)'),ISNULL(s.n.value('(VGBEL)[1]' ,'VARCHAR(100)'),'')) END,  --OrderNo
			s.n.value('(LFIMG)[1]' ,'VARCHAR(100)'),  --Qty
			s.n.value('(VRKME)[1]' ,'VARCHAR(100)'),  --QtyUnit
			s.n.value('(YE1EDL24_GLABS/LFIMG_PAL)[1]' ,'VARCHAR(100)'),  --PalletQty
			s.n.value('(E1EDL26/PSTYV)[1]' ,'VARCHAR(100)'),  --TaxCode
			s.n.value('(CMT)[1]' ,'NVARCHAR(500)'), --Comment	
			s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),  --StockQty
			s.n.value('(NTGEW)[1]' ,'VARCHAR(100)'),  --Net Weight
			s.n.value('(BRGEW)[1]' ,'VARCHAR(100)'),  --Gross Weight
			s.n.value('(GEWEI)[1]' ,'VARCHAR(100)')  --Net Weight
		FROM @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as b(n)
		CROSS APPLY b.n.nodes('E1EDL24') AS s(n)
		CROSS APPLY s.n.nodes('E1EDL41') AS z(n)
		WHERE z.n.value('(QUALI)[1]' ,'VARCHAR(100)')='002'

		INSERT INTO [dbo].[tblTransferTransportDeliveryItem]
				   (
				   [TransferID]
				   ,[TransportID]
				   ,[DeliveryNo]
				   ,[ItemNo]
				   ,[ItemCode]
				   ,[ItemName]
				   ,[OrderNo]
				   ,[Qty]
				   ,[QtyUnit]
				   ,[PalletQty]
				   ,[TaxCode]
				   ,[Comment]
				   ,[StockQty]
				   ,[NetWeight]
				   ,[GrossWeight]
				   ,[WeightUnit])
		SELECT
			@TransferID, --TransferID
			@ID, --TransportNo
			b.n.value('(VBELN)[1]' ,'VARCHAR(100)'), --DeliveryNo
			s.n.value('(POSNR)[1]' ,'VARCHAR(100)'),  --ItemNo
			s.n.value('(MATNR)[1]' ,'VARCHAR(100)'),  --ItemCode
			ISNULL(s.n.value('(YE1EDL24_GLABS/MAKTX_HU)[1]' ,'VARCHAR(300)'),s.n.value('(ARKTX)[1]' ,'VARCHAR(300)')),  --ItemName
			ISNULL(s.n.value('(VGBEL)[1]' ,'VARCHAR(100)'),''),  --OrderNo
			s.n.value('(LFIMG)[1]' ,'VARCHAR(100)'),  --Qty
			s.n.value('(VRKME)[1]' ,'VARCHAR(100)'),  --QtyUnit
			s.n.value('(YE1EDL24_GLABS/LFIMG_PAL)[1]' ,'VARCHAR(100)'),  --PalletQty
			s.n.value('(E1EDL26/PSTYV)[1]' ,'VARCHAR(100)'),  --TaxCode
			s.n.value('(CMT)[1]' ,'NVARCHAR(500)'), --Comment	
			s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),  --StockQty
			s.n.value('(NTGEW)[1]' ,'VARCHAR(100)'),  --Net Weight
			s.n.value('(BRGEW)[1]' ,'VARCHAR(100)'),  --Gross Weight
			s.n.value('(GEWEI)[1]' ,'VARCHAR(100)')  --Net Weight
		from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as b(n)
		CROSS APPLY b.n.nodes('E1EDL24') AS s(n)
		WHERE NOT EXISTS(SELECT * FROM @QS qs WHERE qs.DeliveryNo=b.n.value('(VBELN)[1]' ,'VARCHAR(100)') AND qs.Pos=s.n.value('(POSNR)[1]' ,'VARCHAR(100)'))


		--New TransportStage Logic
		DECLARE @Stage TABLE(
			[Direction] [bit] NULL,
			[StageNo] [varchar](10) NULL,
			[DeliveryNo] [varchar](100) NOT NULL,
			[AddressNo] [varchar](50) NOT NULL,
			[PartnerCode] [varchar](50) NOT NULL,
			[PartnerName] [nvarchar](300) NOT NULL,
			[PartnerCountry] [varchar](3) NULL,
			[PartnerCity] [nvarchar](150) NOT NULL,
			[PartnerAddress] [nvarchar](1000) NULL,
			[PartnerPhone] [varchar](100) NULL,
			[PartnerMail] [varchar](500) NULL,
			[PartnerZIP] [varchar](15) NULL)
		
		INSERT INTO @Stage
		SELECT 
				0, --Direction
				s.n.value('(TSNUM)[1]' ,'VARCHAR(100)'),	--StageNo
				x.n.value('(VBELN)[1]' ,'VARCHAR(100)'),	--DeliveryNo
				ISNULL(z.n.value('(ADRNR)[1]' ,'VARCHAR(100)'),''), --AddressNo
				ISNULL(ISNULL(z.n.value('(KUNNR)[1]' ,'VARCHAR(100)'),z.n.value('(VSTEL)[1]' ,'VARCHAR(100)')),s.n.value('(E1EDT44/LIFNR)[1]' ,'VARCHAR(100)')), --PartnerCode
				z.n.value('(E1ADRM6/NAME1)[1]' ,'NVARCHAR(300)'), --PartnerName
				z.n.value('(E1ADRM6/COUNTRY1)[1]' ,'NVARCHAR(3)'), --PartnerCountry
				z.n.value('(E1ADRM6/CITY1)[1]' ,'NVARCHAR(150)'), --PartnerCity
				RTRIM(z.n.value('(E1ADRM6/STREET1)[1]' ,'NVARCHAR(1000)')+ ' '+ ISNULL(z.n.value('(E1ADRM6/HOUSE_SUPL)[1]' ,'NVARCHAR(1000)'),'')), --PartnerAddress
				z.n.value('(E1ADRM6/TELEPHONE1)[1]' ,'VARCHAR(100)'), --PartnerPhone??
				z.n.value('(E1ADRM6/E_MAIL)[1]' ,'VARCHAR(500)'), --PartnerMail??
				z.n.value('(E1ADRM6/POSTL_COD1)[1]' ,'VARCHAR(500)') --PartnerZIP??
			from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDK33') as s(n)
			CROSS APPLY s.n.nodes('E1EDT01') as x(n)
			CROSS APPLY s.n.nodes('E1EDT44') as z(n)
			WHERE z.n.value('(QUALI)[1]' ,'VARCHAR(50)')='001'
		
		INSERT INTO @Stage
		SELECT 
				1,--Direction
				s.n.value('(TSNUM)[1]' ,'VARCHAR(100)'),	--StageNo
				--s.n.value('(E1EDT44/VSTEL)[1]' ,'VARCHAR(100)'),  --SiteCode
				x.n.value('(VBELN)[1]' ,'VARCHAR(100)'),	--DeliveryNo
				ISNULL(z.n.value('(ADRNR)[1]' ,'VARCHAR(100)'),''), --AddressNo
				ISNULL(ISNULL(z.n.value('(KUNNR)[1]' ,'VARCHAR(100)'),z.n.value('(VSTEL)[1]' ,'VARCHAR(100)')),(z.n.value('(WERKS)[1]' ,'VARCHAR(100)'))), --PartnerCode
				z.n.value('(E1ADRM6/NAME1)[1]' ,'NVARCHAR(300)'), --PartnerName
				z.n.value('(E1ADRM6/COUNTRY1)[1]' ,'NVARCHAR(3)'), --PartnerCountry
				z.n.value('(E1ADRM6/CITY1)[1]' ,'NVARCHAR(150)'), --PartnerCity
				RTRIM(z.n.value('(E1ADRM6/STREET1)[1]' ,'NVARCHAR(1000)')+ ' '+ ISNULL(z.n.value('(E1ADRM6/HOUSE_SUPL)[1]' ,'NVARCHAR(1000)'),'')), --PartnerAddress
				z.n.value('(E1ADRM6/TELEPHONE1)[1]' ,'VARCHAR(100)'), --PartnerPhone??
				z.n.value('(E1ADRM6/E_MAIL)[1]' ,'VARCHAR(500)'), --PartnerMail??
				z.n.value('(E1ADRM6/POSTL_COD1)[1]' ,'VARCHAR(500)') --PartnerZIP??
			from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDK33') as s(n)
			CROSS APPLY s.n.nodes('E1EDT01') as x(n)
			CROSS APPLY s.n.nodes('E1EDT44') as z(n)
			WHERE z.n.value('(QUALI)[1]' ,'VARCHAR(50)')='002'
		
			INSERT INTO [dbo].[tblTransferTransportStage]
					   ([TransferID]
					   ,[StageNo]
					   ,[DeliveryNo]
					   ,[AddressNo]
					   ,[PartnerCodeFrom]
					   ,[PartnerNameFrom]
					   ,[PartnerCountryFrom]
					   ,[PartnerCityFrom]
					   ,[PartnerAddressFrom]
					   ,[PartnerPhoneFrom]
					   ,[PartnerMailFrom]
					   ,[PartnerZIPFrom]
					   ,[PartnerCodeTo]
					   ,[PartnerNameTo]
					   ,[PartnerCountryTo]
					   ,[PartnerCityTo]
					   ,[PartnerAddressTo]
					   ,[PartnerPhoneTo]
					   ,[PartnerMailTo]
					   ,[PartnerZIPTo])
				SELECT 
						@TransferID,
						st.StageNo,
						st.DeliveryNo,
						ISNULL((SELECT TOP 1 st2.AddressNo FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.AddressNo<>'' ORDER BY st2.Direction DESC),''),
						PartnerCode,
						PartnerName,
						PartnerCountry,
						PartnerCity,
						PartnerAddress,
						PartnerPhone,
						PartnerMail,
						PartnerZIP,
						(SELECT st2.PartnerCode FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.Direction=1),
						(SELECT st2.PartnerName FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.Direction=1), 
						(SELECT st2.PartnerCountry FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.Direction=1),
						(SELECT st2.PartnerCity FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.Direction=1),
						(SELECT st2.PartnerAddress FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.Direction=1),
						(SELECT st2.PartnerPhone FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.Direction=1),
						(SELECT st2.PartnerMail FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.Direction=1),
						(SELECT st2.PartnerZIP FROM @Stage st2 WHERE st2.StageNo=st.StageNo AND st2.DeliveryNo=st.DeliveryNo AND st2.Direction=1)
					FROM @Stage st
					WHERE st.Direction=0

			--Delivery Comment logic outbound logic
			INSERT INTO @Comments(DeliveryNo,TDID,Comment)
			SELECT 
				s.n.value('(VBELN)[1]' ,'VARCHAR(100)'),  --DeliveryNo
				z.n.value('(TDID)[1]' ,'VARCHAR(100)') , --DeliveryNo
				ISNULL(y.n.value('(TDLINE)[1]' ,'VARCHAR(100)'),'') --COMMENT
			from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as s(n)
			CROSS APPLY s.n.nodes('E1TXTH8') as z(n)
			OUTER APPLY z.n.nodes('E1TXTP8') as y(n)
			WHERE s.n.value('(E1EDT13/QUALF)[1]' ,'VARCHAR(50)')='006'
	 
			 INSERT INTO @Comments2(DeliveryNo, Comment)
			 SELECT c.DeliveryNo, ISNULL((SELECT  CAST((SELECT CAST(cc.Comment AS NVARCHAR(500))+' ' 
					FROM @Comments cc
					WHERE cc.DeliveryNo=c.DeliveryNo AND (TDID='Y002' OR TDID='0100')
					FOR XML PATH('')) AS NVARCHAR(1000))),'') FROM @Comments c
					GROUP BY c.DeliveryNo
		
			--Update comment form multiple rows
			UPDATE ttd
			SET ttd.Comment=cc.Comment
			FROM tblTransferTransportDelivery ttd INNER JOIN @Comments2 cc ON cc.DeliveryNo=ttd.DeliveryNo
			
			--HERE ADD Comment in case of inbound

		

			--Now just comment OUT NEED to TEST with NEW STRUCTURE
			/*				
				--If SiteCode Customer pallet come back Y006
					UPDATE ttd 
					SET ttd.Direction=0
					FROM tblTransferTransportDelivery ttd INNER JOIN tblTransferTransportStage st ON st.DeliveryNo=ttd.DeliveryNo 
					INNER JOIN tblClientParams tc ON tc.SiteCode=st.PartnerCode WHERE st.TransferID=@TransferID	


				--If WHCode and PartnerName<>WhName Pallet repair Out
					UPDATE ttd 
					SET ttd.Direction=0
					FROM tblTransferTransportDelivery ttd INNER JOIN tblTransferTransportStage st ON st.DeliveryNo=ttd.DeliveryNo 
					INNER JOIN tblClientParams tc ON tc.WHCode=st.PartnerCode AND tc.WHName=st.PartnerName  WHERE st.TransferID=@TransferID	
					AND tc.ActiveFlg=1

				--If WHCode and PartnerName=WhName Pallet repair in
					UPDATE ttd 
					SET ttd.Direction=1
					FROM tblTransferTransportDelivery ttd INNER JOIN tblTransferTransportStage st ON st.DeliveryNo=ttd.DeliveryNo 
					INNER JOIN tblClientParams tc ON tc.WHCode=st.PartnerCode AND tc.WHName<>st.PartnerName  WHERE st.TransferID=@TransferID
					AND tc.ActiveFlg=1
			*/
			--OLD logic for interfactory
			/*
				IF EXISTS(SELECT * FROM tblTransferTransportStage sa INNER JOIN tblClientParams tc ON tc.WHCode=sa.PartnerCode WHERE sa.TransferID=@TransferID)
				BEGIN
					DECLARE 
					@PartnerCode [varchar](50),
					@PartnerName [nvarchar](300),
					@PartnerCountry [varchar](3),
					@PartnerCity [nvarchar](150),
					@PartnerAddress [nvarchar](1000),
					@PartnerPhone [varchar](100),
					@PartnerMail [varchar](500),
					@PartnerZIP [varchar](15)

					SELECT @PartnerCode = tc.WHCode, @PartnerName = tc.WHName, @PartnerCountry = tc.WHCountry, @PartnerCity = tc.WHCity, @PartnerAddress = tc.WHAddress,@PartnerPhone = tc.WHPhone, 
					@PartnerMail = tc.WHMail, @PartnerZIP = tc.WHZIP FROm tblClientParams tc WHERE SiteCode=@PlantCode


					--Set Direction Im
					UPDATE ttd 
					SET ttd.Direction=0, ttd.PartnerCode=@PartnerCode, ttd.PartnerCity=@PartnerCity, ttd.PartnerAddress=@PartnerAddress, ttd.PartnerCountry=@PartnerCountry,
					ttd.PartnerMail=@PartnerMail, ttd.PartnerName=@PartnerName, ttd.PartnerPhone=@PartnerPhone, ttd.PartnerZIP=@PartnerZIP
					FROM tblTransferTransportDelivery ttd INNER JOIN tblTransferTransportStage st ON st.DeliveryNo=ttd.DeliveryNo 
					INNER JOIN tblClientParams tc ON tc.WHCode=st.PartnerCode WHERE st.TransferID=@TransferID
		

					--Set PlantCode
					UPDATE tta 
					SET tta.PlantCode=tc.SiteCode
					FROM tblTransferTransport tta
					INNER JOIN  tblTransferTransportDelivery ttd ON ttd.TransportID=tta.id
					INNER JOIN tblTransferTransportStage st ON st.DeliveryNo=ttd.DeliveryNo 
					INNER JOIN tblClientParams tc ON tc.WHCode=st.PartnerCode 
					WHERE st.TransferID=@TransferID
				END
			*/
	
			UPDATE ts
			SET ts.SiteIDFrom=ISNULL(tc.SiteCode,tc2.SiteCode)
			FROm tblTransferTransportStage ts
			LEFT OUTER JOIN tblClientParams tc ON tc.SiteCode=ts.PartnerCodeFrom AND tc.ActiveFlg=1
			LEFT OUTER JOIN tblClientParams tc2 ON tc2.WHCode=ts.PartnerCodeFrom AND tc2.ActiveFlg=1
			WHERE ts.TransferID=@TransferID


			UPDATE ts
			SET ts.SiteIDTo=ISNULL(tc.SiteCode,tc2.SiteCode)
			FROm tblTransferTransportStage ts
			LEFT OUTER JOIN tblClientParams tc ON tc.SiteCode=ts.PartnerCodeTo AND tc.ActiveFlg=1
			LEFT OUTER JOIN tblClientParams tc2 ON tc2.WHCode=ts.PartnerCodeTo AND tc2.ActiveFlg=1
			WHERE ts.TransferID=@TransferID

			UPDATE tdd
			SET tdd.StageNo=st.StageNo, 
			tdd.SiteID=CASE WHEN  st.SiteIDFrom IS NOT NULL THEN st.SiteIDFrom WHEN   st.SiteIDFrom IS NULL THEN st.SiteIDTo END,
			tdd.Direction=CASE WHEN  st.SiteIDFrom IS NOT NULL THEN 1 WHEN  st.SiteIDFrom IS NULL THEN 0 END
			FROM [dbo].[tblTransferTransportDelivery] tdd 
			INNER JOIN [dbo].[tblTransferTransportStage] st ON st.DeliveryNo=tdd.DeliveryNo AND st.TransferID=tdd.TransferID
			WHERE tdd.TransferID=@TransferID 

			UPDATE tdd
			SET tdd.PartnerCode=st.PartnerCodeFrom, tdd.PartnerName=st.PartnerNameFrom, tdd.PartnerCountry=st.PartnerCountryFrom,
			tdd.PartnerCity=st.PartnerCityFrom, tdd.PartnerAddress=st.PartnerAddressFrom,tdd.PartnerZIP=st.PartnerZIPFrom
			FROM [dbo].[tblTransferTransportDelivery] tdd 
			INNER JOIN [dbo].[tblTransferTransportStage] st ON st.DeliveryNo=tdd.DeliveryNo AND st.TransferID=tdd.TransferID
			WHERE tdd.TransferID=@TransferID AND tdd.Direction=0

			UPDATE tdd
			SET tdd.PartnerCode=st.PartnerCodeTo, tdd.PartnerName=st.PartnerNameTo, tdd.PartnerCountry=st.PartnerCountryTo,
			tdd.PartnerCity=st.PartnerCityTo, tdd.PartnerAddress=st.PartnerAddressTo,tdd.PartnerZIP=st.PartnerZIPTo
			FROM [dbo].[tblTransferTransportDelivery] tdd 
			INNER JOIN [dbo].[tblTransferTransportStage] st ON st.DeliveryNo=tdd.DeliveryNo AND st.TransferID=tdd.TransferID
			WHERE tdd.TransferID=@TransferID AND tdd.Direction=1

			DECLARE @SelfOrganized BIT

			SELECT @SelfOrganized=	[dbo].[fnGetShipmentOrganizer](ttt.ShipmentType) FROM tblTransferTransport ttt WHERE TransferID=@TransferID

			IF(@SelfOrganized=0)
			BEGIN
				UPDATE tt
				SET OrganizerCode=ttd.OrganizerCode, tt.OrganizerAddress=ttd.OrganizerAddress, tt.OrganizerCity=ttd.OrganizerCity, tt.OrganizerCountryCode=ttd.OrganizerCountryCode, tt.OrganizerMail=ttd.OrganizerMail,
				tt.OrganizerName=ttd.OrganizerName, tt.OrganizerPhone=ttd.OrganizerPhone, tt.OrganizerZIP=ttd.OrganizerZIP, tt.OrganizerTaxID=ttd.OrganizerTaxID
				FROM [dbo].[tblTransferTransport] tt
				INNER JOIN [dbo].[tblTransferTransportDelivery] ttd ON ttd.TransportID=tt.id
				WHERE ttd.id=(SELECT MIN(ttd2.id) FROM [dbo].[tblTransferTransportDelivery] ttd2 WHERE ttd2.TransferID=@TransferID AND ttd2.OrganizerCode IS NOT NULL)
				AND tt.TransferID=@TransferID
			END

		UPDATE tdd
		SET tdd.StageNo=st.StageNo, tdd.PartnerCode=CASE WHEN tdd.PartnerCode IN('LHU01','LRO01') THEN st.AddressNo ELSE tdd.PartnerCode END
		FROM [dbo].[tblTransferTransportDelivery] tdd 
		INNER JOIN [dbo].[tblTransferTransportStage] st ON st.DeliveryNo=tdd.DeliveryNo AND st.TransferID=tdd.TransferID
		WHERE tdd.TransferID=@TransferID
		 
        --Define Real Site Code
		DECLARE @SiteCode VARCHAR(15), @PartnerFrom VARCHAR(50), @PartnerTo VARCHAR(50)
	
		SELECT @PartnerFrom = sta.PartnerCodeFrom, @PartnerTo=sta.PartnerCodeTo  
		FROM tblTransferTransportStage sta 
		WHERE sta.TransferID=@TransferID 
		AND sta.StageNo=(
			SELECT MIN(sta2.StageNo) FROM tblTransferTransportStage sta2 WHERE sta2.TransferID=@TransferID
			)
		
		IF EXISTS(SELECT * FROM tblClientParams cp WHERE cp.SiteCode=@PartnerFrom AND cp.ActiveFlg=1)
		BEGIN
			SET @SiteCode=@PartnerFrom	
		END

		IF (@SiteCode IS NULL AND EXISTS(SELECT * FROM tblClientParams cp WHERE cp.SiteCode=@PartnerTo AND cp.ActiveFlg=1))
		BEGIN
			SET @SiteCode=@PartnerTo
		END

		IF(@SiteCode IS NOT NULL)
		BEGIN
			UPDATE tblTransferTransport
			SET PlantCode=@SiteCode
			WHERE TransferID=@TransferID
		END

		--Special Logics
		--If SiteCode Customer pallet come back Y006
		UPDATE ts
		SET ts.SiteIDTo=NULL
		FROm tblTransferTransportStage ts
		WHERE ts.TransferID=@TransferID AND ts.SiteIDFrom=ts.SiteIDTo

		UPDATE ttd 
		SET ttd.Direction=0
		FROM tblTransferTransportDelivery ttd INNER JOIN tblClientParams tc 
		ON tc.SiteCode=ttd.SiteID WHERE ttd.SiteID=ttd.PartnerCode AND ttd.TransferID=@TransferID AND tc.ActiveFlg=1


		--If WHCode and PartnerName<>WhName Pallet repair Out
		UPDATE ttd 
		SET ttd.Direction=0
		FROM tblTransferTransportDelivery ttd 	INNER JOIN tblClientParams tc 
		ON tc.WHCode=ttd.PartnerCode AND tc.WHName=ttd.PartnerName AND tc.SiteCode=ttd.SiteID
		WHERE ttd.TransferID=@TransferID AND tc.ActiveFlg=1

		--If WHCode and PartnerName=WhName Pallet repair in
		UPDATE ttd 
		SET ttd.Direction=0
		FROM tblTransferTransportDelivery ttd 	INNER JOIN tblClientParams tc 
		ON tc.WHCode=ttd.PartnerCode AND tc.WHName<>ttd.PartnerName AND tc.SiteCode=ttd.SiteID
		WHERE ttd.TransferID=@TransferID AND tc.ActiveFlg=1



		--LHU001 logic

		UPDATE tblTransferIn
		SET FileType=1
		WHERE id=@TransferID
	END

END

	UPDATE tblTransferIn
	SET LoadFlg=1
	WHERE id=@TransferID

	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,TransportNo,ProcessID,TransferIn)
	SELECT 'spLoadSAPFilev223','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,1,@TransportNo,1,@TransferID
	
	SET @SuccessFlg=1

END TRY
BEGIN CATCH
	UPDATE tblTransferIn
	SET LoadFlg=0
	WHERE id=@TransferID

	SELECT @Msg=ERROR_MESSAGE()
	--SET @Msg='SAP Load failure'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,TransportNo,ProcessID,TransferIn)
	SELECT 'spLoadSAPFilev223','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,@TransportNo,1,@TransferID

	SET @SuccessFlg=0
END CATCH
END
GO
