/****** Object:  Table [dbo].[tblActivePlates]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblActivePlates](
	[SiteCode] [varchar](10) NULL,
	[PlateNo] [varchar](30) NULL,
	[SourceID] [int] NULL,
	[EntryDate] [datetime] NULL
) ON [PRIMARY]
GO
