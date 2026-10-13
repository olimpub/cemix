/****** Object:  Table [dbo].[tblTransferTransportDeliveryItem]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTransferTransportDeliveryItem](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[TransferID] [int] NOT NULL,
	[TransportID] [int] NOT NULL,
	[DeliveryNo] [varchar](100) NOT NULL,
	[ItemNo] [varchar](10) NOT NULL,
	[ItemCode] [nvarchar](50) NOT NULL,
	[ItemName] [nvarchar](300) NOT NULL,
	[OrderNo] [varchar](100) NOT NULL,
	[Qty] [numeric](9, 3) NULL,
	[QtyUnit] [varchar](10) NOT NULL,
	[PalletQty] [numeric](9, 3) NULL,
	[TaxCode] [varchar](10) NOT NULL,
	[Comment] [nvarchar](500) NULL,
	[StockQty] [numeric](9, 3) NULL,
	[NetWeight] [numeric](12, 3) NULL,
	[GrossWeight] [numeric](12, 3) NULL,
	[WeightUnit] [varchar](10) NULL,
	[BatchFlg] [varchar](10) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
