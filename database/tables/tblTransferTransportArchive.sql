/****** Object:  Table [dbo].[tblTransferTransportArchive]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTransferTransportArchive](
	[id] [int] NOT NULL,
	[TransferID] [int] NOT NULL,
	[TransportNo] [varchar](100) NOT NULL,
	[Priority] [varchar](50) NOT NULL,
	[CarrierCode] [varchar](50) NOT NULL,
	[CarrierName] [nvarchar](300) NOT NULL,
	[CountryCode] [varchar](3) NULL,
	[CarrierCity] [nvarchar](150) NOT NULL,
	[CarrierAddress] [nvarchar](1000) NULL,
	[CarrierPhone] [varchar](100) NULL,
	[CarrierMail] [varchar](500) NULL,
	[CarrierZIP] [varchar](15) NULL,
	[TruckType] [varchar](200) NULL,
	[PlantCode] [varchar](50) NOT NULL,
	[PlantName] [nvarchar](300) NOT NULL,
	[TransportDate] [varchar](20) NULL,
	[PrintCMR] [varchar](2) NULL,
	[ShipmentType] [varchar](10) NULL,
	[OrganizerCode] [varchar](50) NULL,
	[OrganizerName] [nvarchar](300) NULL,
	[OrganizerCountryCode] [varchar](3) NULL,
	[OrganizerCity] [nvarchar](150) NULL,
	[OrganizerAddress] [nvarchar](1000) NULL,
	[OrganizerPhone] [varchar](100) NULL,
	[OrganizerMail] [varchar](500) NULL,
	[OrganizerZIP] [varchar](15) NULL,
	[LicensePlate1] [varchar](50) NULL,
	[LicensePlate2] [varchar](50) NULL,
	[TransportNo2] [varchar](100) NULL,
	[CarrierTaxID] [varchar](30) NULL,
	[OrganizerTaxID] [varchar](30) NULL,
	[DriverName] [nvarchar](200) NULL,
	[DriverPhone] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
