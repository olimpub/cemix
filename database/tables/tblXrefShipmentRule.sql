/****** Object:  Table [dbo].[tblXrefShipmentRule]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblXrefShipmentRule](
	[SAPID] [varchar](100) NOT NULL,
	[GLABsID] [varchar](100) NOT NULL,
	[SiteCode] [varchar](15) NULL,
	[AutoBlockFlg] [bit] NULL,
	[TemplateID] [int] NULL,
	[IntercompanyGLABsID] [varchar](100) NULL
) ON [PRIMARY]
GO
