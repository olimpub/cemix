/*
====================================================================================================
CEMIX UNIFIED DEPLOYMENT PACKAGE: S/4HANA Item Aggregation, Multi-Batch Formatting, Pallet Code & Cleanup
====================================================================================================
Tartalom (minden egyetlen SQL scriptben):
  1. tblXrefExceptions: Raklapkódok (80000036, K00890000) regisztrációja.
  2. spLoadSAPFilevS4:
     - Élő szerver XQuery komment-összefűzés (E1TXTP8/TDLINE/text()).
     - BatchFlg (HIEVW) és súly tizedesvessző-pont csere pótlása az 1. E1EDL24 INSERT blokkban (QUALI='002').
     - BatchFlg = 'X' átörökítése az altételekre a Qty = 0 főtételek törlése előtt.
  3. spLoadTransportToMWv234 (v1.10):
     - Cikkszám szintű tételösszevonás (DeliveryNo x ItemCode).
     - Több batch + mennyiség összefűzése: Batch1(Qty1), Batch2(Qty2), No Batch(Qty3).
     - BatchFlg = 1 automatikus beállítása, ha HIEVW = 'X' vagy bármelyik altételen van batch szám.
     - Meglévő ItemNo megtartása frissítéskor, új tételeknél 10-es lépésközű ItemNo generálás.
     - Duplikáció-megelőzés és NULL-biztos változásfigyelés.
  4. spCreateCargoItemBodyv223:
     - GLABs megjegyzés formázás: Batch:B1(10), No Batch(5) | Súly:1500 kg.
     - Zárolás (pickingLocked = 1, loadingLocked = 1), amíg BatchFlg = 1 és bármelyik altételhez
       még nincs batch rendelve ('No Batch(...)' vagy üres).
  5. Diagnosztika és opcionális konszolidáció a már nyitott fuvarok esetleges duplikált tételeire.

Verzió: v1.12
Dátum / Időbélyeg: 2026-10-21 20:53
====================================================================================================
*/

-- USE [Middleware_prod]; -- vagy a cel adatbazis neve
-- GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =================================================================================================
-- 1. LÉPÉS: Raklapkódok rögzítése az X-Ref táblában (ha még nem léteznének)
-- =================================================================================================
IF NOT EXISTS (SELECT 1 FROM tblXrefExceptions WHERE ExType = 'PalletItemCode' AND ExValue = '80000036')
BEGIN
    INSERT INTO tblXrefExceptions (ExType, ExValue) VALUES ('PalletItemCode', '80000036');
    PRINT 'PalletItemCode 80000036 hozzaadva a tblXrefExceptions tablahoz.';
END
ELSE
BEGIN
    PRINT 'PalletItemCode 80000036 mar letezik a tblXrefExceptions tablaban.';
END
GO

IF NOT EXISTS (SELECT 1 FROM tblXrefExceptions WHERE ExType = 'PalletItemCode' AND ExValue = 'K00890000')
BEGIN
    INSERT INTO tblXrefExceptions (ExType, ExValue) VALUES ('PalletItemCode', 'K00890000');
    PRINT 'PalletItemCode K00890000 hozzaadva a tblXrefExceptions tablahoz.';
END
ELSE
BEGIN
    PRINT 'PalletItemCode K00890000 mar letezik a tblXrefExceptions tablaban.';
END
GO

-- =================================================================================================
-- 2. LÉPÉS: spLoadSAPFilevS4 frissítése
-- =================================================================================================
PRINT 'Deploying spLoadSAPFilevS4...'
GO

/****** Object:  StoredProcedure [dbo].[spLoadSAPFilevS4]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







CREATE OR ALTER PROCEDURE [dbo].[spLoadSAPFilevS4](
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
				   ,[WeightUnit]
				   ,[BatchFlg])
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
			ISNULL(NULLIF(LTRIM(RTRIM(s.n.value('(LICHN)[1]' ,'NVARCHAR(500)'))),''),LTRIM(RTRIM(s.n.value('(CHARG)[1]' ,'NVARCHAR(500)')))), --Comment	AS Batch Number, --Comment	
			s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),  --StockQty
			REPLACE(s.n.value('(NTGEW)[1]' ,'VARCHAR(100)'),',','.'),  --Net Weight
			REPLACE(s.n.value('(BRGEW)[1]' ,'VARCHAR(100)'),',','.'),  --Gross Weight
			s.n.value('(GEWEI)[1]' ,'VARCHAR(100)'),  --Net Weight
			s.n.value('(HIEVW)[1]' ,'VARCHAR(10)') --BatchFlg
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
			ISNULL(NULLIF(LTRIM(RTRIM(s.n.value('(LICHN)[1]' ,'NVARCHAR(500)'))),''),LTRIM(RTRIM(s.n.value('(CHARG)[1]' ,'NVARCHAR(500)')))), --Comment	AS Batch Number
			s.n.value('(YE1EDL24_GLABS/LABST_VRKME)[1]' ,'VARCHAR(100)'),  --StockQty
			REPLACE(s.n.value('(NTGEW)[1]' ,'VARCHAR(100)'),',','.'),  --Net Weight
			REPLACE(s.n.value('(BRGEW)[1]' ,'VARCHAR(100)'),',','.'),  --Gross Weight
			s.n.value('(GEWEI)[1]' ,'VARCHAR(100)'),  --Net Weight
			s.n.value('(HIEVW)[1]' ,'VARCHAR(10)') --Comment	
		from @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') as b(n)
		CROSS APPLY b.n.nodes('E1EDL24') AS s(n)
		WHERE NOT EXISTS(SELECT * FROM @QS qs WHERE qs.DeliveryNo=b.n.value('(VBELN)[1]' ,'VARCHAR(100)') AND qs.Pos=s.n.value('(POSNR)[1]' ,'VARCHAR(100)'))
	
		-- Propagate BatchFlg = 'X' from header item (Qty = 0) or sibling sub-items before deleting Qty = 0 rows
		UPDATE it
		SET it.BatchFlg = 'X'
		FROM [dbo].[tblTransferTransportDeliveryItem] it
		WHERE it.TransferID = @TransferID
		  AND ISNULL(it.BatchFlg, '') <> 'X'
		  AND EXISTS (
			SELECT 1
			FROM [dbo].[tblTransferTransportDeliveryItem] it0
			WHERE it0.TransferID = @TransferID
			  AND it0.DeliveryNo = it.DeliveryNo
			  AND it0.ItemCode = it.ItemCode
			  AND (it0.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(it0.Comment, ''))) <> '')
		  )

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
				s.n.value('(VBELN)[1]', 'VARCHAR(100)') AS DeliveryNo,
				z.n.value('(TDID)[1]', 'VARCHAR(100)')  AS TDID,
				LTRIM(RTRIM(z.n.query('
					for $line in E1TXTP8/TDLINE/text()
					return concat($line, " ")
				').value('.', 'VARCHAR(MAX)'))) AS Comment
			FROM @XML.nodes('/YYSHPMNT06_GLABS/IDOC/E1EDT20/E1EDL20') AS s(n)
			CROSS APPLY s.n.nodes('E1TXTH8') AS z(n);

		
			--Update comment form multiple rows
			UPDATE ttd
			SET ttd.Comment=cc.Comment
			FROM tblTransferTransportDelivery ttd INNER JOIN @Comments cc ON cc.DeliveryNo=ttd.DeliveryNo
			
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


PRINT 'spLoadSAPFilevS4 successfully updated.'
GO

-- =================================================================================================
-- 3. LÉPÉS: spLoadTransportToMWv234 (v1.10) frissítése
-- =================================================================================================
PRINT 'Deploying spLoadTransportToMWv234 v1.10...'
GO

/****** Object:  StoredProcedure [dbo].[spLoadTransportToMWv234]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








CREATE OR ALTER PROCEDURE [dbo].[spLoadTransportToMWv234](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
/*
Version 1.09

1.01	:		Changed by Daniel Bakos, add SAPTemplateID to tblShipment on 2023/02/19
1.02	:		Changed by Daniel Bakos, add PalletGrouping logic on 2023/12/12
1.03	:		Changed by Daniel Bakos, to fix PalletGrouping logic not use TOP 1 on 2024/02/23
1.04	:		Changed by Daniel Bakos, fix merge transport addition, if transport is not loaded tt GLABs yet on 2025/02/09
1.05	:		Changed by Daniel Bakos, same itemno but different item code fix yet on 2025/03/25
1.06	:		Changed by Daniel Bakos, new version of pallet grouping logic 2025/05/16
1.07	:		Changed by Daniel Bakos, intercompany unload sap write back logic implementation 2026/01/14
1.08	:		Changed by Daniel Bakos, add BatchNo 2026/04/28
1.09	:		Changed by Daniel Bakos, change intercompany shipment rule logic on 2026/05/05
1.10	:		Changed by Antigravity AI, aggregate items by DeliveryNo and ItemCode, reuse existing ItemNo on update or generate synthetic stepped ItemNo for new items, update pallet code to 80000036 on 2026/10/15
*/
AS
BEGIN

DECLARE @Msg NVARCHAR(MAX), @SourceFlg BIT, @TransportNo VARCHAR(30),@InterCompanyCnt INT
SET @SourceFlg=NULL

IF EXISTS(SELECT * FROM [dbo].[tblTransferTransport] ttd 
	WHERE ttd.TransferID=@TransferID)
BEGIN
	SET @SourceFlg=1
END
ELSE
BEGIN 
	IF EXISTS(SELECT * FROM [dbo].[tblTransferTransportArchive] ttd 
	WHERE ttd.TransferID=@TransferID)
	BEGIN
		SET @SourceFlg=0
	END
END



IF(@SourceFlg IS NULL)
BEGIN
	SET @SuccessFlg=0
	RETURN;
END



BEGIN TRY
 --Define Intercompany logic
DECLARE @Intercompany TABLE(
	PartnerCode VARCHAR(50),
	SiteCode VARCHAR(10)
)
IF(@SourceFlg=1)
BEGIN
	INSERT INTO @Intercompany(PartnerCode)
	SELECT ts.PartnerCodeFrom FROM tblTransferTransportStage ts
	WHERE ts.TransferID=@TransferID
	UNION
	SELECT ts.PartnerCodeTo FROM tblTransferTransportStage ts
	WHERE ts.TransferID=@TransferID
END
ELSE
BEGIN
	INSERT INTO @Intercompany(PartnerCode)
	SELECT ts.PartnerCodeFrom FROM tblTransferTransportStageArchive ts
	WHERE ts.TransferID=@TransferID
	UNION
	SELECT ts.PartnerCodeTo FROM tblTransferTransportStageArchive ts
	WHERE ts.TransferID=@TransferID
END


UPDATE s
SET s.SiteCode=cp.SiteCode
FROM @Intercompany s INNER JOIN tblClientParams cp
ON s.PartnerCode=cp.SiteCode

UPDATE s
SET s.SiteCode=cp.SiteCode
FROM @Intercompany s INNER JOIN tblClientParams cp
ON s.PartnerCode=cp.WHCode
WHERE s.SiteCode IS NULL

SELECT @InterCompanyCnt=COUNT(DISTINCT SiteCode) FROm @Intercompany

DECLARE @tblTransport TABLE(
	[TransportNo] [varchar](100) NOT NULL,
	[GLABsID] [varchar](50) NULL,
	[CarrierID] [varchar](50) NULL,
	[SelfOrganized] [bit] NULL,
	[SiteCode] [varchar](10) NULL,
	[LicensePlate1] [varchar](20) NULL,
	[LicensePlate2] [varchar](20) NULL,
	[DelegateFlg] [bit] NULL,
	[DriverName] [nvarchar](200) NULL,
	[DriverPhone] [varchar](60) NULL,
	[OrganizerID] [varchar](50) NULL,
	[MergeTransportNo] [varchar](100) NULL

)
	IF(@SourceFlg=1)
	BEGIN
		INSERT INTO @tblTransport(
				[TransportNo],
				[CarrierID], 
				[SelfOrganized],
				[SiteCode],
				[LicensePlate1],
				[LicensePlate2],
				[DelegateFlg],
				[DriverName],
				[DriverPhone],
				[OrganizerID],
				[MergeTransportNo]
		)
		SELECT 
				ttd.TransportNo, --TransportNo
				[dbo].[fnGetCarrierCode](ttd.CarrierCode,ttd.PlantCode), --CarrierID
				[dbo].[fnGetShipmentOrganizer](ttd.ShipmentType),  --SelfOrganized
				ttd.PlantCode, --SiteCode
				[dbo].[fnCleanLicensePlate](ttd.LicensePlate1),
				[dbo].[fnCleanLicensePlate](ttd.LicensePlate2),
				NULL, --DelegateFlg
				ttd.DriverName, --DriverName
				ttd.DriverPhone, --DriverPhone
				[dbo].[fnGetCarrierCode](ttd.OrganizerCode,ttd.PlantCode), --OrganizerID
				ttd.TransportNo2 --CASE WHEN LEFT(ttd.TransportNo2,2)='00' THEN ttd.TransportNo2 ELSE '00'+ttd.TransportNo2 END --MergeTransportNo
		FROM [dbo].[tblTransferTransport] ttd 
		WHERE ttd.TransferID=@TransferID
	END
	ELSE
	BEGIN
			INSERT INTO @tblTransport(
			[TransportNo],
			[CarrierID], 
			[SelfOrganized],
			[SiteCode],
			[LicensePlate1],
			[LicensePlate2],
			[DelegateFlg],
			[DriverPhone],
			[OrganizerID],
			[MergeTransportNo]
			)
			SELECT 
				ttd.TransportNo, --TransportNo
				[dbo].[fnGetCarrierCode](ttd.CarrierCode,ttd.PlantCode), --CarrierID
				[dbo].[fnGetShipmentOrganizer](ttd.ShipmentType),  --SelfOrganized
				ttd.PlantCode, --SiteCode
				[dbo].[fnCleanLicensePlate](ttd.LicensePlate1),
				[dbo].[fnCleanLicensePlate](ttd.LicensePlate2),
				NULL, --DelegateFlg
				NULL, --DriverPhone
				[dbo].[fnGetCarrierCode](ttd.OrganizerCode,ttd.PlantCode), --OrganizerID
				ttd.TransportNo2 --   CASE WHEN LEFT(ttd.TransportNo2,2)='00' THEN ttd.TransportNo2 ELSE '00'+ttd.TransportNo2 END --MergeTransportNo
			FROM [dbo].[tblTransferTransportArchive] ttd 
			WHERE ttd.TransferID=@TransferID
	END
	--Load to table variable
	DECLARE @tblShipment TABLE(
	[TransportID] [varchar](100) NOT NULL,
	[Priority] [varchar](50) NULL,
	[ShipmentRule] [varchar] (50) NULL,  --Needs for included
	[PickupDate] [varchar] (20) NULL,
	[SiteCode] [varchar] (10) NULL,
	[SAPTemplateID] [int] NULL
	) 

	DECLARE @Sites TABLE(
		SiteCode VARCHAR(10) 
	)
	IF(@SourceFlg=1)
	BEGIN
		INSERT INTO @Sites
		SELECT 
			DISTINCT ttd.SiteID	
		FROM [dbo].[tblTransferTransportDelivery] ttd 
			WHERE ttd.TransferID=@TransferID
		UNION
		SELECT 
			ISNULL(tc.SiteCode,tc2.SiteCode)
		FROm [dbo].[tblTransferTransportDelivery] ttd 
		LEFT OUTER JOIN tblClientParams tc ON tc.SiteCode=ttd.PartnerCode AND tc.ActiveFlg=1
		LEFT OUTER JOIN tblClientParams tc2 ON tc2.WHCode=ttd.PartnerCode AND  tc2.ActiveFlg=1
			WHERE ttd.TransferID=@TransferID

		INSERT INTO @tblShipment(
			TransportID,
			Priority,
			ShipmentRule,
			PickupDate,
			SiteCode,
			SAPTemplateID
		)
		SELECT 
			ttt.TransportNo,
			[dbo].[fnGetServiceLevel](ttt.[Priority],ss.SiteCode),
			CASE WHEN @InterCompanyCnt>1 THEN [dbo].[fnGetIntercompanyShipmentRule](ttt.ShipmentType,SiteCode) ELSE [dbo].[fnGetShipmentRule](ttt.ShipmentType,SiteCode) END,
			[dbo].[fnGetLatestPickupDate](@TransferID,SiteCode),
			ss.SiteCode,
			CASE WHEN @InterCompanyCnt>1 AND ttt.[PlantCode]= ss.SiteCode THEN  [dbo].[fnGetSAPTemplateID](ttt.ShipmentType,SiteCode)
				 WHEN @InterCompanyCnt>1 AND ttt.[PlantCode]<> ss.SiteCode THEN  (SELECT sst.id FROM [dbo].[tblShipmentStatusTemplate] sst WHERE sst.InterCompanyUnloadFlg=1)
				 ELSE [dbo].[fnGetSAPTemplateID](ttt.ShipmentType,SiteCode)
				 END
		FROM tblTransferTransport ttt 
		CROSS APPLY @Sites ss
		WHERE ttt.TransferID=@TransferID AND ss.SiteCode IS NOT NULL
	END
	ELSE
	BEGIN
		INSERT INTO @Sites
		SELECT 
			DISTINCT ttd.SiteID	
		FROM [dbo].[tblTransferTransportDeliveryArchive] ttd 
			WHERE ttd.TransferID=@TransferID
		UNION
		SELECT 
			ISNULL(tc.SiteCode,tc2.SiteCode)
		FROm [dbo].[tblTransferTransportDeliveryArchive] ttd 
		LEFT OUTER JOIN tblClientParams tc ON tc.SiteCode=ttd.PartnerCode AND tc.ActiveFlg=1
		LEFT OUTER JOIN tblClientParams tc2 ON tc2.WHCode=ttd.PartnerCode AND  tc2.ActiveFlg=1
			WHERE ttd.TransferID=@TransferID

		INSERT INTO @tblShipment(
			TransportID,
			Priority,
			ShipmentRule,
			PickupDate,
			SiteCode,
			SAPTemplateID
		)		
		SELECT 
			ttt.TransportNo,
			[dbo].[fnGetServiceLevel](ttt.[Priority],ss.SiteCode),
			CASE WHEN @InterCompanyCnt>1 THEN [dbo].[fnGetIntercompanyShipmentRule](ttt.ShipmentType,SiteCode) ELSE [dbo].[fnGetShipmentRule](ttt.ShipmentType,SiteCode) END,
			[dbo].[fnGetLatestPickupDate](@TransferID,SiteCode),
			ss.SiteCode,
			CASE WHEN @InterCompanyCnt>1 AND ttt.[PlantCode]= ss.SiteCode THEN  [dbo].[fnGetSAPTemplateID](ttt.ShipmentType,SiteCode)
				 WHEN @InterCompanyCnt>1 AND ttt.[PlantCode]<> ss.SiteCode THEN  (SELECT sst.id FROM [dbo].[tblShipmentStatusTemplate] sst WHERE sst.InterCompanyUnloadFlg=1)
				 ELSE [dbo].[fnGetSAPTemplateID](ttt.ShipmentType,SiteCode)
				 END
		FROM tblTransferTransportArchive ttt 
		CROSS APPLY @Sites ss
		WHERE ttt.TransferID=@TransferID AND ss.SiteCode IS NOT NULL
	END

		DECLARE @tblCargo TABLE(
		[DeliveryNo] [varchar](100) NOT NULL,
		[Weight] [numeric](12,2) NOT NULL,
		[Colli] [smallint] NOT NULL,
		[Comment] [nvarchar](500) NULL,
		[DeliveryDate] [varchar](20),
		[PickupDate] [varchar](20),
		[SourceSideCode] [varchar](15),
		[SourcePartnerID] [varchar](50),
		[DestinationSideCode] [varchar](15),
		[DestinationPartnerID] [varchar](50),
		[ContactInfo] [nvarchar](300) NULL,
		[ContactPhone] [varchar](500) NULL,
		[Direction] [bit] NULL,
		[StageNo] [nvarchar](300) NULL
		)
		/*
		SELECT
			ttd.DeliveryNo,
			ttd.Weight,
			0, --Caluclate later on
			ttd.Comment,
			[dbo].[fnConvertToDate](ttd.DeliveryDate),
			[dbo].[fnConvertToDatetime](ttd.PickupDate),
			CASE ttd.Direction WHEN 1 THEN ttd.SiteID ELSE [dbo].[fnGetSiteCode](ttd.PartnerCode) END,
			CASE ttd.Direction WHEN 1 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			CASE ttd.Direction WHEN 0 THEN ttd.SiteID ELSE [dbo].[fnGetSiteCode](ttd.PartnerCode) END,
			CASE ttd.Direction WHEN 0 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			ttd.ContactInfo,
			ttd.PartnerPhone,
			ttd.Direction,
			ttd.StageNo
		FROM tblTransferTransportDelivery ttd 
		INNER JOIN tblTransferTransport tt ON tt.TransferID=ttd.TransferID
		WHERE ttd.TransferID=@TransferID
		*/

	IF(@SourceFlg=1)
	BEGIN
		INSERT INTO @tblCargo(
			[DeliveryNo],
			[Weight],
			[Colli],
			[Comment],
			[DeliveryDate],
			[PickupDate],
			[SourceSideCode],
			[SourcePartnerID],
			[DestinationSideCode],
			[DestinationPartnerID],
			[ContactInfo],
			[ContactPhone],
			[Direction],
			[StageNo]
		)
		SELECT
			ttd.DeliveryNo,
			ttd.Weight,
			0, --Caluclate later on
			ttd.Comment,
			[dbo].[fnConvertToDate](ttd.DeliveryDate),
			[dbo].[fnConvertToDatetime](ttd.PickupDate),
			CASE ttd.Direction WHEN 1 THEN ttd.SiteID ELSE [dbo].[fnGetSiteCode](ttd.PartnerCode) END,
			CASE ttd.Direction WHEN 1 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			CASE ttd.Direction WHEN 0 THEN ttd.SiteID ELSE [dbo].[fnGetSiteCode](ttd.PartnerCode) END,
			CASE ttd.Direction WHEN 0 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			ttd.ContactInfo,
			ttd.PartnerPhone,
			ttd.Direction,
			ttd.StageNo
		FROM tblTransferTransportDelivery ttd 
		INNER JOIN tblTransferTransport tt ON tt.TransferID=ttd.TransferID
		WHERE ttd.TransferID=@TransferID
	END
	ELSE 
	BEGIN
		INSERT INTO @tblCargo(
			[DeliveryNo],
			[Weight],
			[Colli],
			[Comment],
			[DeliveryDate],
			[PickupDate],
			[SourceSideCode],
			[SourcePartnerID],
			[DestinationSideCode],
			[DestinationPartnerID],
			[ContactInfo],
			[ContactPhone],
			[Direction],
			[StageNo]
		)
		SELECT
			ttd.DeliveryNo,
			ttd.Weight,
			0, --Caluclate later on
			ttd.Comment,
			[dbo].[fnConvertToDate](ttd.DeliveryDate),
			[dbo].[fnConvertToDatetime](ttd.PickupDate),
			ttd.SiteID,
			CASE ttd.Direction WHEN 1 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			[dbo].[fnGetSiteCode](ttd.PartnerCode),
			CASE ttd.Direction WHEN 0 THEN [dbo].[fnGetSiteID](tt.PlantCode) ELSE [dbo].[fnGetPartnerCode](ttd.PartnerCode,ttd.SiteID) END,
			ttd.ContactInfo,
			ttd.PartnerPhone,
			ttd.Direction,
			ttd.StageNo
		FROM tblTransferTransportDeliveryArchive ttd 
		INNER JOIN tblTransferTransportArchive tt ON tt.TransferID=ttd.TransferID
		WHERE ttd.TransferID=@TransferID
	END

	--Just because of Pallet logic
	UPDATE @tblCargo
	SET DestinationSideCode=CASE Direction WHEN 0 THEN DestinationSideCode ELSE NULL END,
	SourceSideCode=CASE Direction WHEN 1 THEN SourceSideCode ELSE NULL END
	WHERE SourceSideCode=DestinationSideCode


	DECLARE @TransportID VARCHAR(50)
	SELECT TOP 1 @TransportID = TransportNo FROM @tblTransport

	-- Deduplicate existing tblCargoItem records if any duplicates exist for this transport
	;WITH Dups AS (
		SELECT 
			id, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
			ROW_NUMBER() OVER(
				PARTITION BY DeliveryNo, ItemCode 
				ORDER BY 
					CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
					CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
					id ASC
			) AS rn
		FROM tblCargoItem
		WHERE TransportID = @TransportID
	)
	DELETE FROM tblCargoItem
	WHERE id IN (
		SELECT id FROM Dups WHERE rn > 1 AND SourceGLABsID IS NULL
	);

	;WITH Dups AS (
		SELECT 
			id, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
			ROW_NUMBER() OVER(
				PARTITION BY DeliveryNo, ItemCode 
				ORDER BY 
					CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
					CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
					id ASC
			) AS rn
		FROM tblCargoItem
		WHERE TransportID = @TransportID
	)
	UPDATE tci
	SET tci.SourceStatus = -1, tci.DestinationStatus = -1
	FROM tblCargoItem tci
	INNER JOIN Dups d ON d.id = tci.id
	WHERE d.rn > 1 AND tci.SourceGLABsID IS NOT NULL AND tci.SourceStatus NOT IN (-1, 3);

	DECLARE @tblCargoItem TABLE(
		[DeliveryNo] [varchar](100) NOT NULL,
		[ItemNo] [varchar](10) NOT NULL,
		[ItemCode] [nvarchar](50) NOT NULL,
		[ItemName] [nvarchar](300) NOT NULL,
		[OrderNo] [varchar](100) NOT NULL,
		[Qty] [numeric](9,3) NOT NULL,
		[QtyUnit] [varchar](10) NOT NULL,
		[QtyUnitID] [varchar](50) NOT NULL,
		[PalletQty] [numeric](9,3) NULL,
		[PickingFlg] [bit] NULL,
		[Comment] [nvarchar](500)  NULL,
		[StockQty] [numeric](9,3) NULL,
		[NetWeight] [numeric](12,3) NULL,
		[GrossWeight] [numeric](12,3) NULL,
		[CopyFlg] [bit] NULL,
		[BatchFlg] [bit] NULL
	)

	DECLARE @tblCargoItemCopy TABLE(
		[DeliveryNo] [varchar](100) NOT NULL,
		[OldDeliveryNo] [varchar](100) NOT NULL,
		[ItemNo] [varchar](10) NOT NULL,
		[ItemCode] [nvarchar](50) NOT NULL,
		[ItemName] [nvarchar](300) NOT NULL,
		[OrderNo] [varchar](100) NOT NULL,
		[Qty] [numeric](9,3) NOT NULL,
		[QtyUnit] [varchar](10) NOT NULL,
		[QtyUnitID] [varchar](50) NOT NULL,
		[PalletQty] [numeric](9,3) NULL,
		[PickingFlg] [bit] NULL,
		[Comment] [nvarchar](500)  NULL,
		[StockQty] [numeric](9,3) NULL,
		[NetWeight] [numeric](12,3) NULL,
		[GrossWeight] [numeric](12,3) NULL,
		[CopyFlg] [bit] NULL,
		[BatchFlg] [bit] NULL
	)

	DECLARE @AggregatedDeliveryItems TABLE (
		[DeliveryNo] [varchar](100) NOT NULL,
		[ItemCode] [nvarchar](50) NOT NULL,
		[ItemName] [nvarchar](300) NOT NULL,
		[OrderNo] [varchar](100) NOT NULL,
		[Qty] [numeric](9,3) NOT NULL,
		[QtyUnit] [varchar](10) NOT NULL,
		[PalletQty] [numeric](9,3) NULL,
		[StockQty] [numeric](9,3) NULL,
		[NetWeight] [numeric](12,3) NULL,
		[GrossWeight] [numeric](12,3) NULL,
		[BatchFlg] [bit] NULL,
		[Comment] [nvarchar](500) NULL,
		[MinItemNo] [varchar](10) NULL
	)

	IF(@SourceFlg=1)
	BEGIN
		INSERT INTO @AggregatedDeliveryItems (
			DeliveryNo, ItemCode, ItemName, OrderNo, Qty, QtyUnit,
			PalletQty, StockQty, NetWeight, GrossWeight, BatchFlg, Comment, MinItemNo
		)
		SELECT 
			tdi.DeliveryNo,
			tdi.ItemCode,
			MAX(tdi.ItemName),
			MIN(tdi.OrderNo),
			SUM(tdi.Qty),
			MAX(tdi.QtyUnit),
			MAX(ISNULL(tdi.PalletQty, tdi.Qty)),
			MAX(ISNULL(tdi.StockQty, 0)),
			SUM(ISNULL(tdi.NetWeight, 0)),
			SUM(ISNULL(tdi.GrossWeight, 0)),
			MAX(CASE WHEN tdi.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(tdi.Comment, ''))) <> '' THEN 1 ELSE 0 END),
			CASE 
				WHEN MAX(CASE WHEN tdi.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(tdi.Comment, ''))) <> '' THEN 1 ELSE 0 END) = 1 THEN
					ISNULL(
						STUFF((
							SELECT ', ' + b.BatchName + '(' + FORMAT(b.BatchQty, '0.###') + ')'
							FROM (
								SELECT 
									CASE 
										WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 'No Batch'
										ELSE LTRIM(RTRIM(c.Comment))
									END AS BatchName,
									SUM(c.Qty) AS BatchQty,
									CASE WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 1 ELSE 0 END AS IsNoBatch,
									MIN(c.ItemNo) AS MinSubItemNo
								FROM tblTransferTransportDeliveryItem c
								WHERE c.TransferID = @TransferID 
								  AND c.DeliveryNo = tdi.DeliveryNo 
								  AND c.ItemCode = tdi.ItemCode 
								  AND c.Qty > 0
								GROUP BY 
									CASE 
										WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 'No Batch'
										ELSE LTRIM(RTRIM(c.Comment))
									END,
									CASE WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 1 ELSE 0 END
							) b
							ORDER BY b.IsNoBatch ASC, b.MinSubItemNo ASC
							FOR XML PATH(''), TYPE
						).value('.', 'NVARCHAR(MAX)'), 1, 2, ''),
						''
					)
				ELSE ''
			END,
			MIN(tdi.ItemNo)
		FROM tblTransferTransportDeliveryItem tdi
		WHERE tdi.TransferID = @TransferID
		  AND tdi.Qty > 0
		GROUP BY tdi.DeliveryNo, tdi.ItemCode
	END
	ELSE
	BEGIN
		INSERT INTO @AggregatedDeliveryItems (
			DeliveryNo, ItemCode, ItemName, OrderNo, Qty, QtyUnit,
			PalletQty, StockQty, NetWeight, GrossWeight, BatchFlg, Comment, MinItemNo
		)
		SELECT 
			tdi.DeliveryNo,
			tdi.ItemCode,
			MAX(tdi.ItemName),
			MIN(tdi.OrderNo),
			SUM(tdi.Qty),
			MAX(tdi.QtyUnit),
			MAX(ISNULL(tdi.PalletQty, tdi.Qty)),
			MAX(ISNULL(tdi.StockQty, 0)),
			SUM(ISNULL(tdi.NetWeight, 0)),
			SUM(ISNULL(tdi.GrossWeight, 0)),
			MAX(CASE WHEN tdi.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(tdi.Comment, ''))) <> '' THEN 1 ELSE 0 END),
			CASE 
				WHEN MAX(CASE WHEN tdi.BatchFlg = 'X' OR LTRIM(RTRIM(ISNULL(tdi.Comment, ''))) <> '' THEN 1 ELSE 0 END) = 1 THEN
					ISNULL(
						STUFF((
							SELECT ', ' + b.BatchName + '(' + FORMAT(b.BatchQty, '0.###') + ')'
							FROM (
								SELECT 
									CASE 
										WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 'No Batch'
										ELSE LTRIM(RTRIM(c.Comment))
									END AS BatchName,
									SUM(c.Qty) AS BatchQty,
									CASE WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 1 ELSE 0 END AS IsNoBatch,
									MIN(c.ItemNo) AS MinSubItemNo
								FROM tblTransferTransportDeliveryItemArchive c
								WHERE c.TransferID = @TransferID 
								  AND c.DeliveryNo = tdi.DeliveryNo 
								  AND c.ItemCode = tdi.ItemCode 
								  AND c.Qty > 0
								GROUP BY 
									CASE 
										WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 'No Batch'
										ELSE LTRIM(RTRIM(c.Comment))
									END,
									CASE WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 1 ELSE 0 END
							) b
							ORDER BY b.IsNoBatch ASC, b.MinSubItemNo ASC
							FOR XML PATH(''), TYPE
						).value('.', 'NVARCHAR(MAX)'), 1, 2, ''),
						''
					)
				ELSE ''
			END,
			MIN(tdi.ItemNo)
		FROM tblTransferTransportDeliveryItemArchive tdi
		WHERE tdi.TransferID = @TransferID
		  AND tdi.Qty > 0
		GROUP BY tdi.DeliveryNo, tdi.ItemCode
	END

	;WITH ItemMapping AS (
		SELECT 
			adi.DeliveryNo,
			adi.ItemCode,
			adi.ItemName,
			adi.OrderNo,
			adi.Qty,
			adi.QtyUnit,
			adi.PalletQty,
			adi.StockQty,
			adi.NetWeight,
			adi.GrossWeight,
			adi.BatchFlg,
			adi.Comment,
			adi.MinItemNo,
			ExistingItemNo = (
				SELECT TOP 1 tci.ItemNo 
				FROM tblCargoItem tci 
				WHERE tci.DeliveryNo = adi.DeliveryNo 
				  AND tci.ItemCode = adi.ItemCode 
				  AND tci.TransportID = @TransportID
				ORDER BY 
					CASE WHEN tci.SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
					CASE WHEN ISNULL(tci.SourceStatus, 0) NOT IN (-1, 3) THEN 0 ELSE 1 END,
					tci.id ASC
			),
			BaseNo = ISNULL((
				SELECT MAX(TRY_CAST(tci.ItemNo AS INT))
				FROM tblCargoItem tci
				WHERE tci.DeliveryNo = adi.DeliveryNo 
				  AND tci.TransportID = @TransportID
			), 0),
			NewSeq = ROW_NUMBER() OVER(
				PARTITION BY adi.DeliveryNo, 
					CASE WHEN EXISTS (
						SELECT 1 FROM tblCargoItem tci 
						WHERE tci.DeliveryNo = adi.DeliveryNo 
						  AND tci.ItemCode = adi.ItemCode 
						  AND tci.TransportID = @TransportID
					) THEN 0 ELSE 1 END
				ORDER BY adi.MinItemNo
			)
		FROM @AggregatedDeliveryItems adi
	)
	INSERT INTO @tblCargoItem (
		[DeliveryNo], [ItemNo], [ItemCode], [ItemName], [OrderNo],
		[Qty], [QtyUnit], [QtyUnitID], [PalletQty], [PickingFlg],
		[Comment], [StockQty], [NetWeight], [GrossWeight], [CopyFlg], [BatchFlg]
	)
	SELECT 
		m.DeliveryNo,
		CASE 
			WHEN m.ExistingItemNo IS NOT NULL THEN m.ExistingItemNo
			ELSE RIGHT('000000' + CAST(m.BaseNo + (m.NewSeq * 10) AS VARCHAR(10)), 6)
		END AS ItemNo,
		m.ItemCode,
		m.ItemName,
		m.OrderNo,
		m.Qty,
		m.QtyUnit,
		[dbo].[fnGetQtyUnit](m.QtyUnit),
		m.PalletQty,
		CASE 
			WHEN ISNULL(m.PalletQty, 0) = 0 OR CAST(m.Qty AS INT) % CAST(m.PalletQty AS INT) = 0 THEN 0 
			ELSE 1 
		END AS PickingFlg,
		m.Comment,
		m.StockQty,
		m.NetWeight,
		m.GrossWeight,
		0 AS CopyFlg,
		m.BatchFlg
	FROM ItemMapping m;

	--Update Collidata
	UPDATE t
	SET t.Colli=ISNULL((SELECT SUM(CEILING(it.Qty/it.PalletQty)) FROM @tblCargoItem it WHERE it.DeliveryNo=t.DeliveryNo AND ISNULL(it.PalletQty,0)>0),0)
	FROM @tblCargo t

	UPDATE t
	SET t.Colli=1
	FROM @tblCargo t
	WHERE t.Colli=0
	/*
	SELECT * FROm @tblTransport
	SELECT * FROM @tblShipment
	SELECT * FROM @tblCargo
	SELECT * FROM @tblCargoItem
	*/
	SELECT * FROM @tblCargo

	--DECLARE Raklap logic
	DECLARE @PalletLogic TABLE(
		PartnerID VARCHAR(100),
		DeliveryCnt SMALLINT,
		DeliveryNo VARCHAR(50),
		PalletNo INT,
		SrcDeliveryNo VARCHAR(50)
	)

	DECLARE @tmpTransportNo VARCHAR(50)
	SELECT TOP 1 @tmpTransportNo= TransportNo FROM @tblTransport

	INSERT INTO @PalletLogic(PartnerID,DeliveryCnt,DeliveryNo,PalletNo,SrcDeliveryNo)
	SELECT tc.SourcePartnerID,COUNT(DISTINCT tci.DeliveryNo),@tmpTransportNo+LEFT(tc.SourcePartnerID,2)+RIGHT(tc.SourcePartnerID,2),SUM(tci.Qty), MIN(tc.DeliveryNo) 
	FROM @tblCargo tc 
	INNER JOIN @tblCargoItem tci ON tci.DeliveryNo=tc.DeliveryNo
	WHERE (tci.ItemCode IN ('80000036', 'K00890000') OR EXISTS (SELECT 1 FROM tblXrefExceptions xe WHERE xe.ExType = 'PalletItemCode' AND xe.ExValue = tci.ItemCode)) 
	  AND tc.Direction=0
	GROUP BY tc.SourcePartnerID

	DELETE FROM @PalletLogic WHERE DeliveryCnt=1

	--------------------------
	INSERT INTO @tblCargoItemCopy
		(
			[DeliveryNo],
			[OldDeliveryNo],
			[ItemNo],
			[ItemCode],
			[ItemName],
			[OrderNo],
			[Qty],
			[QtyUnit],
			[QtyUnitID],
			[PalletQty],
			[PickingFlg],
			[Comment],
			[StockQty],
			[NetWeight],
			[GrossWeight],
			[CopyFlg],
			[BatchFlg]
		)
	SELECT pl.DeliveryNo, '', '000001', tci.ItemCode, MAX(tci.ItemName), '', pl.PalletNo, MAX(tci.QtyUnit), MAX(tci.QtyUnitID), MAX(tci.PalletQty), MAX(CAST(tci.PickingFlg AS INT)), MAX(tci.Comment), MAX(tci.StockQty), SUM(tci.NetWeight), SUM(tci.GrossWeight), 1, MAX(CAST(tci.BatchFlg AS INT))
	FROM @tblCargo tc 
	INNER JOIN @tblCargoItem tci ON tci.DeliveryNo=tc.DeliveryNo
	INNER JOIN @PalletLogic pl ON pl.PartnerID=tc.SourcePartnerID
	WHERE (tci.ItemCode IN ('80000036', 'K00890000') OR EXISTS (SELECT 1 FROM tblXrefExceptions xe WHERE xe.ExType = 'PalletItemCode' AND xe.ExValue = tci.ItemCode))
	GROUP BY pl.DeliveryNo, tci.ItemCode, pl.PalletNo

	--DELETE All Items(singel Items)
	DELETE tci FROM @tblCargoItem tci 
	INNER JOIN @tblCargo tc ON tc.DeliveryNo=tci.DeliveryNo 
	INNER JOIN @PalletLogic pl ON pl.PartnerID=tc.SourcePartnerID
	WHERE (tci.ItemCode IN ('80000036', 'K00890000') OR EXISTS (SELECT 1 FROM tblXrefExceptions xe WHERE xe.ExType = 'PalletItemCode' AND xe.ExValue = tci.ItemCode))

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
			[Comment],
			[StockQty],
			[NetWeight],
			[GrossWeight],
			[CopyFlg],
			[BatchFlg]
		)
		SELECT 
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
			[Comment],
			[StockQty],
			[NetWeight],
			[GrossWeight],
			[CopyFlg],
			[BatchFlg]
		FROM @tblCargoItemCopy
		WHERE CopyFlg=1
	
	
	INSERT INTO @tblCargo(
			[DeliveryNo],
			[Weight],
			[Colli],
			[Comment],
			[DeliveryDate],
			[PickupDate],
			[SourceSideCode],
			[SourcePartnerID],
			[DestinationSideCode],
			[DestinationPartnerID],
			[ContactInfo],
			[ContactPhone],
			[Direction],
			[StageNo]
		)
	SELECT 
		tci.DeliveryNo,
		tci.NetWeight,
		tci.Qty,
		'',--Comment
		tcc.DeliveryDate,
		tcc.PickupDate,
		tcc.SourceSideCode, 
		tcc.SourcePartnerID,
		tcc.DestinationSideCode,
		tcc.DestinationPartnerID,
		tcc.ContactInfo,
		tcc.ContactPhone,
		tcc.Direction,
		tcc.StageNo
	FROM @tblCargoItem tci 
		INNER JOIN @PalletLogic pl ON pl.DeliveryNo=tci.DeliveryNo
		INNER JOIN @tblCargo tcc ON tcc.DeliveryNo=pl.SrcDeliveryNo   WHERE NOT EXISTS(
		SELECT * FROM @tblCargo tc WHERE tc.DeliveryNo=tci.DeliveryNo
	)


	------EXCLUD BECAUSE OF S4  UPGRADE!!!
	/*
	DELETE tc FROM @tblCargo tc WHERE NOT EXISTS(
		SELECT * FROM @tblCargoItem tci WHERE tci.DeliveryNo=tc.DeliveryNo)
	*/
	/*
	SELECT * FROM @PalletLogic
	SELECT * FROM @tblCargoItemCopy
	SELECT * FROM @tblCargo
	SELECT * FROM @tblCargoItem
	*/


	--Define Exit points
	SELECT @TransportNo=TransportNo FROm @tblTransport

	--No stage No
	IF EXISTS(SELECT * FROm @tblCargo WHERE StageNo IS NULL)
	BEGIN
		SELECT TOP 1 @Msg='Missing Stage Data ('+DeliveryNo+')' FROm @tblCargo WHERE StageNo IS NULL
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID		
		
		RETURN
	END

	--No Carrier Data
	IF EXISTS(SELECT * FROm @tblTransport WHERE ISNULL(CarrierID,'')='')
	BEGIN
		SET @Msg='Missing Carrier Data'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID

		RETURN
	END

	--No Organizer id SelfOrganized=0
	IF EXISTS(SELECT * FROm @tblTransport WHERE ISNULL(OrganizerID,'')='' AND SelfOrganized=0)
	BEGIN
		SET @Msg='Missing Organizer Data'
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID

		RETURN
	END

	DECLARE @MergeTransportNo VARCHAR(30)
	SELECT @MergeTransportNo=ISNULL(MergeTransportNo,'') FROM @tblTransport
	IF(@MergeTransportNo<>'')
	BEGIN
		--Merge Transport No not exists in GLABs
		IF NOT EXISTS(SELECT * FROM tblTransport tt2 WHERE tt2.TransportNo=@MergeTransportNo AND tt2.GLABsID IS NOT NULL)
		BEGIN
			SELECT @Msg='No Active Transport to Merge:'+@MergeTransportNo
			INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
			SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
			SET @SuccessFlg=0
			--SELECT @SuccessFlg,@Msg --Just for testing
			UPDATE tblTransferIn
			SET TransformFlg=0
			WHERE id=@TransferID

			RETURN
		END


		--Check if merge is possible
		IF EXISTS(SELECT * FROm @tblTransport tt WHERE ISNULL(MergeTransportNo,'')<>'' AND EXISTS(SELECT * FROM tblTransport tt2 WHERE tt2.TransportNo=ISNULL(MergeTransportNo,'') AND tt2.GLABsID IS NOT NULL))
		BEGIN
			DECLARE @SiteCodesFrom TABLE(
				SiteCode VARCHAR(15)
			)

			DECLARE @SiteCodesTo TABLE(
				SiteCode VARCHAR(15)
			)

			INSERT INTO @SiteCodesFrom
			SELECT ts.SiteCode FROM @tblShipment ts

			INSERT INTO @SiteCodesTo
			SELECT ts.SiteCode FROM tblShipment ts WHERE ts.TransportID=@MergeTransportNo

			IF EXISTS(SELECT * FROM @SiteCodesFrom sf LEFT OUTER JOIN @SiteCodesTo st ON st.SiteCode=sf.SiteCode WHERE st.SiteCode IS NULL)
			BEGIN
				SELECT TOP 1 @Msg='No Site Code found in Merged transport:'+ sf.SiteCode FROM @SiteCodesFrom sf LEFT OUTER JOIN @SiteCodesTo st ON st.SiteCode=sf.SiteCode WHERE st.SiteCode IS NULL
				INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
				SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
				SET @SuccessFlg=0
				--SELECT @SuccessFlg,@Msg --Just for testing
				UPDATE tblTransferIn
				SET TransformFlg=0
				WHERE id=@TransferID				
				
				RETURN
			END
		END
	END
	--Merge Transport No different, but picking not completed!!!! LATER
	
	--No shipment Rule found
	IF EXISTS(SELECT * FROm @tblShipment WHERE ISNULL(ShipmentRule,'')='')
	BEGIN
		SELECT TOP 1 @Msg='Missing Shipment Rule('+SiteCode+')' FROM @tblShipment WHERE ISNULL(ShipmentRule,'')=''
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		RETURN
	END
	
	--Missing partner id
	IF EXISTS(SELECT * FROm @tblCargo WHERE ISNULL(SourcePartnerID,'')='')
	BEGIN
		SELECT TOP 1 @Msg='Missing Source PartnerID('+DeliveryNo+')' FROm @tblCargo  WHERE ISNULL(SourcePartnerID,'')=''
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID		
		
		RETURN
	END
	
	IF EXISTS(SELECT * FROm @tblCargo WHERE ISNULL(DestinationPartnerID,'')='')
	BEGIN
		SELECT TOP 1 @Msg='Missing Destination PartnerID('+DeliveryNo+')' FROm @tblCargo  WHERE ISNULL(DestinationPartnerID,'')=''
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID		
		
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		RETURN
	END
	
	--No Qty Unit ID
	IF EXISTS(SELECT * FROm @tblCargoItem WHERE ISNULL(QtyUnitID,'')='')
	BEGIN
		SELECT TOP 1 @Msg='Missing Qty Unit Reference('+QtyUnit+')' FROm @tblCargoItem WHERE ISNULL(QtyUnitID,'')=''
		INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
		SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo
		SET @SuccessFlg=0
		--SELECT @SuccessFlg,@Msg --Just for testing
		UPDATE tblTransferIn
		SET TransformFlg=0
		WHERE id=@TransferID
		
		RETURN
	END
	
	--Any item level change but locked LATER




	--SELECT @SuccessFlg,@Msg

	
	----LOAD TO DB
	IF EXISTS(SELECT * FROM tblTransport tr INNER JOIN @tblTransport trr ON trr.TransportNo=tr.TransportNo)
	BEGIN
		UPDATE tr
		SET tr.CarrierID=trr.CarrierID, tr.OrganizerID=trr.OrganizerID, tr.DelegateFlg=0
		FROM tblTransport tr INNER JOIN @tblTransport trr ON trr.TransportNo=tr.TransportNo
		AND (tr.OrganizerID<>trr.OrganizerID OR tr.CarrierID<>trr.CarrierID)

		UPDATE tr
		SET tr.Status=CASE WHEN tr.Status=0 THEN 0 ELSE -1 END, tr.MergeTransportNo=trr.MergeTransportNo
		FROM tblTransport tr INNER JOIN @tblTransport trr ON trr.TransportNo=tr.TransportNo
		AND (ISNULL(tr.MergeTransportNo,'')<>ISNULL(trr.MergeTransportNo,''))
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[tblTransport]
				   ([TransportNo]
				   ,[GLABsID]
				   ,[CarrierID]
				   ,[SelfOrganized]
				   ,[SiteCode]
				   ,[LicensePlate1]
				   ,[LicensePlate2]
				   ,[DelegateFlg]
				   ,[DriverName]
				   ,[DriverPhone]
				   ,[OrganizerID]
				   ,[MergeTransportNo]
				   ,[Status])
		SELECT 
			tr.TransportNo,
			NULL,
			tr.CarrierID,
			tr.SelfOrganized,
			tr.SiteCode,
			tr.LicensePlate1,
			tr.LicensePlate2,
			tr.DelegateFlg,
			tr.DriverName,
			tr.DriverPhone,
			tr.OrganizerID,
			tr.MergeTransportNo,
			CASE WHEN tr.MergeTransportNo IS NULL THEN 0 ELSE NULL END --Merge transports should not be transferred
		FROM @tblTransport tr
	END

		--Compare Stations!!!!
	IF EXISTS(SELECT ts.TransportID FROm tblShipment ts INNER JOIN @tblShipment tts ON tts.TransportID=ts.TransportID)
	BEGIN
		UPDATE ts
		SET ts.Priority=ISNULL(tts.Priority,''), ts.Status=0
		FROM tblShipment ts INNER JOIN @tblShipment tts ON tts.TransportID=ts.TransportID
		AND (ISNULL(tts.Priority,'')<>ts.Priority)

		UPDATE ts
		SET ts.PickupDate=tts.PickupDate, ts.Status=0
		FROM tblShipment ts INNER JOIN @tblShipment tts ON tts.TransportID=ts.TransportID
		AND ( ISNULL(tts.PickupDate,GETDATE())<>ISNULL(ts.PickupDate,GETDATE()))
	END
	
	IF EXISTS(SELECT * FROm @tblShipment ts WHERE NOT EXISTS(SELECT * FROm tblShipment tss WHERE tss.TransportID=ts.TransportID AND tss.SiteCode=ts.SiteCode))
	BEGIN
		INSERT INTO [dbo].[tblShipment]
           ([TransportID]
           ,[Priority]
           ,[ShipmentRule]
           ,[PickupDate]
           ,[Status]
           ,[SiteCode]
           ,[DelegateFlg]
		   ,[CheckOutBlock]
		   ,[SAPTemplateID]
		   )
		  SELECT 
			ts.TransportID,
			ISNULL(ts.Priority,''),
			ts.ShipmentRule,
			ts.PickupDate,
			0,---Status
			ts.SiteCode,
			0,--DelegateFlg
			CASE WHEN ISNULL((SELECT TOP 1 txs.AutoBlockFlg FROM tblXrefShipmentRule txs WHERE txs.GLABsID=ts.ShipmentRule),(SELECT TOP 1 txs.AutoBlockFlg FROM tblXrefShipmentRule txs WHERE txs.IntercompanyGLABsID=ts.ShipmentRule))=1 THEN 1 ELSE NULL END,
			ISNULL(ts.SAPTemplateID,(SELECT tst.id FROm tblShipmentStatusTemplate tst WHERE tst.DefaultFlg=1))
		  FROm @tblShipment ts 
		  WHERE NOT EXISTS(SELECT * FROm tblShipment tss WHERE tss.TransportID=ts.TransportID AND tss.SiteCode=ts.SiteCode)
	END

	IF (@TransportID IS NULL)
	BEGIN
		SELECT @TransportID=ts.TransportID FROM @tblShipment ts
	END

	--Update Cargos
	UPDATE tc
	SET tc.Comment=tcc.Comment, tc.ContactInfo=tcc.ContactInfo,/*tc.PickupDate=tcc.PickupDate,*/tc.DeliveryDate=tcc.DeliveryDate,tc.Status=0,tc.Colli=tcc.Colli, tc.StageNo=tcc.StageNo, tc.Weight=tcc.Weight, tc.ContactPhone=tcc.ContactPhone, tc.SourcePartnerID=tcc.SourcePartnerID, tc.DestinationPartnerID=tcc.DestinationPartnerID
	FROM tblCargo tc INNER JOIN @tblCargo tcc ON tcc.DeliveryNo=tc.DeliveryNo AND tc.TransportID=@TransportID
	AND ((tc.Comment<>tcc.Comment OR tc.ContactInfo<>tcc.ContactInfo /*OR tc.PickupDate<>tcc.PickupDate*/ OR tc.Colli<>tcc.Colli OR tc.Weight<>tcc.Weight OR tc.ContactPhone<>tcc.ContactPhone OR tc.SourcePartnerID<>tcc.SourcePartnerID OR tc.DestinationPartnerID<>tcc.DestinationPartnerID) 
	OR (tc.Status=2)
	)--OR tc.DeliveryDate<>tcc.DeliveryDate)
	   
	--Insert Cargo
	 INSERT INTO [dbo].[tblCargo]
			   ([TransportID]
			   ,[DeliveryNo]
			   ,[Weight]
			   ,[Colli]
			   ,[Comment]
			   ,[DeliveryDate]
			   ,[PickupDate]
			   ,[SourceSiteCode]
			   ,[SourcePartnerID]
			   ,[DestinationSiteCode]
			   ,[DestinationPartnerID]
			   ,[ContactInfo]
			   ,[GLABsID]
			   ,[Status]
			   ,[Direction]
			   ,[StageNo]
			   ,[ContactPhone])
	SELECT	
		@TransportID,
		tcc.DeliveryNo,
		tcc.Weight,
		tcc.Colli,
		tcc.Comment,
		tcc.DeliveryDate,
		tcc.PickupDate,
		tcc.SourceSideCode,
		tcc.SourcePartnerID,
		tcc.DestinationSideCode,
		tcc.DestinationPartnerID,
		tcc.ContactInfo,
		NULL,
		0,
		tcc.Direction,
		tcc.StageNo,
		tcc.ContactPhone
	FROM @tblCargo tcc 
	WHERE NOT EXISTS(SELECT * FROM tblCargo tc WHERE tc.DeliveryNo=tcc.DeliveryNo AND tc.TransportID=@TransportID)

	--Delete Cargo
	UPDATE tc
	SET tc.Status=-1
	FROM tblCargo tc 
	WHERE tc.TransportID=@TransportID
	AND NOT EXISTS(SELECT * FROM @tblCargo tcc WHERE tcc.DeliveryNo=tc.DeliveryNo)
	
	
	--Items: Match on DeliveryNo and ItemCode to prevent duplicate rows and picking lock delete failures
	UPDATE tci
	SET tci.Qty=tcci.Qty, 
	    tci.PalletQty=tcci.PalletQty, 
	    tci.QtyUnitID=tcci.QtyUnitID,
	    tci.SourceStatus=0,
	    tci.DestinationStatus=0, 
	    tci.PickingFlg=tcci.PickingFlg, 
	    tci.StockQty=tcci.StockQty, 
	    tci.OrderNo=tcci.OrderNo, 
	    tci.NetWeight=tcci.NetWeight, 
	    tci.GrossWeight=tcci.GrossWeight, 
	    tci.BatchFlg=tcci.BatchFlg, 
	    tci.Comment=tcci.Comment,
	    tci.ItemName=tcci.ItemName
	FROM tblCargoItem tci 
	INNER JOIN @tblCargoItem tcci 
	    ON tcci.DeliveryNo=tci.DeliveryNo 
	   AND tcci.ItemCode=tci.ItemCode 
	   AND tcci.ItemNo=tci.ItemNo 
	   AND tci.TransportID=@TransportID 
	WHERE ISNULL(tci.SourceStatus, 0) NOT IN (-1, 3)
	  AND ((ISNULL(tci.Qty,0)<>ISNULL(tcci.Qty,0) OR ISNULL(tci.PalletQty,0)<>ISNULL(tcci.PalletQty,0) OR ISNULL(tci.QtyUnitID,'')<>ISNULL(tcci.QtyUnitID,'') OR ISNULL(tci.PickingFlg,0)<>ISNULL(tcci.PickingFlg,0) OR ISNULL(tci.StockQty,0)<>ISNULL(tcci.StockQty,0) OR ISNULL(tci.BatchFlg,0)<>ISNULL(tcci.BatchFlg,0) OR ISNULL(tci.Comment,'')<>ISNULL(tcci.Comment,'') OR ISNULL(tci.NetWeight,0)<>ISNULL(tcci.NetWeight,0) OR ISNULL(tci.GrossWeight,0)<>ISNULL(tcci.GrossWeight,0)) 
	   OR (tci.DestinationStatus=2 OR tci.SourceStatus=2))

	INSERT INTO [dbo].[tblCargoItem]
			   ([DeliveryNo]
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
			   ,[DestinationGLABsID]
			   ,[DestinationStatus]
			   ,[StockQty]
			   ,TransportID
			   ,NetWeight
			   ,GrossWeight
			   ,BatchFlg)
	SELECT 
		tci.DeliveryNo,
		tci.ItemNo,
		tci.ItemCode,
		tci.ItemName,
		tci.OrderNo,
		tci.Qty,
		tci.QtyUnit,
		tci.QtyUnitID,
		tci.PalletQty,
		tci.PickingFlg,
		tci.Comment,
		NULL,
		0,
		NULL,
		0,
		tci.StockQty,
		@TransportID,
		tci.NetWeight,
		tci.GrossWeight,
		tci.BatchFlg
	FROM @tblCargoItem tci 
	WHERE NOT EXISTS(
		SELECT * FROM tblCargoItem tcci 
		WHERE tcci.DeliveryNo=tci.DeliveryNo 
		  AND tcci.ItemCode=tci.ItemCode 
		  AND tcci.TransportID=@TransportID
		  AND ISNULL(tcci.SourceStatus, 0) NOT IN (-1, 3)
	)

	UPDATE tci
	SET tci.SourceStatus=-1, tci.DestinationStatus=-1
	FROM tblCargoItem tci 
	WHERE tci.DeliveryNo IN(SELECT tca.DeliveryNo FROM @tblCargo tca)
	  AND tci.TransportID=@TransportID
	  AND NOT EXISTS(
		SELECT * FROM @tblCargoItem tcci 
		WHERE tcci.DeliveryNo=tci.DeliveryNo 
		  AND tcci.ItemCode=tci.ItemCode
	  )
	-----------

	--Archive
	INSERT INTO [dbo].[tblTransferTransportArchive]
			   (
			   [id]
			   ,[TransferID]
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
			   ,[OrganizerCode]
			   ,[OrganizerName]
			   ,[OrganizerCountryCode]
			   ,[OrganizerCity]
			   ,[OrganizerAddress]
			   ,[OrganizerPhone]
			   ,[OrganizerMail]
			   ,[OrganizerZIP]
			   ,[OrganizerTaxID]
			   ,[LicensePlate1]
			   ,[LicensePlate2]
			   ,[TransportNo2]
			   ,[DriverName]
			   ,[DriverPhone]
			   )
	SELECT
			[id]
			,[TransferID]
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
			,[OrganizerCode]
			,[OrganizerName]
			,[OrganizerCountryCode]
			,[OrganizerCity]
			,[OrganizerAddress]
			,[OrganizerPhone]
			,[OrganizerMail]
			,[OrganizerZIP]
			,[OrganizerTaxID]
			,[LicensePlate1]
			,[LicensePlate2]
			,[TransportNo2]
			,[DriverName]
			,[DriverPhone]
	FROM [dbo].[tblTransferTransport]
	WHERE TransferID=@TransferID

	INSERT INTO [dbo].[tblTransferTransportDeliveryArchive]
			   ([id]
			   ,[TransferID]
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
				,[StageNo]
				,[OrganizerCode]
				,[OrganizerName]
				,[OrganizerCountryCode]
				,[OrganizerCity]
				,[OrganizerAddress]
				,[OrganizerPhone]
				,[OrganizerMail]
				,[OrganizerZIP]
				,[OrganizerTaxID]
				,[SiteID]
				)
	SELECT 
			[id]
			,[TransferID]
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
			,[StageNo]
			,[OrganizerCode]
			,[OrganizerName]
			,[OrganizerCountryCode]
			,[OrganizerCity]
			,[OrganizerAddress]
			,[OrganizerPhone]
			,[OrganizerMail]
			,[OrganizerZIP]
			,[OrganizerTaxID]
			,[SiteID]
	FROM [dbo].[tblTransferTransportDelivery]
	WHERE TransferID=@TransferID

	INSERT INTO [dbo].[tblTransferTransportDeliveryItemArchive]
			   ([id]
			   ,[TransferID]
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
			   ,[BatchFlg]
			   )
	SELECT 
			[id]
			,[TransferID]
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
			,[BatchFlg]
	FROM [dbo].[tblTransferTransportDeliveryItem]
	WHERE TransferID=@TransferID

	INSERT INTO [dbo].[tblTransferTransportStageArchive]
           ([id]
		   ,[TransferID]
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
           ,[PartnerZIPTo]
           ,[SiteIDFrom]
           ,[SiteIDTo])
	SELECT 
			[id]
		   ,[TransferID]
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
           ,[PartnerZIPTo]
           ,[SiteIDFrom]
           ,[SiteIDTo]
	FROM [dbo].[tblTransferTransportStage]
	WHERE TransferID=@TransferID


	--Delete
	DELETE FROM tblTransferTransport WHERE TransferID=@TransferID
	DELETE FROM tblTransferTransportDelivery WHERE TransferID=@TransferID
	DELETE FROM tblTransferTransportDeliveryItem WHERE TransferID=@TransferID
	DELETE FROM tblTransferTransportStage WHERE TransferID=@TransferID

	--LOG
	UPDATE tblTransferIn
	SET TransformFlg=1
	WHERE id=@TransferID

	SET @Msg='SAP Load success'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
	SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,1,5,@TransferID,@TransportNo
	
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

	UPDATE tblTransferIn
	SET TransformFlg=0
	WHERE id=@TransferID

	SELECT @Msg=ERROR_MESSAGE() 
	
	SET @TransportNo=ISNULL((SELECT tt.TransportNo FROm tblTransferTransport tt WHERE tt.TransferID=@TransferID),(SELECT tt.TransportNo FROm tblTransferTransportArchive tt WHERE tt.TransferID=@TransferID))
	--SET @Msg='SAP Load failure'
	INSERT INTO tblLog(SPName,Inparams,Outparams,Msg,SuccessFlg, ProcessID, TransferIn,TransportNo)
	SELECT 'spLoadTransportToMW','@TransferID='+CAST(@TransferID AS VARCHAR(20)),'',@Msg,0,5,@TransferID,@TransportNo

	SET @SuccessFlg=0
END CATCH

END
GO


PRINT 'spLoadTransportToMWv234 successfully updated to v1.10.'
GO

-- =================================================================================================
-- 4. LÉPÉS: spCreateCargoItemBodyv223 frissítése
-- =================================================================================================
PRINT 'Deploying spCreateCargoItemBodyv223...'
GO

/****** Object:  StoredProcedure [dbo].[spCreateCargoItemBodyv223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROCEDURE [dbo].[spCreateCargoItemBodyv223](
	@TransferID INT,
	@SiteCode VARCHAR(15),
	@CargoItemID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

	DECLARE @RowID INT, @ItemNo VARCHAR(10),@ItemCode VARCHAR(20),@ItemName NVARCHAR(300),@Qty NUMERIC(9,3),@RowComment NVARCHAR(1000),@Picking VARCHAR(10),@QtyUnit VARCHAR(50), @ItemSegment VARCHAR(20),@GLABsID VARCHAR(50), @CargoID VARCHAR(50), @PickingQty NUMERIC(9,3) ,@StockQty NUMERIC(9,3), @BatchFlg BIT,@LockedFlg BIT, @GrossWeight INT, @OriginalBatchNo NVARCHAR(500), @NetWeight INT
	SELECT  @ItemCode=ci.ItemCode,@ItemNo=ci.ItemNo, @ItemName = ci.ItemName, @Qty = ci.Qty, @RowComment =  ISNULL(ci.Comment,''), @Picking = 1/*ci.PickingFlg*/ ,@QtyUnit = ci.QtyUnitID, 
	@GLABsID=CASE WHEN tc.SourceSiteCode=@SiteCode THEN ci.SourceGLABsID ELSE ci.DestinationGLABsID END, 
	@CargoID=CASE WHEN tc.SourceSiteCode=@SiteCode THEN tc.SourceOperationsID ELSE tc.DestinationOperationsID END, 
	@PickingQty=ci.Qty%CASE WHEN ISNULL(ci.PalletQty,0) =0 THEN ci.Qty ELSE ci.PalletQty END,
	--@PickingQty=ROUND((ci.Qty%(ci.Qty/CASE ci.PalletQty WHEN 0 THEN 1 ELSE ci.PalletQty END)),3), --ci.Qty%CASE ci.PalletQty WHEN 0 THEN 1 ELSE ci.PalletQty END,--
	@StockQty=ISNULL(ci.StockQty,0),
	@BatchFlg=ISNULL(ci.BatchFlg,0),
	@GrossWeight=CEILING(ISNULL(ci.GrossWeight,0)),
	@NetWeight=CEILING(ISNULL(ci.NetWeight,0)),
	@OriginalBatchNo=ISNULL(ci.Comment,'')
	FROM tblCargoItem ci INNER JOIN tblCargo tc  ON tc.DeliveryNo=ci.DeliveryNo AND tc.TransportID=ci.TransportID
	WHERE ci.id=@CargoItemID

	SELECT @ItemCode, @ItemName, @Qty

	DELETE FROM JSONText WHERE TransferID=@TransferID

	INSERT INTO JSONText
		SELECT @TransferID,'data.type','''cargoOperationItems''','' 
    IF(@GLABsID IS NOT NULL)
	BEGIN

		INSERT INTO JSONText
		SELECT @TransferID,'data.id',''''+@GLABsID+'''','' 
	 
	END
	
	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.code',''''+@ItemCode+'''',''
	
	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.name',''''+@ItemName+'''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.remoteId',''''+@ItemNo+'''',''

	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.quantity',CAST(@Qty AS varchar(10)),'' 



	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.quantityForPickingLocation',CAST(@PickingQty AS varchar(10)),'' 

	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.stockInfo',CAST(@StockQty AS varchar(10)),'' 

	--SELECT @BatchFlg, @RowComment

	IF(@BatchFlg=1)
	BEGIN
		IF(@RowComment='')
		BEGIN
			SET @RowComment='Batch:No Batch(' + FORMAT(@Qty, '0.###') + ')'
		END
		ELSE
		BEGIN
			SET @RowComment='Batch:'+@RowComment
		END

		IF(@NetWeight>0)
		BEGIN
			SET @RowComment=@RowComment+N' | Súly:' + CAST(@NetWeight AS VARCHAR(10)) +' kg' 
		END
	END
	ELSE
	BEGIN
		IF(@NetWeight>0)
		BEGIN
			SET @RowComment='Súly:' + CAST(@NetWeight AS VARCHAR(10)) +' kg' 
		END
	END

	

	IF(@BatchFlg=1 AND (@OriginalBatchNo='' OR @OriginalBatchNo='-' OR @OriginalBatchNo LIKE '%No Batch%'))
	BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.pickingLocked','CAST(1 AS BIT)','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.loadingLocked','CAST(1 AS BIT)','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.comment',''''+@RowComment+'''','' 
	END
	ELSE
	BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.pickingLocked','CAST(0 AS BIT)','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.loadingLocked','CAST(0 AS BIT)','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.comment',''''+@RowComment+'''','' 
	END

	
	IF(@GLABsID IS NULL)
	BEGIN
		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.cargoOperation.data.type','''cargoOperations''','' 

		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.cargoOperation.data.id',''''+@CargoID+'''','' 


		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.quantityUnit.data.type','''quantityUnits''','' 

		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.quantityUnit.data.id',''''+@QtyUnit+'''','' 
	END

	SELECT * FROM JSONText WHERE TransferID=@TransferID

DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL=COALESCE(@SQL, '','') +js.JsonText +' AS "' +js.JsonField +'",' FROM JSONText js
WHERE js.TransferID=@TransferID
ORDER BY js.RowID

--PRINT @SQL
SELECT @SQL=N'SELECT @JSON=(SELECT '+LEFT(@SQL,LEN(@SQL)-1)+' FOR JSON PATH)'

DECLARE @params NVARCHAR(250)
SET @Params='@JSON NVARCHAR(MAX) OUTPUT'

--PRINT @SQL

EXEC sp_executesql @SQL,@Params, @JSON=@Body OUTPUT

SELECT @Body=LEFT(@Body,LEN(@Body)-1)
SELECT @Body=RIGHT(@Body,LEN(@Body)-1)

SET @SuccessFlg=1
END TRY
BEGIN CATCH 
	/*
		SELECT  
    ERROR_NUMBER() AS ErrorNumber  
    ,ERROR_SEVERITY() AS ErrorSeverity  
    ,ERROR_STATE() AS ErrorState  
    ,ERROR_PROCEDURE() AS ErrorProcedure  
    ,ERROR_LINE() AS ErrorLine  
    ,ERROR_MESSAGE() AS ErrorMessage;  
	SET @SuccessFlg=0
	*/
END CATCH
END
GO


PRINT 'spCreateCargoItemBodyv223 successfully updated.'
GO

-- =================================================================================================
-- 5. LÉPÉS: DIAGNOSZTIKA ÉS OPCIONÁLIS KONSZOLIDÁCIÓ (nyitott fuvarmegbízások ellenőrzése)
-- =================================================================================================
PRINT 'Running duplicate item diagnostics on active transports...'
GO

SELECT 
    tci.TransportID, 
    tci.DeliveryNo, 
    tci.ItemCode, 
    COUNT(*) AS DuplicateCount,
    STRING_AGG(tci.ItemNo, ', ') AS ItemNumbers,
    STRING_AGG(
        CASE 
            WHEN LTRIM(RTRIM(ISNULL(tci.Comment, ''))) = '' THEN 'No Batch(' + FORMAT(tci.Qty, '0.###') + ')'
            ELSE LTRIM(RTRIM(tci.Comment)) + '(' + FORMAT(tci.Qty, '0.###') + ')'
        END, 
        ', '
    ) AS AggregatedBatches,
    STRING_AGG(ISNULL(tci.SourceGLABsID, 'NO_GLABS'), ', ') AS GLABsIDs,
    STRING_AGG(CAST(tci.SourceStatus AS VARCHAR(10)), ', ') AS SourceStatuses,
    SUM(tci.Qty) AS TotalSumQty
FROM tblCargoItem tci
INNER JOIN tblTransport tt ON tt.TransportNo = tci.TransportID
WHERE tt.Status < 3 -- Nyitott, folyamatban lévő szállítások
  AND ISNULL(tci.SourceStatus, 0) NOT IN (-1, 3)
GROUP BY tci.TransportID, tci.DeliveryNo, tci.ItemCode
HAVING COUNT(*) > 1;
GO

/*
-- OPCIONÁLIS KONSZOLIDÁCIÓ (csak akkor vedd ki kommentből és futtasd, ha a fenti lekérdezés aktív duplikációkat talál):
BEGIN TRANSACTION;

-- A) A megtartandó (rn = 1) sor frissítése az összesített mennyiséggel, súllyal és összefűzött Batch(mennyiség) megjegyzéssel
;WITH Ranked AS (
    SELECT 
        id, TransportID, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
        ROW_NUMBER() OVER(
            PARTITION BY TransportID, DeliveryNo, ItemCode 
            ORDER BY 
                CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
                CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
                id ASC
        ) AS rn,
        COUNT(*) OVER(PARTITION BY TransportID, DeliveryNo, ItemCode) AS cnt
    FROM tblCargoItem
    WHERE TransportID IN (SELECT TransportNo FROM tblTransport WHERE Status < 3)
      AND ISNULL(SourceStatus, 0) NOT IN (-1, 3)
),
Agg AS (
    SELECT 
        tci.TransportID,
        tci.DeliveryNo,
        tci.ItemCode,
        SUM(tci.Qty) AS SumQty,
        SUM(ISNULL(tci.NetWeight, 0)) AS SumNetWeight,
        SUM(ISNULL(tci.GrossWeight, 0)) AS SumGrossWeight,
        MAX(CASE WHEN tci.BatchFlg = 1 OR LTRIM(RTRIM(ISNULL(tci.Comment, ''))) <> '' THEN 1 ELSE 0 END) AS MaxBatchFlg,
        CASE 
            WHEN MAX(CASE WHEN tci.BatchFlg = 1 OR LTRIM(RTRIM(ISNULL(tci.Comment, ''))) <> '' THEN 1 ELSE 0 END) = 1 THEN
                ISNULL(
                    STUFF((
                        SELECT ', ' + b.BatchName + '(' + FORMAT(b.BatchQty, '0.###') + ')'
                        FROM (
                            SELECT 
                                CASE 
                                    WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 'No Batch'
                                    ELSE LTRIM(RTRIM(c.Comment))
                                END AS BatchName,
                                SUM(c.Qty) AS BatchQty,
                                CASE WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 1 ELSE 0 END AS IsNoBatch,
                                MIN(c.ItemNo) AS MinSubItemNo
                            FROM tblCargoItem c
                            WHERE c.TransportID = tci.TransportID
                              AND c.DeliveryNo = tci.DeliveryNo
                              AND c.ItemCode = tci.ItemCode
                              AND ISNULL(c.SourceStatus, 0) NOT IN (-1, 3)
                              AND c.Qty > 0
                            GROUP BY 
                                CASE 
                                    WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 'No Batch'
                                    ELSE LTRIM(RTRIM(c.Comment))
                                END,
                                CASE WHEN LTRIM(RTRIM(ISNULL(c.Comment, ''))) = '' THEN 1 ELSE 0 END
                        ) b
                        ORDER BY b.IsNoBatch ASC, b.MinSubItemNo ASC
                        FOR XML PATH(''), TYPE
                    ).value('.', 'NVARCHAR(MAX)'), 1, 2, ''),
                    ''
                )
            ELSE ''
        END AS AggComment
    FROM tblCargoItem tci
    WHERE tci.TransportID IN (SELECT TransportNo FROM tblTransport WHERE Status < 3)
      AND ISNULL(tci.SourceStatus, 0) NOT IN (-1, 3)
    GROUP BY tci.TransportID, tci.DeliveryNo, tci.ItemCode
    HAVING COUNT(*) > 1
)
UPDATE tci
SET tci.Qty = a.SumQty,
    tci.NetWeight = a.SumNetWeight,
    tci.GrossWeight = a.SumGrossWeight,
    tci.BatchFlg = a.MaxBatchFlg,
    tci.Comment = a.AggComment,
    tci.SourceStatus = 0,
    tci.DestinationStatus = 0
FROM tblCargoItem tci
INNER JOIN Ranked r ON r.id = tci.id AND r.rn = 1 AND r.cnt > 1
INNER JOIN Agg a ON a.TransportID = tci.TransportID AND a.DeliveryNo = tci.DeliveryNo AND a.ItemCode = tci.ItemCode;

-- B) A GLABs-hez még fel nem küldött árva másodlagos rekordok törlése
;WITH Dups AS (
    SELECT 
        id, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
        ROW_NUMBER() OVER(
            PARTITION BY TransportID, DeliveryNo, ItemCode 
            ORDER BY 
                CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
                CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
                id ASC
        ) AS rn
    FROM tblCargoItem
    WHERE TransportID IN (SELECT TransportNo FROM tblTransport WHERE Status < 3)
      AND ISNULL(SourceStatus, 0) NOT IN (-1, 3)
)
DELETE FROM tblCargoItem
WHERE id IN (
    SELECT id FROM Dups WHERE rn > 1 AND SourceGLABsID IS NULL
);

-- C) A GLABs-ben már létező, de másodlagos/felesleges sorok törlésre jelölése
;WITH Dups AS (
    SELECT 
        id, DeliveryNo, ItemCode, ItemNo, SourceGLABsID, SourceStatus,
        ROW_NUMBER() OVER(
            PARTITION BY TransportID, DeliveryNo, ItemCode 
            ORDER BY 
                CASE WHEN SourceGLABsID IS NOT NULL THEN 0 ELSE 1 END,
                CASE WHEN SourceStatus NOT IN (-1, 3) THEN 0 ELSE 1 END,
                id ASC
        ) AS rn
    FROM tblCargoItem
    WHERE TransportID IN (SELECT TransportNo FROM tblTransport WHERE Status < 3)
      AND ISNULL(SourceStatus, 0) NOT IN (-1, 3)
)
UPDATE tci
SET tci.SourceStatus = -1, tci.DestinationStatus = -1
FROM tblCargoItem tci
INNER JOIN Dups d ON d.id = tci.id
WHERE d.rn > 1 AND tci.SourceGLABsID IS NOT NULL AND tci.SourceStatus NOT IN (-1, 3);

COMMIT TRANSACTION;
*/

PRINT 'Cemix deployment completed successfully.'
GO
