/****** Object:  Table [dbo].[tblTransferIn]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTransferIn](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[TransferDate] [datetime] NOT NULL,
	[TransferStatus] [smallint] NULL,
	[HeaderData] [nvarchar](max) NULL,
	[Body] [nvarchar](max) NOT NULL,
	[BodyXML] [xml] NULL,
	[LoadFlg] [bit] NULL,
	[PartnerFlg] [bit] NULL,
	[TransformFlg] [bit] NULL,
	[SendFlg] [bit] NULL,
	[FileType] [smallint] NULL,
	[TransportNo] [varchar](220) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- Indexes & Constraints
ALTER TABLE [dbo].[tblTransferIn] ADD  DEFAULT (getdate()) FOR [TransferDate]
GO
