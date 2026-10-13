/****** Object:  Table [dbo].[tblClientParams]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblClientParams](
	[SiteCode] [nvarchar](10) NOT NULL,
	[client_id] [nvarchar](100) NOT NULL,
	[client_secret] [nvarchar](200) NOT NULL,
	[profile id] [nvarchar](100) NOT NULL,
	[partner_id] [nvarchar](200) NOT NULL,
	[url] [varchar](500) NOT NULL,
	[SAPUrl] [varchar](500) NULL,
	[SAPUserName] [nvarchar](200) NULL,
	[SAPPassword] [nvarchar](200) NULL,
	[WHCode] [varchar](10) NULL,
	[WHName] [nvarchar](200) NULL,
	[WHCountry] [varchar](3) NULL,
	[WHCity] [nvarchar](150) NULL,
	[WHAddress] [nvarchar](1000) NULL,
	[WHPhone] [varchar](100) NULL,
	[WHMail] [varchar](500) NULL,
	[WHZIP] [varchar](15) NULL,
	[ActiveFlg] [bit] NULL,
	[AutoEntryFlg] [bit] NULL,
	[AutoExitFlg] [bit] NULL,
	[PreCallFlg] [bit] NULL,
	[AutoCheckOutFlg] [bit] NULL,
	[ItemsFlg] [bit] NULL,
	[QueryFlg] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[SiteCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
