/****** Object:  Table [dbo].[tblShipmentStatus]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipmentStatus](
	[id] [int] NOT NULL,
	[StatusName] [varchar](20) NOT NULL,
	[QueryFlg] [bit] NOT NULL,
	[LastRunDate] [datetime] NULL,
	[AutoSAPCompleteFlg] [bit] NULL,
	[SAPStatusIn] [varchar](10) NULL,
	[SAPStatusOut] [varchar](10) NULL,
	[SAPStatusInDateStart] [bit] NULL,
	[SAPStatusInDateEnd] [bit] NULL,
	[SAPStatusOutDateStart] [bit] NULL,
	[SAPStatusOutDateEnd] [bit] NULL,
	[SAPStatusArrivalDate] [bit] NULL,
	[TemplateID] [int] NULL
) ON [PRIMARY]
GO
