/****** Object:  Table [dbo].[tblTransferTransportDocumentArchive]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTransferTransportDocumentArchive](
	[id] [int] NOT NULL,
	[TransferID] [int] NOT NULL,
	[TransportNo] [varchar](100) NOT NULL,
	[DeliveryNo] [varchar](100) NOT NULL,
	[DocType] [varchar](50) NOT NULL,
	[PDFData] [nvarchar](max) NOT NULL,
	[CreateDate] [datetime] NOT NULL,
	[LoadFlg] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
