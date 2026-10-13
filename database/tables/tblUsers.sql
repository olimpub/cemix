/****** Object:  Table [dbo].[tblUsers]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblUsers](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[SiteCode] [varchar](20) NULL,
	[ProfileUserID] [varchar](50) NULL,
	[FirstName] [nvarchar](200) NULL,
	[LastName] [nvarchar](200) NULL,
	[Email] [nvarchar](200) NULL,
	[Position] [nvarchar](200) NULL,
	[ReportFlg] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

-- Indexes & Constraints
ALTER TABLE [dbo].[tblUsers] ADD  DEFAULT ((0)) FOR [ReportFlg]
GO
