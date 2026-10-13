/****** Object:  Table [dbo].[tblPartnerProd]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblPartnerProd](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[GLABsID] [varchar](50) NULL,
	[PartnerType] [smallint] NOT NULL,
	[PartnerCode] [varchar](50) NULL,
	[PartnerName] [nvarchar](300) NULL,
	[PartnerCountry] [varchar](3) NULL,
	[PartnerCity] [nvarchar](150) NULL,
	[PartnerAddress] [nvarchar](1000) NULL,
	[PartnerPhone] [varchar](100) NULL,
	[PartnerMail] [varchar](500) NULL,
	[PartnerZIP] [varchar](15) NULL,
	[SiteCode] [varchar](15) NULL,
	[PlantCode] [varchar](50) NULL,
	[ProfileFlg] [bit] NULL,
	[Status] [smallint] NULL,
	[TaxID] [varchar](30) NULL,
	[ProfileID] [varchar](50) NULL,
	[SAPCode] [varchar](50) NULL
) ON [PRIMARY]
GO
