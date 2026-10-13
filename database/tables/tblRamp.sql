/****** Object:  Table [dbo].[tblRamp]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblRamp](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[SiteCode] [varchar](10) NOT NULL,
	[RampName] [nvarchar](100) NOT NULL,
	[GLABsID] [varchar](50) NOT NULL,
	[PreCallFlg] [bit] NOT NULL,
	[CallID] [varchar](50) NULL,
	[DeleteStatus] [smallint] NULL,
 CONSTRAINT [PK__tblRamp] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
