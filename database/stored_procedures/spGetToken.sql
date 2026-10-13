/****** Object:  StoredProcedure [dbo].[spGetToken]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spGetToken](
	@SiteCode VARCHAR(10),
	@Token VARCHAR(100) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN
SELECT TOP 1 @Token = access_token FROM tblToken WHERE ExpiryDate>DATEADD(mi,+1,GETDATE())
ORDER BY id DESC

IF(ISNULL(@Token,'')='')
BEGIN
	DECLARE  @TransferID INT
	EXECUTE spTokenRequest
		@SiteCode=@SiteCode,
		@TransferID=@TransferID OUT,
		@SuccessFlg=@SuccessFlg OUT

		IF (@SuccessFlg=1)
		BEGIN
			SELECT TOP 1 @Token = access_token FROM tblToken WHERE ExpiryDate>DATEADD(mi,+1,GETDATE())
			ORDER BY id DESC
		END
END
ELSE
BEGIN
	SET @SuccessFlg=1
	RETURN
END

END
GO
