/****** Object:  Table [dbo].[tblTransferOut]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTransferOut](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[TransferType] [smallint] NULL,
	[URL] [varchar](1000) NOT NULL,
	[Header] [nvarchar](max) NOT NULL,
	[Body] [nvarchar](max) NOT NULL,
	[MsgType] [varchar](100) NOT NULL,
	[MsgMethod] [varchar](100) NOT NULL,
	[ResponseAccept] [varchar](100) NOT NULL,
	[Status] [smallint] NULL,
	[StatusCode] [int] NULL,
	[StatusDesc] [nvarchar](max) NULL,
	[ReturnMsg] [nvarchar](max) NULL,
	[TransportID] [int] NULL,
	[TransportDate] [datetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Indexes & Constraints
ALTER TABLE [dbo].[tblTransferOut] ADD  DEFAULT (getdate()) FOR [TransportDate]
GO
