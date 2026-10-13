/****** Object:  StoredProcedure [dbo].[spCreateCallBody]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCreateCallBody](
	@TransferID INT,
	@StationID VARCHAR(50),
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN
DECLARE @RampID VARCHAR(50)
BEGIN TRY

SELECT @RampID = tr.GLABsID FROM tblShipment ts INNER JOIN tblRamp tr ON tr.id=ts.RampID
WHERE ts.StationID=@StationID

DELETE FROM JSONText
WHERE TransferID=@TransferID

INSERT INTO JSONText
SELECT @TransferID,'data.type','''calls''',''

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.station.data.type','''shipmentStations''',''

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.station.data.id',''''+@StationID+'''',''

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.ramp.data.type','''ramps''',''

INSERT INTO JSONText
SELECT @TransferID,'data.relationships.ramp.data.id',''''+@RampID+'''',''


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


SELECT @SQL=N'SELECT @JSON=(SELECT '+LEFT(@SQL,LEN(@SQL)-1)+' FOR JSON PATH, INCLUDE_NULL_VALUES)'
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
