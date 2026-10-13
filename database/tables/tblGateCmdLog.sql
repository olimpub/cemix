/****** Object:  Table [dbo].[tblGateCmdLog]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblGateCmdLog](
	[LogID] [int] NULL,
	[Result] [nvarchar](2000) NULL,
	[LogDate] [datetime] NULL
) ON [PRIMARY]
GO

-- Indexes & Constraints
ALTER TABLE [dbo].[tblGateCmdLog] ADD  DEFAULT (getdate()) FOR [LogDate]
GO
