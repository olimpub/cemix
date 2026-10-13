/****** Object:  Table [dbo].[tblStationStatusLive]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblStationStatusLive](
	[StationID] [varchar](50) NULL,
	[StatusID] [int] NULL,
	[StatusDate] [datetime] NOT NULL
) ON [PRIMARY]
GO

-- Indexes & Constraints
ALTER TABLE [dbo].[tblStationStatusLive] ADD  DEFAULT (getdate()) FOR [StatusDate]
GO
