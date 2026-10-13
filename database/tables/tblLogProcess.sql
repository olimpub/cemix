/****** Object:  Table [dbo].[tblLogProcess]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblLogProcess](
	[id] [smallint] NOT NULL,
	[ActionName] [nvarchar](100) NULL,
	[NotifyFailFlg] [bit] NULL,
	[NotifySuccessFlg] [bit] NULL,
	[FailRecipients] [varchar](1000) NULL,
	[SuccessRecipients] [varchar](1000) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
