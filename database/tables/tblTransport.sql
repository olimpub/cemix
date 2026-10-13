/****** Object:  Table [dbo].[tblTransport]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tblTransport](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[TransportNo] [varchar](100) NOT NULL,
	[GLABsID] [varchar](50) NULL,
	[CarrierID] [varchar](50) NULL,
	[SelfOrganized] [bit] NULL,
	[SiteCode] [varchar](10) NULL,
	[LicensePlate1] [varchar](20) NULL,
	[LicensePlate2] [varchar](20) NULL,
	[DelegateFlg] [bit] NULL,
	[DriverPhone] [varchar](60) NULL,
	[OrganizerID] [varchar](50) NULL,
	[MergeTransportNo] [varchar](100) NULL,
	[Status] [smallint] NULL,
	[DriverName] [nvarchar](200) NULL,
 CONSTRAINT [PK__tblTransport] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
