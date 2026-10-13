/****** Object:  StoredProcedure [dbo].[spLoadSAPFilevS4]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







CREATE PROCEDURE [dbo].[spLoadSAPFilevS4](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
AS
BEGIN

BEGIN TRY

DECLARE @XML XML, @Direction VARCHAR(100),@AddressCode VARCHAR(10),@InOut SMALLINT,@ID INT,@Msg VARCHAR(MAX),@DocType VARCHAR(10),@OrganizerAddressCode VARCHAR(10), @TransportNo VARCHAR(20), @SAPAddressQualifier VARCHAR(10), @Action VARCHAR(10), @PickupQualifier VARCHAR(10), @DeliveryNo VARCHAR(100)


UPDATE tblTransferIn
SET BodyXML=[dbo].[fnClearSAPXML](Body)
WHERE id=@TransferID 

SELECT @XML=BodyXML FROM tblTransferIn WHERE id=@TransferID

SELECT @XML

SELECT @DocType=
    @xml.value('(/GLABS_DOCUMENT/doctype)[1]', 'VARCHAR(100)')

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
		s.n.value('(freight_order)[1]' ,'VARCHAR(100)'),
		s.n.value('(delivery)[1]' ,'VARCHAR(100)'),
		s.n.value('(doctype)[1]' ,'VARCHAR(50)'),
		s.n.value('(pdf_url)[1]' ,'NVARCHAR(MAX)'),
		GETDATE()
	from @XML.nodes('GLABS_DOCUMENT') as s(n)

	SELECT @DeliveryNo=
		s.n.value('(delivery)[1]' ,'VARCHAR(100)'),
		@TransportNo=
		s.n.value('(freight_order)[1]' ,'VARCHAR(100)')
	from @XML.nodes('GLABS_DOCUMENT') as s(n)

	SELECT @TransportNo=RIGHT(@TransportNo, LEN(@TransportNo) - PATINDEX('%[^0]%', @TransportNo) + 1)

	UPDATE ttd
	SET TransportNo=@TransportNo
	FROM [dbo].[tblTransferTransportDocument] ttd WHERE ttd.TransferID=@TransferID

	UPDATE tblTransferIn
	SET FileType=2, TransportNo=@TransportNo,LoadFlg=1
	WHERE id=@TransferID

	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,TransportNo,ProcessID,TransferIn)
	SELECT 'spLoadSAPFilev223','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,1,@TransportNo,1,@TransferID
	
	SET @SuccessFlg=1
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

	SELECT @Direction, @Action, @TransportNo

	UPDATE tblTransferIn
	SET TransportNo=@TransportNo
	WHERE id=@TransferID
	
	IF(@Action='DEL')
	BEGIN
		UPDATE tblTransferIn
		SET FileType=3, TransportNo=@TransportNo,LoadFlg=1
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

		SELECT @AddressCode, @OrganizerAddressCode, @InOut

		
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
				d.m.value('(TPLST)[1]' ,'VARCHAR(50)'), --PlantCode
				'',--d.m.value('(NAME1)[1]' ,'NVARCHAR(300)'), --PlantName,
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
		CROSS APPLY @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/YE1EDT20_GLABS') as d(m)
		--CROSS APPLY @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDT47/E1EDT56') as e(m)
		CROSS APPLY @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDT10') as dt(m)
		WHERE c.m.value('(PARTNER_Q)[1]' ,'VARCHAR(50)')='SP'
		--AND d.m.value('(PARTNER_Q)[1]' ,'VARCHAR(50)')='OTP' 
		----AND dt.m.value('(QUALF)[1]' ,'VARCHAR(50)')='002'

		---H311 -Veszprém,H312- Bugyi, H313 - Vác, H314 Debrecen    //TPLST

		/*
		--Organizer codes
		BO10 = we organise, outbound
		BO11 = customer pick up, outbound
		BO20 = we organise, inbound
		BO21 = customer / vendor organises, inbound
		
		SELECT * FROM [dbo].[tblXrefShipmentOrganizer]
		

		INSERT INTO [dbo].[tblXrefShipmentOrganizer]
		SELECT 'BO10',1

		INSERT INTO [dbo].[tblXrefShipmentOrganizer]
		SELECT 'BO11',0

		INSERT INTO [dbo].[tblXrefShipmentOrganizer]
		SELECT 'BO20',1

		INSERT INTO [dbo].[tblXrefShipmentOrganizer]
		SELECT 'BO21',0

		*/

		/*With this??
		 
			Forwarding Agent Tracking ID = merged transports
 
			@Filkorn Erzsébet
			For the trucks which need to offload first empty pallets at CEMIX and then load cargo for customers, we will use this field in the freight order.
 
			@Jan Holakovský: it is ROOT, STOP_SUCC (Successor_id = 10), STOP_SUCC_DOCREFERENCE (select BTD_ID where BTD_TCO = 12)

		*/

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
			@TransferID, @ID,
			s.n.value('(VBELN)[1]' ,'VARCHAR(100)'),
			@InOut,
			ISNULL(s.n.value('(INCO1)[1]' ,'VARCHAR(100)') +' ' +s.n.value('(INCO2)[1]' ,'VARCHAR(100)'),''),
			s.n.value('(BTGEW)[1]' ,'NUMERIC(12,2)'),
			'',
			z.n.value('(NTANF)[1]' ,'VARCHAR(100)'),
			b.n.value('(NTANF)[1]' ,'VARCHAR(100)')+b.n.value('(NTANZ)[1]' ,'VARCHAR(100)'),
			xa.PARTNER_ID, xa.NAME1, xa.COUNTRY1, xa.CITY1,
			RTRIM(xa.STREET1 + ' ' + ISNULL(xa.HOUSE_SUPL,'')),
			ISNULL(xa.TELEPHONE2, xa.TELEPHONE1),
			xa.E_MAIL, xa.POSTL_COD1, xa.STCD1, xa.NAME2,
			ya.PARTNER_ID, ya.NAME1, ya.COUNTRY1, ya.CITY1,
			RTRIM(ya.STREET1 + ' ' + ISNULL(ya.HOUSE_SUPL,'')),
			ya.TELEPHONE1, ya.E_MAIL, ya.POSTL_COD1, ya.STCD1
		FROM @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') AS s(n)
		OUTER APPLY s.n.nodes('E1EDT13') AS z(n)
		OUTER APPLY s.n.nodes('E1EDT13') AS b(n)
		OUTER APPLY (
			SELECT 
				t.n.value('(PARTNER_ID)[1]','varchar(50)') AS PARTNER_ID,
				t.n.value('(NAME1)[1]','nvarchar(300)') AS NAME1,
				t.n.value('(COUNTRY1)[1]','nvarchar(3)') AS COUNTRY1,
				t.n.value('(CITY1)[1]','nvarchar(150)') AS CITY1,
				t.n.value('(STREET1)[1]','nvarchar(1000)') AS STREET1,
				t.n.value('(HOUSE_SUPL)[1]','nvarchar(1000)') AS HOUSE_SUPL,
				t.n.value('(TELEPHONE2)[1]','varchar(100)') AS TELEPHONE2,
				t.n.value('(TELEPHONE1)[1]','varchar(100)') AS TELEPHONE1,
				t.n.value('(E_MAIL)[1]','varchar(500)') AS E_MAIL,
				t.n.value('(POSTL_COD1)[1]','varchar(500)') AS POSTL_COD1,
				t.n.value('(YE1ADRM1_GLABS/STCD1)[1]','varchar(50)') AS STCD1,
				t.n.value('(NAME2)[1]','nvarchar(300)') AS NAME2
			FROM s.n.nodes('E1ADRM1') AS t(n)
			WHERE LTRIM(RTRIM(t.n.value('(PARTNER_Q)[1]','varchar(50)'))) = LTRIM(RTRIM(@AddressCode))
		) AS xa
		OUTER APPLY (
			SELECT 
				u.n.value('(PARTNER_ID)[1]','varchar(50)') AS PARTNER_ID,
				u.n.value('(NAME1)[1]','nvarchar(300)') AS NAME1,
				u.n.value('(COUNTRY1)[1]','nvarchar(3)') AS COUNTRY1,
				u.n.value('(CITY1)[1]','nvarchar(150)') AS CITY1,
				u.n.value('(STREET1)[1]','nvarchar(1000)') AS STREET1,
				u.n.value('(HOUSE_SUPL)[1]','nvarchar(1000)') AS HOUSE_SUPL,
				u.n.value('(TELEPHONE1)[1]','varchar(100)') AS TELEPHONE1,
				u.n.value('(E_MAIL)[1]','varchar(500)') AS E_MAIL,
				u.n.value('(POSTL_COD1)[1]','varchar(500)') AS POSTL_COD1,
				u.n.value('(YE1ADRM1_GLABS/STCD1)[1]','varchar(50)') AS STCD1
			FROM s.n.nodes('E1ADRM1') AS u(n)
			WHERE LTRIM(RTRIM(u.n.value('(PARTNER_Q)[1]','varchar(50)'))) = LTRIM(RTRIM(@OrganizerAddressCode))
		) AS ya
		WHERE z.n.value('(QUALF)[1]' ,'VARCHAR(50)') = @SAPAddressQualifier
		  AND b.n.value('(QUALF)[1]' ,'VARCHAR(50)') = @PickupQualifier


		
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
			--s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),-- Interim FIX
			s.n.value('(YE1EDL24_GLABS/LFIMG_PAL)[1]' ,'VARCHAR(100)'),  --PalletQty
			s.n.value('(E1EDL26/PSTYV)[1]' ,'VARCHAR(100)'),  --TaxCode
			ISNULL(s.n.value('(LICHN)[1]' ,'NVARCHAR(500)'),s.n.value('(CHARG)[1]' ,'NVARCHAR(500)')), --Comment	AS Batch Number, --Comment	
			s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),  --StockQty
			s.n.value('(NTGEW)[1]' ,'VARCHAR(100)'),  --Net Weight
			s.n.value('(BRGEW)[1]' ,'VARCHAR(100)'),  --Gross Weight
			s.n.value('(GEWEI)[1]' ,'VARCHAR(100)')  --Net Weight
		FROM @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as b(n)
		CROSS APPLY b.n.nodes('E1EDL24') AS s(n)
		CROSS APPLY s.n.nodes('E1EDL41') AS z(n)
		WHERE z.n.value('(QUALI)[1]' ,'VARCHAR(100)')='002'
		
		
		/*
		SELECT 'Track'
				SELECT
			@TransferID, --TransferID
			@ID, --TransportNo
			b.n.value('(VBELN)[1]' ,'VARCHAR(100)'), --DeliveryNo
			s.n.value('(POSNR)[1]' ,'VARCHAR(100)'),  --ItemNo
			s.n.value('(MATNR)[1]' ,'VARCHAR(100)'),  --ItemCode
			ISNULL(s.n.value('(YE1EDL24_GLABS/MAKTX_HU)[1]' ,'VARCHAR(300)'),s.n.value('(ARKTX)[1]' ,'VARCHAR(300)')),  --ItemName
			ISNULL(s.n.value('(VGBEL)[1]' ,'VARCHAR(100)'),''),  --OrderNo
			s.n.value('(LFIMG)[1]' ,'VARCHAR(100)'),  --Qty
			ISNULL(s.n.value('(VRKME)[1]' ,'VARCHAR(100)'),'PCS'),  --QtyUnit
			s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)') AS PAlletQty,  --StockQty
			--s.n.value('(YE1EDL24_GLABS/LFIMG_PAL)[1]' ,'VARCHAR(100)'),  --PalletQty
			s.n.value('(E1EDL26/PSTYV)[1]' ,'VARCHAR(100)'),  --TaxCode
			s.n.value('(CHARG)[1]' ,'NVARCHAR(500)'), --Comment	
			s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),  --StockQty
			s.n.value('(NTGEW)[1]' ,'VARCHAR(100)'),  --Net Weight
			s.n.value('(BRGEW)[1]' ,'VARCHAR(100)'),  --Gross Weight
			s.n.value('(GEWEI)[1]' ,'VARCHAR(100)')  --Net Weight
			--CAST(s.n.value('(NTGEW)[1]' ,'VARCHAR(100)') AS NUMERIC(8,3)) AS CASTNETWT,
			--CAST(s.n.value('(BRGEW)[1]' ,'VARCHAR(100)') AS NUMERIC(8,3)) AS CATGRWT  --Gross Weight

		from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as b(n)
		CROSS APPLY b.n.nodes('E1EDL24') AS s(n)
		WHERE NOT EXISTS(SELECT * FROM @QS qs WHERE qs.DeliveryNo=b.n.value('(VBELN)[1]' ,'VARCHAR(100)') AND qs.Pos=s.n.value('(POSNR)[1]' ,'VARCHAR(100)'))
		*/

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
				   ,[WeightUnit]
				   ,[BatchFlg])
		SELECT
			@TransferID, --TransferID
			@ID, --TransportNo
			b.n.value('(VBELN)[1]' ,'VARCHAR(100)'), --DeliveryNo
			s.n.value('(POSNR)[1]' ,'VARCHAR(100)'),  --ItemNo
			s.n.value('(MATNR)[1]' ,'VARCHAR(100)'),  --ItemCode
			ISNULL(s.n.value('(YE1EDL24_GLABS/MAKTX_HU)[1]' ,'VARCHAR(300)'),s.n.value('(ARKTX)[1]' ,'VARCHAR(300)')),  --ItemName
			ISNULL(s.n.value('(VGBEL)[1]' ,'VARCHAR(100)'),''),  --OrderNo
			s.n.value('(LFIMG)[1]' ,'VARCHAR(100)'),  --Qty
			ISNULL(s.n.value('(VRKME)[1]' ,'VARCHAR(100)'),'PCS'),  --QtyUnit
			--s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),-- Interim FIX
			s.n.value('(YE1EDL24_GLABS/LFIMG_PAL)[1]' ,'VARCHAR(100)'),  --PalletQty
			s.n.value('(E1EDL26/PSTYV)[1]' ,'VARCHAR(100)'),  --TaxCode
			ISNULL(s.n.value('(LICHN)[1]' ,'NVARCHAR(500)'),s.n.value('(CHARG)[1]' ,'NVARCHAR(500)')), --Comment	AS Batch Number
			s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),  --StockQty
			REPLACE(s.n.value('(NTGEW)[1]' ,'VARCHAR(100)'),',','.'),  --Net Weight
			REPLACE(s.n.value('(BRGEW)[1]' ,'VARCHAR(100)'),',','.'),  --Gross Weight
			s.n.value('(GEWEI)[1]' ,'VARCHAR(100)'),  --Net Weight
			s.n.value('(HIEVW)[1]' ,'VARCHAR(10)') --Comment	
		from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as b(n)
		CROSS APPLY b.n.nodes('E1EDL24') AS s(n)
		WHERE NOT EXISTS(SELECT * FROM @QS qs WHERE qs.DeliveryNo=b.n.value('(VBELN)[1]' ,'VARCHAR(100)') AND qs.Pos=s.n.value('(POSNR)[1]' ,'VARCHAR(100)'))
	
		--Delete where Qty = 0
		DELETE it
		FROM [dbo].[tblTransferTransportDeliveryItem] it
		WHERE it.TransferID=@TransferID AND it.Qty=0

		--DELETE Tax items, only Pal exchange allowed
		DELETE it
		FROM [dbo].[tblTransferTransportDeliveryItem] it
		WHERE it.TaxCode='TAX' AND it.ItemCode<>'80000036'

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
		

		SELECT 'Stages comes'
		DECLARE @SiteCode VARCHAR(10)
		SELECT TOP 1 @SiteCode=tt.PlantCode FROM [dbo].[tblTransferTransport]  tt WHERE tt.TransferID=@TransferID

		SELECT @SiteCode AS SiteCode

		INSERT INTO @Stage
		SELECT 
				@InOut, --Direction
				s.n.value('(TSNUM)[1]' ,'VARCHAR(100)'),	--StageNo
				x.n.value('(VBELN)[1]' ,'VARCHAR(100)'),	--DeliveryNo
				ISNULL(z.n.value('(ADRNR)[1]' ,'VARCHAR(100)'),''), --AddressNo
				ISNULL(ISNULL(z.n.value('(KUNNR)[1]' ,'VARCHAR(100)'),z.n.value('(VSTEL)[1]' ,'VARCHAR(100)')),s.n.value('(E1EDT44/LIFNR)[1]' ,'VARCHAR(100)')), --PartnerCode
				z.n.value('(E1ADRM6/NAME1)[1]' ,'NVARCHAR(300)'), --PartnerName
				z.n.value('(E1ADRM6/COUNTRY1)[1]' ,'NVARCHAR(3)'), --PartnerCountry
				z.n.value('(E1ADRM6/CITY1)[1]' ,'NVARCHAR(150)'), --PartnerCity
				z.n.value('(E1ADRM6/STREET1)[1]' ,'NVARCHAR(150)'), --PartnerAddress
				z.n.value('(E1ADRM6/TELEPHONE1)[1]' ,'VARCHAR(100)'), --PartnerPhone??
				z.n.value('(E1ADRM6/E_MAIL)[1]' ,'VARCHAR(500)'), --PartnerMail??
				z.n.value('(E1ADRM6/POSTL_COD1)[1]' ,'VARCHAR(500)') --PartnerZIP??
			from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDK33') as s(n)
			CROSS APPLY s.n.nodes('E1EDT01') as x(n)
			CROSS APPLY s.n.nodes('E1EDT44') as z(n)
			
			SELECT * FROM @Stage
			
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
						CASE @InOut WHEN 1 
						THEN (SELECT TOP 1 cp.WHCode FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerCode END,
						CASE @InOut WHEN 1 
						THEN (SELECT TOP 1 cp.WHName FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerName END,
						CASE @InOut WHEN 1 
						THEN (SELECT TOP 1 cp.WHCountry FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerCountry END,
						CASE @InOut WHEN 1 
						THEN (SELECT TOP 1 cp.WHCity FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerCity END,
						CASE @InOut WHEN 1 
						THEN (SELECT TOP 1 cp.WHAddress FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerAddress END,
						CASE @InOut WHEN 1 
						THEN (SELECT TOP 1 cp.WHPhone FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerPhone END,
						CASE @InOut WHEN 1 
						THEN (SELECT TOP 1 cp.WHMail FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerMail END,
						CASE @InOut WHEN 1 
						THEN (SELECT TOP 1 cp.WHZIP FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerZIP END,
						CASE @InOut WHEN 0 
						THEN (SELECT TOP 1 cp.WHCode FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerCode END,
						CASE @InOut WHEN 0 
						THEN (SELECT TOP 1 cp.WHName FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerName END,
						CASE @InOut WHEN 0 
						THEN (SELECT TOP 1 cp.WHCountry FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerCountry END,
						CASE @InOut WHEN 0 
						THEN (SELECT TOP 1 cp.WHCity FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerCity END,
						CASE @InOut WHEN 0 
						THEN (SELECT TOP 1 cp.WHAddress FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerAddress END,
						CASE @InOut WHEN 0 
						THEN (SELECT TOP 1 cp.WHPhone FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerPhone END,
						CASE @InOut WHEN 0 
						THEN (SELECT TOP 1 cp.WHMail FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerMail END,
						CASE @InOut WHEN 0 
						THEN (SELECT TOP 1 cp.WHZIP FROM tblClientParams cp WHERE SiteCode=@SiteCode) 
						ELSE PartnerZIP END
					FROM @Stage st
					--WHERE st.Direction=0

					----FOR S4 LET'S TURN OFF STAGING LOGIC!!!!!   START

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

			----FOR S4 LET'S TURN OFF STAGING LOGIC!!!!!   END


			--Define Organizer
			DECLARE @SelfOrganized BIT

			SELECT @SelfOrganized=	[dbo].[fnGetShipmentOrganizer](ttt.ShipmentType) FROM tblTransferTransport ttt WHERE TransferID=@TransferID

			IF(@SelfOrganized=0)
			BEGIN
				UPDATE tt
				SET OrganizerCode=ISNULL(ttd.OrganizerCode,tt.CarrierCode), tt.OrganizerAddress=ISNULL(ttd.OrganizerAddress,tt.CarrierAddress), tt.OrganizerCity=ISNULL(ttd.OrganizerCity, tt.CarrierCity),tt.OrganizerCountryCode=ISNULL(ttd.OrganizerCountryCode,tt.CountryCode),
				tt.OrganizerMail=ISNULL(ttd.OrganizerMail,tt.CarrierMail),	tt.OrganizerName=ISNULL(ttd.OrganizerName,tt.CarrierName), tt.OrganizerPhone=ISNULL(ttd.OrganizerPhone,tt.CarrierPhone), tt.OrganizerZIP=ISNULL(ttd.OrganizerZIP,tt.CarrierZIP),tt.OrganizerTaxID=ISNULL(ttd.OrganizerTaxID,tt.CarrierTaxID)
				FROM [dbo].[tblTransferTransport] tt
				INNER JOIN [dbo].[tblTransferTransportDelivery] ttd ON ttd.TransportID=tt.id
				WHERE ttd.id=(SELECT MIN(ttd2.id) FROM [dbo].[tblTransferTransportDelivery] ttd2 WHERE ttd2.TransferID=@TransferID) --AND ttd2.OrganizerCode IS NOT NULL)
				AND tt.TransferID=@TransferID
			END
		

		--TURN ON 'LHU01' AND 'LRO01' FOR S4 START
		
		UPDATE tdd
		SET tdd.StageNo=st.StageNo, tdd.PartnerCode=CASE WHEN tdd.PartnerCode IN('CLHU01','CLRO01') THEN st.AddressNo ELSE tdd.PartnerCode END
		FROM [dbo].[tblTransferTransportDelivery] tdd 
		INNER JOIN [dbo].[tblTransferTransportStage] st ON st.DeliveryNo=tdd.DeliveryNo AND st.TransferID=tdd.TransferID
		WHERE tdd.TransferID=@TransferID
		
        --Define Real Site Code
		--TURN ON 'LHU01' AND 'LRO01' FOR S4 END


		--SITE LOGIC TURN OFF FOR S4 START
		/*
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
		*/
		--SITE LOGIC TURN OFF FOR S4 END


		--TURN OFF SPECIAL LOGICS FOR S4 START
		/*
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
		*/
		--TURN OFF SPECIAL LOGICS FOR S4 END


		--LHU001 logic

		UPDATE tblTransferIn
		SET FileType=1, LoadFlg=1
		WHERE id=@TransferID
	END

	SET @Msg='Success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,TransportNo,ProcessID,TransferIn)
	SELECT 'spLoadSAPFilevS4','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,1,@TransportNo,1,@TransferID
	
	SET @SuccessFlg=1
END
END TRY
BEGIN CATCH
	UPDATE tblTransferIn
	SET LoadFlg=0
	WHERE id=@TransferID


	SELECT ERROR_NUMBER() AS ErrorNumber,
    ERROR_SEVERITY() AS ErrorSeverity,
    ERROR_STATE() AS ErrorState,
    ERROR_PROCEDURE() AS ErrorProcedure,
    ERROR_LINE() AS ErrorLine,
    ERROR_MESSAGE() AS ErrorMessage;
	SELECT @Msg=ERROR_MESSAGE()
	--SET @Msg='SAP Load failure'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg,TransportNo,ProcessID,TransferIn)
	SELECT 'spLoadSAPFilevS4','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,@TransportNo,1,@TransferID

	SET @SuccessFlg=0
END CATCH
END
GO
