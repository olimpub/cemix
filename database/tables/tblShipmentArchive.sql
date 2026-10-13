/****** Object:  Table [dbo].[tblShipmentArchive]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipmentArchive](
	[id] [int] NOT NULL,
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
	[CallID] [varchar](50) NULL,
	[OrderID] [smallint] NULL,
	[RampID] [smallint] NULL,
	[CallStatus] [smallint] NULL,
	[CargoOperationsID] [varchar](50) NULL,
	[CheckOutBlock] [tinyint] NULL,
	[CheckOutAllow] [tinyint] NULL,
	[SAPTemplateID] [int] NULL
) ON [PRIMARY]
GO
