/****** Object:  Table [dbo].[tblCargoItem]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblCargoItem](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[DeliveryNo] [varchar](100) NOT NULL,
	[ItemNo] [varchar](10) NOT NULL,
	[ItemCode] [nvarchar](50) NOT NULL,
	[ItemName] [nvarchar](300) NOT NULL,
	[OrderNo] [varchar](100) NOT NULL,
	[Qty] [numeric](9, 3) NULL,
	[QtyUnit] [varchar](10) NOT NULL,
	[QtyUnitID] [varchar](50) NOT NULL,
	[PalletQty] [numeric](9, 3) NULL,
	[PickingFlg] [bit] NULL,
	[Comment] [nvarchar](500) NULL,
	[SourceGLABsID] [varchar](50) NULL,
	[SourceStatus] [smallint] NULL,
	[IncludedText] [varchar](100) NULL,
	[StockQty] [numeric](9, 3) NULL,
	[DestinationGLABsID] [varchar](50) NULL,
	[DestinationStatus] [smallint] NULL,
	[TransportID] [varchar](100) NULL,
	[SourceInProgressFlg] [bit] NULL,
	[DestinationInProgressFlg] [bit] NULL,
	[NetWeight] [numeric](12, 3) NULL,
	[GrossWeight] [numeric](12, 3) NULL,
	[BatchFlg] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

-- Indexes & Constraints
/****** Object:  Index [IX_tblCargoItem1]    Script Date: 2026. 10. 13. 8:28:31 ******/
CREATE NONCLUSTERED INDEX [IX_tblCargoItem1] ON [dbo].[tblCargoItem]
(
	[SourceGLABsID] ASC,
	[SourceStatus] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
