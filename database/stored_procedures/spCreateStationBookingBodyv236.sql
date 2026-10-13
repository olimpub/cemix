/****** Object:  StoredProcedure [dbo].[spCreateStationBookingBodyv236]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCreateStationBookingBodyv236](
	@TransferID INT,
	@StationID INT,
	@BookingDate VARCHAR(20),
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
SELECT @TransferID,'data.type','''shipmentStations''',''

INSERT INTO JSONText
SELECT @TransferID,'data.id',''''+@StationNo+'''','' 
/*
INSERT INTO JSONText
SELECT @TransferID,'data.attributes.timeSlot.startTime',@BookingDate,''
*/
INSERT INTO JSONText
SELECT @TransferID,'data.attributes.booking.start',@BookingDate,''





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
