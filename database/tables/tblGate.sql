/****** Object:  Table [dbo].[tblGate]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblGate](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[GateName] [varchar](100) NOT NULL,
	[GateAddress] [varchar](300) NOT NULL,
	[Password] [varchar](50) NOT NULL,
	[SiteCode] [varchar](10) NOT NULL,
	[GateNo] [varchar](4) NOT NULL,
	[CmdNotEnter] [varchar](300) NULL,
	[CmdEnter] [varchar](300) NULL,
 CONSTRAINT [PK__tblGate] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = ON, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
