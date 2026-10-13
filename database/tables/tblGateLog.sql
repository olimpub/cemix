/****** Object:  Table [dbo].[tblGateLog]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblGateLog](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[LicensePlate] [varchar](20) NULL,
	[SiteCode] [varchar](10) NULL,
	[GateNo] [varchar](10) NULL,
	[GateID] [int] NULL,
	[PermissionFlg] [bit] NULL,
	[AlreadyOpenFlg] [bit] NULL,
	[OpenSuccessFlg] [bit] NULL,
	[CmdCall] [varchar](200) NULL,
	[LogDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = ON, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

-- Indexes & Constraints
ALTER TABLE [dbo].[tblGateLog] ADD  DEFAULT (getdate()) FOR [LogDate]
GO
