/****** Object:  Table [dbo].[tblCargoItemArchive]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblCargoItemArchive](
	[id] [int] NOT NULL,
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
	[NetWeight] [numeric](12, 3) NULL,
	[GrossWeight] [numeric](12, 3) NULL,
	[BatchFlg] [bit] NULL
) ON [PRIMARY]
GO
