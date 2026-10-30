/****** Object:  Table [dbo].[tblTaskHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTaskHistory](
	[SiteCode] [varchar](10) NULL,
	[TaskID] [varchar](100) NULL,
	[TaskName] [nvarchar](200) NULL,
	[TaskDescription] [nvarchar](2000) NULL,
	[CreateDate] [datetime] NULL,
	[Deadline] [datetime] NULL,
	[FinishDate] [datetime] NULL,
	[TotalWork] [int] NULL,
	[Priority] [int] NULL
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_tblTaskHistory_TaskID] ON [dbo].[tblTaskHistory]
(
	[TaskID] ASC
)
INCLUDE([SiteCode], [CreateDate], [FinishDate]) ON [PRIMARY]
GO
