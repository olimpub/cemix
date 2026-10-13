/****** Object:  Table [dbo].[tblShipmentStat]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipmentStat](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[SiteCode] [varchar](20) NULL,
	[StationID] [varchar](20) NULL,
	[ShipmentDate] [date] NULL,
	[Latency] [smallint] NULL,
	[PickingTime] [smallint] NULL,
	[WaitingTime] [smallint] NULL,
	[LoadingTime] [smallint] NULL,
	[CheckOutTime] [smallint] NULL,
	[ColliIn] [int] NULL,
	[WeightIn] [numeric](18, 3) NULL,
	[ColliOut] [int] NULL,
	[WeightOut] [numeric](18, 3) NULL,
	[PackagePrepared] [smallint] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
