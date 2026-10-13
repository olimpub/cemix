/****** Object:  Table [dbo].[tblShipment]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipment](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[TransportID] [varchar](100) NOT NULL,
	[Priority] [varchar](50) NOT NULL,
	[ShipmentRule] [varchar](50) NULL,
	[PickupDate] [varchar](20) NULL,
	[StationID] [varchar](50) NULL,
	[Status] [smallint] NULL,
	[SiteCode] [varchar](10) NULL,
	[ShipmentStatus] [smallint] NOT NULL,
	[SAPStatus] [smallint] NULL,
	[BookingDate] [datetime] NULL,
	[DelegateFlg] [bit] NULL,
	[AutoEntryFlg] [bit] NULL,
	[AutoCheckOutFlg] [bit] NULL,
	[AutoExitFlg] [bit] NULL,
	[CallID] [varchar](50) NULL,
	[OrderID] [smallint] NULL,
	[RampID] [smallint] NULL,
	[CallStatus] [smallint] NULL,
	[CargoOperationsID] [varchar](50) NULL,
	[CheckOutBlock] [tinyint] NULL,
	[CheckOutAllow] [tinyint] NULL,
	[HistoryFlg] [bit] NULL,
	[SAPTemplateID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

-- Indexes & Constraints
/****** Object:  Index [IX_tblShipment1]    Script Date: 2026. 10. 13. 8:28:31 ******/
CREATE NONCLUSTERED INDEX [IX_tblShipment1] ON [dbo].[tblShipment]
(
	[TransportID] ASC
)
INCLUDE([SiteCode]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[tblShipment] ADD  DEFAULT ((0)) FOR [ShipmentStatus]
GO
