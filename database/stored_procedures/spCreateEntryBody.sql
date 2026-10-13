/****** Object:  StoredProcedure [dbo].[spCreateEntryBody]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spCreateEntryBody](
	@TransferID INT,
	@TransportID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY
DECLARE @ShipmentStatus SMALLINT

SELECT @ShipmentStatus=ts.ShipmentStatus  FROM tblShipment ts WHERE ts.id=@TransportID

IF(@ShipmentStatus IN(3,4))
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.direction','''enter''',''
END

IF(@ShipmentStatus=5)
BEGIN
	INSERT INTO JSONText
	SELECT @TransferID,'data.direction','''exit''',''
END

UPDATE js
SET js.JsonField=REPLACE(JsonField,'@',CAST(js.RowID AS varchar(10)))
FROM JSONText js
WHERE js.TransferID=@TransferID
--ADD
SELECT * FROM JSONText WHERE TransferID=@TransferID

DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL=COALESCE(@SQL, '','') +js.JsonText +' AS "' +js.JsonField +'",' FROM JSONText js
WHERE js.TransferID=@TransferID
ORDER BY js.RowID


SELECT @SQL=N'SELECT @JSON=(SELECT '+LEFT(@SQL,LEN(@SQL)-1)+' FOR JSON PATH)'
PRINT @SQL
DECLARE @params NVARCHAR(250)
SET @Params='@JSON NVARCHAR(MAX) OUTPUT'

EXEC sp_executesql @SQL,@Params, @JSON=@Body OUTPUT

SELECT @Body=LEFT(@Body,LEN(@Body)-1)
SELECT @Body=RIGHT(@Body,LEN(@Body)-1)
SELECT @Body=REPLACE(@Body,'\/','/')

PRINT 'Final'
PRINT '----------------------'
PRINT @Body

SET @SuccessFlg=1
END TRY
BEGIN CATCH
	SET @SuccessFlg=0
END CATCH
END
GO
