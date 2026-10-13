/****** Object:  Table [dbo].[tblS4Upgrade]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblS4Upgrade](
	[RowNo] [int] IDENTITY(1,1) NOT NULL,
	[EmailAddress] [varchar](100) NULL,
	[LastName] [nvarchar](200) NULL,
	[FirstName] [nvarchar](200) NULL,
	[Phone] [varchar](100) NULL,
	[Profiles] [nvarchar](500) NULL,
	[LastLoggedIn] [varchar](100) NULL,
	[ActiveStatus] [varchar](50) NULL,
	[ProfileName] [nvarchar](200) NULL,
	[Permission] [nvarchar](200) NULL,
	[LastLoginDate] [datetime] NULL,
	[StatusFlg] [bit] NULL,
	[SAPCode] [varchar](50) NULL,
	[MWID] [int] NULL
) ON [PRIMARY]
GO
