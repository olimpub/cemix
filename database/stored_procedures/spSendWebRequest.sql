/****** Object:  StoredProcedure [dbo].[spSendWebRequest]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spSendWebRequest](
	@TransferID INT,
	@SuccessFlg BIT OUT
)
AS
BEGIN
	DECLARE
		@TransferType SMALLINT,
		@URL VARCHAR(1000),
		@Header NVARCHAR(MAX),
		@Body NVARCHAR(MAX),
		@MsgType VARCHAR(100),
		@MsgMethod VARCHAR(100),
		@ResponseAccept VARCHAR(100),
		@StatusCode INT,
		@StatusDesc NVARCHAR(MAX),
		@RetMsg NVARCHAR(MAX)


		SELECT @URL = tou.URL, @Header = tou.Header, @Body=tou.Body, @MsgType = tou.MsgType, @MsgMethod=tou.MsgMethod,@ResponseAccept=tou.ResponseAccept FROM tblTransferOut  tou WHERE tou.id=@TransferID
		

	BEGIN TRY
		EXECUTE dbo.spSendWebRequestCLR
			@URL=@URL,
			@Header=@Header,
			@Msg=@Body,	
			@ResponseAccept=@ResponseAccept,
			@MsgType=@MsgType,
			@MsgMethod=@MsgMethod,
			@StatusCode=@StatusCode OUT,
			@StatusDesc=@StatusDesc OUT,
			@RetMsg=@RetMsg OUT

	UPDATE tblTransferOut
	SET StatusCode=@StatusCode, StatusDesc=@StatusDesc, ReturnMsg=@RetMsg, Status= CASE WHEN @StatusCode IN(200,201,202,203,204) THEN 1 ELSE 2 END
	WHERE id=@TransferID

	IF(@StatusCode IN(200,201,202,203,204))
	BEGIN
		SET @SuccessFlg=1
	END
	ELSE
	BEGIN
		SET @SuccessFlg=0
	END

	END TRY
	BEGIN CATCH
		SELECT @RetMsg=ERROR_MESSAGE()
		SET @SuccessFlg=0

		UPDATE tblTransferOut
		SET ReturnMsg=@RetMsg,Status=2
		WHERE id=@TransferID
	END CATCH


END
GO
