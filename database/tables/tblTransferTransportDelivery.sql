/****** Object:  Table [dbo].[tblTransferTransportDelivery]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTransferTransportDelivery](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[TransferID] [int] NOT NULL,
	[TransportID] [int] NOT NULL,
	[DeliveryNo] [varchar](100) NOT NULL,
	[Direction] [smallint] NOT NULL,
	[IncoTerms] [varchar](50) NOT NULL,
	[Weight] [numeric](12, 2) NULL,
	[Comment] [nvarchar](500) NOT NULL,
	[DeliveryDate] [varchar](20) NULL,
	[PickupDate] [varchar](20) NULL,
	[PartnerCode] [varchar](50) NOT NULL,
	[PartnerName] [nvarchar](300) NOT NULL,
	[PartnerCountry] [varchar](3) NULL,
	[PartnerCity] [nvarchar](150) NOT NULL,
	[PartnerAddress] [nvarchar](1000) NULL,
	[PartnerPhone] [varchar](100) NULL,
	[PartnerMail] [varchar](500) NULL,
	[PartnerZIP] [varchar](15) NULL,
	[ContactInfo] [nvarchar](300) NULL,
	[StageNo] [varchar](10) NULL,
	[AddressCode] [varchar](50) NULL,
	[OrganizerCode] [varchar](50) NULL,
	[OrganizerName] [nvarchar](300) NULL,
	[OrganizerCountryCode] [varchar](3) NULL,
	[OrganizerCity] [nvarchar](150) NULL,
	[OrganizerAddress] [nvarchar](1000) NULL,
	[OrganizerPhone] [varchar](100) NULL,
	[OrganizerMail] [varchar](500) NULL,
	[OrganizerZIP] [varchar](15) NULL,
	[PartnerTaxID] [varchar](30) NULL,
	[OrganizerTaxID] [varchar](30) NULL,
	[SiteID] [varchar](15) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
