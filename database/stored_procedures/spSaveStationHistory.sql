/****** Object:  StoredProcedure [dbo].[spSaveStationHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spSaveStationHistory](
	@StationID VARCHAR(50)
)
AS 
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY	
		DELETE FROM tblShipmentStat WHERE StationID = @StationID;
		DELETE FROM tblShipmentLog WHERE StationID = @StationID;

		-- Insert Picking (StageFlg=0, Status='inprogress') and Loading (StageFlg=1, Status='loading') start events in one pass
		INSERT INTO tblShipmentLog (SiteCode, StationID, PickingFlg, LoadingFlg, StartID, StartDate, UserID, ExcludeFlg)
		SELECT
			tbh.SiteCode,
			tbh.StationID,
			CASE WHEN tbh.StageFlg = 0 THEN 1 ELSE 0 END AS PickingFlg,
			CASE WHEN tbh.StageFlg = 1 THEN 1 ELSE 0 END AS LoadingFlg,
			tbh.id,
			tbh.ChangeDate,
			tbh.UserID,
			0
		FROM tblShipmentHistory tbh
		WHERE tbh.StationID = @StationID
		  AND (
			  (tbh.StageFlg = 0 AND tbh.Status = 'inprogress')
			  OR (tbh.StageFlg = 1 AND tbh.Status = 'loading')
		  );

		-- Match each start event with the next chronological event of the same StageFlg
		UPDATE tsl
		SET
			tsl.EndID      = CASE
								 WHEN tsl.PickingFlg = 1 AND nextEvt.Status = 'closed' THEN nextEvt.id
								 WHEN tsl.LoadingFlg = 1 AND nextEvt.Status IN ('administration', 'closed') THEN nextEvt.id
								 ELSE NULL
							 END,
			tsl.EndDate    = CASE
								 WHEN tsl.PickingFlg = 1 AND nextEvt.Status = 'closed' THEN nextEvt.ChangeDate
								 WHEN tsl.LoadingFlg = 1 AND nextEvt.Status IN ('administration', 'closed') THEN nextEvt.ChangeDate
								 ELSE NULL
							 END,
			tsl.LogTime    = CASE
								 WHEN (tsl.PickingFlg = 1 AND nextEvt.Status = 'closed')
								   OR (tsl.LoadingFlg = 1 AND nextEvt.Status IN ('administration', 'closed'))
								 THEN DATEDIFF(MINUTE, tsl.StartDate, nextEvt.ChangeDate)
								 ELSE NULL
							 END,
			tsl.ExcludeFlg = CASE
								 WHEN (tsl.PickingFlg = 1 AND nextEvt.Status = 'closed')
								   OR (tsl.LoadingFlg = 1 AND nextEvt.Status IN ('administration', 'closed'))
								 THEN 0
								 ELSE 1
							 END
		FROM tblShipmentLog tsl
		OUTER APPLY (
			SELECT TOP 1 tbh.id, tbh.ChangeDate, tbh.Status
			FROM tblShipmentHistory tbh
			WHERE tbh.StationID = tsl.StationID
			  AND tbh.id > tsl.StartID
			  AND (
				  (tsl.PickingFlg = 1 AND tbh.StageFlg = 0)
				  OR (tsl.LoadingFlg = 1 AND tbh.StageFlg = 1)
			  )
			ORDER BY tbh.id ASC
		) nextEvt
		WHERE tsl.StationID = @StationID;

		-- Aggregate Stage timestamps in a single scan of tblShipmentHistory
		DECLARE @MinWaitingDate DATETIME,
				@MinLoadingDate DATETIME,
				@MaxAdminDate   DATETIME,
				@MaxClosedDate  DATETIME,
				@PickingTime    SMALLINT,
				@LoadingTime    SMALLINT;

		SELECT
			@MinWaitingDate = MIN(CASE WHEN tbh.Status = 'waiting'        THEN tbh.ChangeDate END),
			@MinLoadingDate = MIN(CASE WHEN tbh.Status = 'loading'        THEN tbh.ChangeDate END),
			@MaxAdminDate   = MAX(CASE WHEN tbh.Status = 'administration' THEN tbh.ChangeDate END),
			@MaxClosedDate  = MAX(CASE WHEN tbh.Status = 'closed'         THEN tbh.ChangeDate END)
		FROM tblShipmentHistory tbh
		WHERE tbh.StationID = @StationID
		  AND tbh.StageFlg = 1;

		-- Aggregate PickingTime & LoadingTime in a single scan of tblShipmentLog
		SELECT
			@PickingTime = SUM(CASE WHEN tsl.PickingFlg = 1 THEN tsl.LogTime END),
			@LoadingTime = SUM(CASE WHEN tsl.LoadingFlg = 1 THEN tsl.LogTime END)
		FROM tblShipmentLog tsl
		WHERE tsl.StationID = @StationID
		  AND ISNULL(tsl.ExcludeFlg, 0) = 0;

		-- Aggregate Outbound and Inbound Cargo metrics
		DECLARE @ColliIn INT = 0, @WeightIn NUMERIC(18,3) = 0,
				@ColliOut INT = 0, @WeightOut NUMERIC(18,3) = 0, @PackageOut SMALLINT = 0;

		SELECT
			@ColliOut   = ISNULL(SUM(tc.Colli), 0),
			@WeightOut  = ISNULL(SUM(tc.Weight), 0),
			@PackageOut = ISNULL(SUM(ci.PickedCount), 0)
		FROM tblShipment ts
		INNER JOIN tblCargo tc
			ON tc.TransportID = ts.TransportID
		   AND tc.SourceSiteCode = ts.SiteCode
		OUTER APPLY (
			SELECT COUNT(*) AS PickedCount
			FROM tblCargoItem ci
			WHERE ci.DeliveryNo = tc.DeliveryNo
			  AND ci.TransportID = ts.TransportID
			  AND ci.PickingFlg = 1
		) ci
		WHERE ts.StationID = @StationID;

		SELECT
			@ColliIn  = ISNULL(SUM(tc.Colli), 0),
			@WeightIn = ISNULL(SUM(tc.Weight), 0)
		FROM tblShipment ts
		INNER JOIN tblCargo tc
			ON tc.TransportID = ts.TransportID
		   AND tc.DestinationSiteCode = ts.SiteCode
		WHERE ts.StationID = @StationID;

		INSERT INTO tblShipmentStat (
			SiteCode, StationID, ShipmentDate, Latency,
			PickingTime, WaitingTime, LoadingTime, CheckOutTime,
			ColliIn, WeightIn, ColliOut, WeightOut, PackagePrepared
		)
		SELECT
			ts.SiteCode,
			ts.StationID,
			@MinLoadingDate,
			DATEDIFF(MINUTE, ts.BookingDate, @MinWaitingDate),
			@PickingTime,
			DATEDIFF(MINUTE, @MinWaitingDate, @MinLoadingDate),
			@LoadingTime,
			DATEDIFF(MINUTE, ISNULL(@MaxAdminDate, @MinLoadingDate), @MaxClosedDate),
			@ColliIn,
			@WeightIn,
			@ColliOut,
			@WeightOut,
			@PackageOut
		FROM tblShipment ts
		WHERE ts.StationID = @StationID;

		UPDATE tblShipment
		SET HistoryFlg = 1
		WHERE StationID = @StationID;
	END TRY
	BEGIN CATCH
		UPDATE tblShipment
		SET HistoryFlg = 0
		WHERE StationID = @StationID;
	END CATCH
END
GO
