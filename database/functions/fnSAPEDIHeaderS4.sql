/****** Object:  UserDefinedFunction [dbo].[fnSAPEDIHeaderS4]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnSAPEDIHeaderS4](
	@SiteCode VARCHAR(20)
)
    RETURNS XML
    AS
    BEGIN

    	-- Declare the return variable here
    	DECLARE @ResultVar XML

    	-- Add the T-SQL statements to compute the return value here
    	SET @ResultVar =
    		(
			SELECT 
				1 AS '@SEGMENT',
				'' AS [TABNAM],
				'' AS [MANDT],
				'' AS [DOCNUM],
				'' AS [DOCREL],
				'' AS [STATUS],
				'' AS [DIRECT],
				'' AS [OUTMOD],
				'' AS [EXPRSS],
				'' AS [TEST],
				'SHPMNT06' AS [IDOCTYP],
				'' AS [CIMTYP],
				CASE WHEN @SiteCode LIKE 'H3%' THEN 'ZZGLABS' ELSE 'YYSHPSTAT_GLABS' END AS [MESTYP],
				'' AS [MESCOD],
				'' AS [MESFCT],
				'' AS [STD],
				'' AS [STDVRS],
				'' AS [STDMES],
				'' AS [SNDPOR],
				'LS' AS [SNDPRT],
				'' AS [SNDPFC],
				'GLABS' AS [SNDPRN],
				'' AS [SNDSAD],
				'' AS [SNDLAD],
				'' AS [RCVPOR],
				'' AS [RCVPRT],
				'' AS [RCVPFC],
				'' AS [RCVPRN],
				'' AS [RCVSAD],
				'' AS [RCVLAD],
				'' AS [CREDAT],
				'' AS [CRETIM],
				'' AS [REFINT],
				'' AS [REFGRP],
				'' AS [REFMES],
				'' AS [ARCKEY],
				'' AS [SERIAL]
			FOR XML PATH('EDI_DC40')
    		)
    	-- Return the result of the function
    	RETURN @ResultVar

    END


GO
