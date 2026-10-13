/****** Object:  StoredProcedure [dbo].[spSendWebBinaryRequestCLR]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE [dbo].[spSendWebBinaryRequestCLR]
	@URL [nvarchar](max),
	@Header [nvarchar](max),
	@Msg [nvarchar](max),
	@ResponseAccept [nvarchar](max),
	@MsgType [nvarchar](max),
	@MsgMethod [nvarchar](20),
	@StatusCode [int] OUTPUT,
	@StatusDesc [nvarchar](max) OUTPUT,
	@RetMsg [nvarchar](max) OUTPUT
WITH EXECUTE AS CALLER
AS
EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[BinaryWebReqMsg]
GO
