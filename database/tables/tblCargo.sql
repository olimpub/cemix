/****** Object:  Table [dbo].[tblCargo]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblCargo](
	[id] [int] IDENTITY(1,1) NOT NULL,
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
	[BorderCrossingID] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

-- Indexes & Constraints
/****** Object:  Index [IX_tblCargo1]    Script Date: 2026. 10. 13. 8:28:31 ******/
CREATE NONCLUSTERED INDEX [IX_tblCargo1] ON [dbo].[tblCargo]
(
	[GLABsID] ASC,
	[Status] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO

/****** Object:  Index [IX_tblCargo2]    Script Date: 2026. 10. 13. 8:28:31 ******/
CREATE NONCLUSTERED INDEX [IX_tblCargo2] ON [dbo].[tblCargo]
(
	[GLABsID] ASC
)
INCLUDE([TransportID],[DeliveryNo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
