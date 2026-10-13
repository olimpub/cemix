/****** Object:  StoredProcedure [dbo].[spCreateCargoItemBody]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCreateCargoItemBody](
	@TransferID INT,
	@CargoItemID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

	DECLARE @RowID INT, @ItemCode VARCHAR(20),@ItemName NVARCHAR(300),@Qty NUMERIC(9,2),@RowComment NVARCHAR(1000),@Picking VARCHAR(10),@QtyUnit VARCHAR(50), @ItemSegment VARCHAR(20),@GLABsID VARCHAR(50), @CargoID VARCHAR(50)
	SELECT  @ItemCode=ci.ItemCode,@ItemName = ci.ItemName, @Qty = ci.Qty, @RowComment =  ci.Comment, @Picking = 1/*ci.PickingFlg*/ ,@QtyUnit = ci.QtyUnitID, @GLABsID=ci.GLABsID, @CargoID=tc.GLABsID FROM tblCargoItem ci INNER JOIN tblCargo tc 
	ON tc.DeliveryNo=ci.DeliveryNo  WHERE ci.id=@CargoItemID


	DELETE FROM JSONText WHERE TransferID=@TransferID

	INSERT INTO JSONText
		SELECT @TransferID,'data.type','''cargoItems''','' 
    IF(@GLABsID IS NOT NULL)
	BEGIN

		INSERT INTO JSONText
		SELECT @TransferID,'data.id',''''+@GLABsID+'''','' 
	 
	END
	
	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.code',''''+@ItemCode+'''',''
	
	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.name',''''+@ItemName+'''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.quantity',CAST(@Qty AS varchar(10)),'' 

	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.comment',''''+@RowComment+'''','' 

	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.picking.required','CAST('+CAST(@Picking AS varchar(10))+'AS BIT)','' 
	
	IF(@GLABsID IS NULL)
	BEGIN
		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.cargo.data.type','''shipmentCargos''','' 

		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.cargo.data.id',''''+@CargoID+'''','' 


		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.quantityUnit.data.type','''quantityUnits''','' 

		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.quantityUnit.data.id',''''+@QtyUnit+'''','' 
	END

	--SELECT * FROM JSONText WHERE TransferID=@TransferID

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
