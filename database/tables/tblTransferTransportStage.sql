/****** Object:  Table [dbo].[tblTransferTransportStage]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTransferTransportStage](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[TransferID] [int] NOT NULL,
	[StageNo] [varchar](10) NULL,
	[DeliveryNo] [varchar](100) NOT NULL,
	[AddressNo] [varchar](100) NOT NULL,
	[PartnerCodeFrom] [varchar](50) NOT NULL,
	[PartnerNameFrom] [nvarchar](300) NOT NULL,
	[PartnerCountryFrom] [varchar](3) NULL,
	[PartnerCityFrom] [nvarchar](150) NOT NULL,
	[PartnerAddressFrom] [nvarchar](1000) NULL,
	[PartnerPhoneFrom] [varchar](100) NULL,
	[PartnerMailFrom] [varchar](500) NULL,
	[PartnerZIPFrom] [varchar](15) NULL,
	[PartnerCodeTo] [varchar](50) NULL,
	[PartnerNameTo] [nvarchar](300) NULL,
	[PartnerCountryTo] [varchar](3) NULL,
	[PartnerCityTo] [nvarchar](150) NOT NULL,
	[PartnerAddressTo] [nvarchar](1000) NULL,
	[PartnerPhoneTo] [varchar](100) NULL,
	[PartnerMailTo] [varchar](500) NULL,
	[PartnerZIPTo] [varchar](15) NULL,
	[SiteIDFrom] [varchar](15) NULL,
	[SiteIDTo] [varchar](15) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
