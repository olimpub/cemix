/****** Object:  StoredProcedure [dbo].[spCreateStationBodyv232]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCreateStationBodyv232](
	@TransferID INT,
	@StationID INT,
	@BlockFlg BIT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

DECLARE @StationNo VARCHAR(50)
SELECT @StationNo=ts.StationID FROm tblShipment ts WHERE ts.id=@StationID

DELETE FROM JSONText WHERE TransferID=@TransferID

INSERT INTO JSONText
SELECT @TransferID,'data.type','''stationDocumentationStatuses''',''

IF(@BlockFlg=0)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.name','''ready''',''
END
IF(@BlockFlg=1)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.attributes.name','''inprogress''',''
END

DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL=COALESCE(@SQL, '','') +js.JsonText +' AS "' +js.JsonField +'",' FROM JSONText js
WHERE js.TransferID=@TransferID
ORDER BY js.RowID

--PRINT @SQL
SELECT @SQL=N'SELECT @JSON=(SELECT '+LEFT(@SQL,LEN(@SQL)-1)+' FOR JSON PATH)'

DECLARE @params NVARCHAR(250)
SET @Params='@JSON NVARCHAR(MAX) OUTPUT'

EXEC sp_executesql @SQL,@Params, @JSON=@Body OUTPUT

SELECT @Body=LEFT(@Body,LEN(@Body)-1)
SELECT @Body=RIGHT(@Body,LEN(@Body)-1)

SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SET @SuccessFlg=0
END CATCH
END
GO
