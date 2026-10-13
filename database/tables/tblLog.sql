/****** Object:  Table [dbo].[tblLog]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblLog](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[SPName] [nvarchar](100) NOT NULL,
	[Inparams] [nvarchar](1000) NOT NULL,
	[Outparams] [nvarchar](1000) NOT NULL,
	[SuccessFlg] [bit] NOT NULL,
	[Msg] [nvarchar](max) NOT NULL,
	[TransportNo] [varchar](30) NULL,
	[DeliveryNo] [varchar](30) NULL,
	[ItemNo] [varchar](20) NULL,
	[ProcessID] [smallint] NULL,
	[NotificationFlg] [bit] NULL,
	[TransferIn] [int] NULL,
	[TransferOut] [int] NULL,
	[PartnerID] [int] NULL,
	[LogDate] [datetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Indexes & Constraints
/****** Object:  Index [IX_tblLog1]    Script Date: 2026. 10. 13. 8:28:31 ******/
CREATE NONCLUSTERED INDEX [IX_tblLog1] ON [dbo].[tblLog]
(
	[SuccessFlg] ASC,
	[NotificationFlg] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO

ALTER TABLE [dbo].[tblLog] ADD  DEFAULT (getdate()) FOR [LogDate]
GO
