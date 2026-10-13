/****** Object:  Table [dbo].[tblProfile]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblProfile](
	[ProfileID] [varchar](50) NULL,
	[ProfileMail] [varchar](300) NULL,
	[ProfileName] [nvarchar](300) NULL,
	[TaxNumber] [varchar](30) NULL,
	[SiteCode] [varchar](30) NULL,
	[ActiveFlg] [bit] NULL
) ON [PRIMARY]
GO
