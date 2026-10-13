/****** Object:  Table [dbo].[tblShipmentStatusQueue]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipmentStatusQueue](
	[StationID] [varchar](50) NULL,
	[ActionDate] [datetime] NULL,
	[CurrentStatus] [smallint] NULL,
	[SaveDate] [datetime] NULL,
	[ProcessStatus] [smallint] NULL
) ON [PRIMARY]
GO
