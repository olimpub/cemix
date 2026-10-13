/****** Object:  Table [dbo].[JSONText]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JSONText](
	[RowID] [int] IDENTITY(1,1) NOT NULL,
	[TransferID] [int] NULL,
	[JsonField] [nvarchar](500) NULL,
	[JsonText] [nvarchar](max) NULL,
	[JsonSQL] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
