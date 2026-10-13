/****** Object:  StoredProcedure [dbo].[spLoadTransport]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spLoadTransport](
	@HeaderData NVARCHAR(MAX),
	@Body NVARCHAR(MAX),
	@ReturnValue INT OUTPUT,
	@ReturnDescription VARCHAR(MAX) OUTPUT
)
AS
BEGIN
BEGIN TRY 

	INSERT INTO [dbo].[tblTransferIn](TransferStatus,HeaderData,Body)
	SELECT 0,@HeaderData,@Body

	SET @ReturnValue=0
	SET @ReturnDescription='OK'

END TRY
BEGIN CATCH
	SET @ReturnValue=-1
	SELECT @ReturnDescription=ERROR_MESSAGE()
END CATCH
END
GO
