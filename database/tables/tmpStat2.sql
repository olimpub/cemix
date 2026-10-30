/****** Object:  Table [dbo].[tmpStat2] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tmpStat2](
	[SiteCode] [varchar](20) NULL,
	[Picker] [varchar](50) NULL,
	[Loader] [varchar](50) NULL,
	[StationID] [varchar](50) NULL,
	[ShipmentDate] [date] NULL,
	[Weight] [numeric](24, 8) NULL,
	[Package] [int] NULL,
	[PackagePrepared] [smallint] NULL,
	[TransportID] [varchar](100) NOT NULL,
	[WeekNo] [int] NULL,
	[Year] [int] NULL,
	[WeightPrepared] [numeric](38, 6) NOT NULL
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_tmpStat2_Lookup] ON [dbo].[tmpStat2]
(
	[Year] ASC,
	[WeekNo] ASC,
	[SiteCode] ASC
)
INCLUDE([Picker], [Loader]) ON [PRIMARY]
GO
