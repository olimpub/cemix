/****** Object:  Table [dbo].[tblShipmentStatusExecution]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipmentStatusExecution](
	[id] [int] NOT NULL,
	[SiteCode] [varchar](10) NOT NULL,
	[LastRunDate] [datetime] NULL
) ON [PRIMARY]
GO
