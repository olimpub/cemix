/****** Object:  StoredProcedure [dbo].[spCreateCargoItemBodyv223]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spCreateCargoItemBodyv223](
	@TransferID INT,
	@SiteCode VARCHAR(15),
	@CargoItemID INT,
	@Body NVARCHAR(MAX) OUT,
	@SuccessFlg BIT OUT
)
AS 
BEGIN

BEGIN TRY

	DECLARE @RowID INT, @ItemNo VARCHAR(10),@ItemCode VARCHAR(20),@ItemName NVARCHAR(300),@Qty NUMERIC(9,3),@RowComment NVARCHAR(1000),@Picking VARCHAR(10),@QtyUnit VARCHAR(50), @ItemSegment VARCHAR(20),@GLABsID VARCHAR(50), @CargoID VARCHAR(50), @PickingQty NUMERIC(9,3) ,@StockQty NUMERIC(9,3), @BatchFlg BIT,@LockedFlg BIT, @GrossWeight INT, @OriginalBatchNo NVARCHAR(500), @NetWeight INT
	SELECT  @ItemCode=ci.ItemCode,@ItemNo=ci.ItemNo, @ItemName = ci.ItemName, @Qty = ci.Qty, @RowComment =  ISNULL(ci.Comment,''), @Picking = 1/*ci.PickingFlg*/ ,@QtyUnit = ci.QtyUnitID, 
	@GLABsID=CASE WHEN tc.SourceSiteCode=@SiteCode THEN ci.SourceGLABsID ELSE ci.DestinationGLABsID END, 
	@CargoID=CASE WHEN tc.SourceSiteCode=@SiteCode THEN tc.SourceOperationsID ELSE tc.DestinationOperationsID END, 
	@PickingQty=ci.Qty%CASE WHEN ISNULL(ci.PalletQty,0) =0 THEN ci.Qty ELSE ci.PalletQty END,
	--@PickingQty=ROUND((ci.Qty%(ci.Qty/CASE ci.PalletQty WHEN 0 THEN 1 ELSE ci.PalletQty END)),3), --ci.Qty%CASE ci.PalletQty WHEN 0 THEN 1 ELSE ci.PalletQty END,--
	@StockQty=ISNULL(ci.StockQty,0),
	@BatchFlg=ISNULL(ci.BatchFlg,0),
	@GrossWeight=CEILING(ISNULL(ci.GrossWeight,0)),
	@NetWeight=CEILING(ISNULL(ci.NetWeight,0)),
	@OriginalBatchNo=ISNULL(ci.Comment,'')
	FROM tblCargoItem ci INNER JOIN tblCargo tc  ON tc.DeliveryNo=ci.DeliveryNo AND tc.TransportID=ci.TransportID
	WHERE ci.id=@CargoItemID

	SELECT @ItemCode, @ItemName, @Qty

	DELETE FROM JSONText WHERE TransferID=@TransferID

	INSERT INTO JSONText
		SELECT @TransferID,'data.type','''cargoOperationItems''','' 
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
		SELECT @TransferID,'data.attributes.remoteId',''''+@ItemNo+'''',''

	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.quantity',CAST(@Qty AS varchar(10)),'' 



	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.quantityForPickingLocation',CAST(@PickingQty AS varchar(10)),'' 

	INSERT INTO JSONText
		SELECT @TransferID,'data.attributes.stockInfo',CAST(@StockQty AS varchar(10)),'' 

	--SELECT @BatchFlg, @RowComment

	IF(@BatchFlg=1)
	BEGIN
		IF(@RowComment='')
		BEGIN
			SET @RowComment='Batch:No Batch(' + FORMAT(@Qty, '0.###') + ')'
		END
		ELSE
		BEGIN
			SET @RowComment='Batch:'+@RowComment
		END

		IF(@NetWeight>0)
		BEGIN
			SET @RowComment=@RowComment+N' | Súly:' + CAST(@NetWeight AS VARCHAR(10)) +' kg' 
		END
	END
	ELSE
	BEGIN
		IF(@NetWeight>0)
		BEGIN
			SET @RowComment='Súly:' + CAST(@NetWeight AS VARCHAR(10)) +' kg' 
		END
	END

	

	IF(@BatchFlg=1 AND (@OriginalBatchNo='' OR @OriginalBatchNo='-' OR @OriginalBatchNo LIKE '%No Batch%'))
	BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.pickingLocked','CAST(1 AS BIT)','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.loadingLocked','CAST(1 AS BIT)','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.comment',''''+@RowComment+'''','' 
	END
	ELSE
	BEGIN
			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.pickingLocked','CAST(0 AS BIT)','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.loadingLocked','CAST(0 AS BIT)','' 

			INSERT INTO JSONText
			SELECT @TransferID,'data.attributes.comment',''''+@RowComment+'''','' 
	END

	
	IF(@GLABsID IS NULL)
	BEGIN
		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.cargoOperation.data.type','''cargoOperations''','' 

		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.cargoOperation.data.id',''''+@CargoID+'''','' 


		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.quantityUnit.data.type','''quantityUnits''','' 

		INSERT INTO JSONText
			SELECT @TransferID,'data.relationships.quantityUnit.data.id',''''+@QtyUnit+'''','' 
	END

	SELECT * FROM JSONText WHERE TransferID=@TransferID

DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL=COALESCE(@SQL, '','') +js.JsonText +' AS "' +js.JsonField +'",' FROM JSONText js
WHERE js.TransferID=@TransferID
ORDER BY js.RowID

--PRINT @SQL
SELECT @SQL=N'SELECT @JSON=(SELECT '+LEFT(@SQL,LEN(@SQL)-1)+' FOR JSON PATH)'

DECLARE @params NVARCHAR(250)
SET @Params='@JSON NVARCHAR(MAX) OUTPUT'

--PRINT @SQL

EXEC sp_executesql @SQL,@Params, @JSON=@Body OUTPUT

SELECT @Body=LEFT(@Body,LEN(@Body)-1)
SELECT @Body=RIGHT(@Body,LEN(@Body)-1)

SET @SuccessFlg=1
END TRY
BEGIN CATCH 
	/*
		SELECT  
    ERROR_NUMBER() AS ErrorNumber  
    ,ERROR_SEVERITY() AS ErrorSeverity  
    ,ERROR_STATE() AS ErrorState  
    ,ERROR_PROCEDURE() AS ErrorProcedure  
    ,ERROR_LINE() AS ErrorLine  
    ,ERROR_MESSAGE() AS ErrorMessage;  
	SET @SuccessFlg=0
	*/
END CATCH
END
GO
