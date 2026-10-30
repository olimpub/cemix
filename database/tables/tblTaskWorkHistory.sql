/****** Object:  Table [dbo].[tblTaskWorkHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTaskWorkHistory](
	[SiteCode] [varchar](10) NULL,
	[TaskID] [varchar](100) NULL,
	[WorkID] [varchar](100) NULL,
	[StartDate] [datetime] NULL,
	[EndDate] [datetime] NULL,
	[WorkTime] [int] NULL,
	[UserID] [nvarchar](100) NULL
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_tblTaskWorkHistory_WorkID] ON [dbo].[tblTaskWorkHistory]
(
	[WorkID] ASC
)
INCLUDE([TaskID], [UserID], [WorkTime]) ON [PRIMARY]
GO
