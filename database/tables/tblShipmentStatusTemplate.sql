/****** Object:  Table [dbo].[tblShipmentStatusTemplate]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipmentStatusTemplate](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[TemplateName] [nvarchar](200) NOT NULL,
	[DefaultFlg] [bit] NOT NULL,
	[InterCompanyUnloadFlg] [bit] NULL
) ON [PRIMARY]
GO
