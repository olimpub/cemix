/****** Object:  Table [dbo].[tmpStat1] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tmpStat1](
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

CREATE NONCLUSTERED INDEX [IX_tmpStat1_StationID] ON [dbo].[tmpStat1]
(
	[StationID] ASC
)
INCLUDE([ShipmentDate], [Picker], [Loader], [WeekNo], [Year], [SiteCode]) ON [PRIMARY]
GO
