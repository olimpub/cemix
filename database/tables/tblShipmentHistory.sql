/****** Object:  Table [dbo].[tblShipmentHistory]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipmentHistory](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[SiteCode] [varchar](20) NULL,
	[StationID] [varchar](50) NULL,
	[ChangeID] [varchar](50) NULL,
	[Status] [varchar](50) NULL,
	[ChangeDate] [datetime] NULL,
	[UserID] [varchar](50) NULL,
	[StageFlg] [bit] NULL,
	[ProcessFlg] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_tblShipmentHistory_StationID] ON [dbo].[tblShipmentHistory]
(
	[StationID] ASC,
	[StageFlg] ASC,
	[Status] ASC
)
INCLUDE([ChangeDate], [UserID]) ON [PRIMARY]
GO
