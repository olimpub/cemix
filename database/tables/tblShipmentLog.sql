/****** Object:  Table [dbo].[tblShipmentLog]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblShipmentLog](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[SiteCode] [varchar](20) NULL,
	[StationID] [varchar](50) NULL,
	[PickingFlg] [bit] NULL,
	[LoadingFlg] [bit] NULL,
	[StartID] [int] NULL,
	[EndID] [int] NULL,
	[StartDate] [datetime] NULL,
	[EndDate] [datetime] NULL,
	[LogTime] [int] NULL,
	[UserID] [varchar](50) NULL,
	[ExcludeFlg] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_tblShipmentLog_StationID] ON [dbo].[tblShipmentLog]
(
	[StationID] ASC,
	[PickingFlg] ASC,
	[LoadingFlg] ASC
)
INCLUDE([LogTime], [UserID], [ExcludeFlg], [StartDate]) ON [PRIMARY]
GO
