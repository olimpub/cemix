/****** Object:  Table [dbo].[tblXrefBorder]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblXrefBorder](
	[SAPID] [varchar](10) NOT NULL,
	[GLABsID] [varchar](100) NOT NULL,
	[BorderName] [nvarchar](200) NOT NULL
) ON [PRIMARY]
GO
