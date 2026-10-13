/****** Object:  View [dbo].[vwErrorLog]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vwErrorLog]
AS
SELECT tl.TransportNo,  lp.ActionName,tl.id,tl.Inparams, tl.Outparams, tl.SuccessFlg, tl.Msg, tl.TransferIn, tl.TransferOut, tl.LogDate, tl.DeliveryNo, tl.ItemNo
FROM tblLog tl INNER JOIN tblLogProcess lp ON lp.id=tl.ProcessID
WHERE tl.LogDate>GETDATE()-7 AND SuccessFlg=0
GO
