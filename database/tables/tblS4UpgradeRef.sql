/****** Object:  Table [dbo].[tblS4UpgradeRef]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblS4UpgradeRef](
	[RowNo] [int] IDENTITY(1,1) NOT NULL,
	[NewRef] [varchar](100) NULL,
	[OldRef] [varchar](100) NULL
) ON [PRIMARY]
GO
