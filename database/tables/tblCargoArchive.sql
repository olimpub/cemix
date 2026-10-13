/****** Object:  Table [dbo].[tblCargoArchive]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblCargoArchive](
	[id] [int] NOT NULL,
	[TransportID] [varchar](100) NOT NULL,
	[DeliveryNo] [varchar](100) NOT NULL,
	[Weight] [numeric](12, 2) NULL,
	[Colli] [smallint] NOT NULL,
	[Comment] [nvarchar](500) NULL,
	[DeliveryDate] [varchar](20) NULL,
	[PickupDate] [varchar](20) NULL,
	[SourcePartnerID] [varchar](50) NULL,
	[DestinationPartnerID] [varchar](50) NULL,
	[ContactInfo] [nvarchar](300) NULL,
	[GLABsID] [varchar](50) NULL,
	[Status] [smallint] NULL,
	[Direction] [bit] NULL,
	[CargoOperationsID] [varchar](50) NULL,
	[StageNo] [varchar](10) NULL,
	[ArrivalDate] [datetime] NULL,
	[ContactPhone] [varchar](50) NULL,
	[QtyMismatchFlg] [bit] NULL,
	[SourceSiteCode] [varchar](15) NULL,
	[DestinationSiteCode] [varchar](15) NULL,
	[SourceOperationsID] [varchar](50) NULL,
	[DestinationOperationsID] [varchar](50) NULL,
	[BorderCrossingID] [varchar](100) NULL
) ON [PRIMARY]
GO
