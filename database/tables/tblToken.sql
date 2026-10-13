/****** Object:  Table [dbo].[tblToken]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblToken](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[access_token] [nvarchar](100) NOT NULL,
	[refresh_token] [nvarchar](100) NOT NULL,
	[token_type] [nvarchar](100) NOT NULL,
	[ExpiryDate] [datetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
