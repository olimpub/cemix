/****** Object:  StoredProcedure [dbo].[spSaveStationHistory]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spSaveStationHistory](
	@StationID VARCHAR(30)
)
AS 
BEGIN

BEGIN TRY	
	DELETE FROM tblShipmentStat WHERE StationID=@StationID
	DELETE FROM tblShipmentLog WHERE StationID=@StationID

	INSERT INTO tblShipmentLog(SiteCode,StationID,PickingFlg,LoadingFlg,StartID, UserID,ExcludeFlg)
	SELECT tbh.SiteCode, tbh.StationID, 1,0,tbh.id,tbh.UserID,0  FROM tblShipmentHistory tbh
	WHERE tbh.StationID=@StationID
	AND tbh.StageFlg=0 AND tbh.Status='inprogress'

	INSERT INTO tblShipmentLog(SiteCode,StationID,PickingFlg,LoadingFlg,StartID,UserID,ExcludeFlg)
	SELECT tbh.SiteCode, tbh.StationID, 0,1,tbh.id, tbh.UserID,0  FROM tblShipmentHistory tbh
	WHERE tbh.StationID=@StationID
	AND tbh.StageFlg=1 AND tbh.Status='loading'

	UPDATE tsl
	SET tsl.EndID=(SELECT MIN(tbh.id) FROM tblShipmentHistory tbh WHERE tbh.id<=(tsl.StartID+2) AND tbh.id>tsl.StartID AND tbh.Status='closed' AND tbh.StageFlg=0 AND tbh.StationID=tsl.StationID)
	FROM tblShipmentLog tsl
	WHERE tsl.StationID=@StationID AND tsl.PickingFlg=1

	UPDATE tsl
	SET tsl.EndID=(SELECT MIN(tbh.id) FROM tblShipmentHistory tbh WHERE tbh.id=(tsl.StartID+1) AND tbh.Status='administration' AND tbh.StageFlg=1 AND tbh.StationID=tsl.StationID)
	FROM tblShipmentLog tsl
	WHERE tsl.StationID=@StationID AND tsl.LoadingFlg=1

	UPDATE tsl
	SET tsl.StartDate=tbh.ChangeDate
	FROM tblShipmentLog tsl INNER JOIN tblShipmentHistory tbh
	ON tbh.id=tsl.StartID
	WHERE tsl.StationID=@StationID

	UPDATE tsl
	SET EndDate=tbh.ChangeDate
	FROM tblShipmentLog tsl INNER JOIN tblShipmentHistory tbh
	ON tbh.id=tsl.EndID
	WHERE tsl.StationID=@StationID

	UPDATE tsl
	SET tsl.ExcludeFlg=1
	FROM tblShipmentLog tsl
	WHERE tsl.StationID=@StationID AND tsl.EndID IS NULL

	UPDATE tsl
	SET tsl.ExcludeFlg=1
	FROM tblShipmentLog tsl
	WHERE tsl.StationID=@StationID AND tsl.EndID IS NULL

	UPDATE tsl
	SET tsl.LogTime=DATEDIFF(mi,StartDate,EndDate)
	FROM tblShipmentLog tsl
	WHERE tsl.StationID=@StationID AND tsl.EndID IS NOT NULL

	DECLARE @CargoOut TABLE(
		DeliveryNo VARCHAR(20),
		WeightOut NUMERIC(18,3),
		ColliOut SMALLINT,
		PackageOut SMALLINT
	)
	INSERT INTO @CargoOut(DeliveryNo,WeightOut,ColliOut,PackageOut)
	SELECT tc.DeliveryNo, tc.Weight,tc.Colli,(SELECT COUNT(*) FROM tblCargoItem ci WHERE ci.DeliveryNo=tc.DeliveryNo AND ci.TransportID=ts.TransportID AND ci.PickingFlg=1) FROM tblShipment ts INNER  JOIN tblCargo tc ON tc.TransportID=ts.TransportID AND tc.SourceSiteCode=ts.SiteCode
	WHERE ts.StationID=@StationID

	DECLARE @CargoIn TABLE(
		DeliveryNo VARCHAR(20),
		WeightIn NUMERIC(18,3),
		ColliIn SMALLINT
	)
	INSERT INTO @CargoIn(DeliveryNo,WeightIn,ColliIn)
	SELECT tc.DeliveryNo, tc.Weight,tc.Colli FROM tblShipment ts INNER  JOIN tblCargo tc ON tc.TransportID=ts.TransportID AND tc.DestinationSiteCode=ts.SiteCode
	WHERE ts.StationID=@StationID

	INSERT INTO tblShipmentStat(SiteCode,StationID,ShipmentDate,Latency,PickingTime,WaitingTime, LoadingTime,CheckOutTime, ColliIn, WeightIn,  ColliOut, WeightOut,PackagePrepared)
	SELECT SiteCode, StationID,
	(SELECT MIN(tbh2.ChangeDate) FROm tblShipmentHistory tbh2 WHERE tbh2.StationID=ts.StationID AND tbh2.StageFlg=1 AND tbh2.Status='loading'),--ShipmentDate
	DATEDIFF(mi,ts.BookingDate,(SELECT tbh2.ChangeDate FROm tblShipmentHistory tbh2 WHERE tbh2.StationID=ts.StationID AND tbh2.StageFlg=1 AND tbh2.Status='waiting')), --Latency
	(SELECT SUM(tsl.LogTime) FROM tblShipmentLog tsl WHERE tsl.StationID=@StationID AND tsl.PickingFlg=1 AND ISNULL(tsl.ExcludeFlg,0)=0), --Picking Time
	DATEDIFF(mi,(SELECT MIN(tbh2.ChangeDate) FROm tblShipmentHistory tbh2 WHERE tbh2.StationID=ts.StationID AND tbh2.StageFlg=1 AND tbh2.Status='waiting'),
		(SELECT MIN(tbh2.ChangeDate) FROm tblShipmentHistory tbh2 WHERE tbh2.StationID=ts.StationID AND tbh2.StageFlg=1 AND tbh2.Status='loading')), --Waiting time,
	(SELECT SUM(tsl.LogTime) FROM tblShipmentLog tsl WHERE tsl.StationID=@StationID AND tsl.LoadingFlg=1 AND ISNULL(tsl.ExcludeFlg,0)=0), --Loading Time
	DATEDIFF(mi,(SELECT MAX(tbh2.ChangeDate) FROm tblShipmentHistory tbh2 WHERE tbh2.StationID=ts.StationID AND tbh2.StageFlg=1 AND tbh2.Status='administration'),
		(SELECT MAX(tbh2.ChangeDate) FROm tblShipmentHistory tbh2 WHERE tbh2.StationID=ts.StationID AND tbh2.StageFlg=1 AND tbh2.Status='closed')),
	ISNULL((SELECT SUM(cin.ColliIn) FROM @CargoIn cin),0) ,--ColliIn
	ISNULL((SELECT SUM(cin.WeightIn) FROM @CargoIn cin),0) ,--WeightIn
	ISNULL((SELECT SUM(cin.ColliOut) FROM @CargoOut cin),0) ,--ColliOut
	ISNULL((SELECT SUM(cin.WeightOut) FROM @CargoOut cin),0) ,--WeightOut
	ISNULL((SELECT SUM(cin.PackageOut) FROM @CargoOut cin),0) --PackageOut
	FROM tblShipment ts
	WHERE ts.StationID=@StationID

	UPDATE tblShipment
	SET HistoryFlg=1
	WHERE StationID=@StationID
END TRY
BEGIN CATCH
	UPDATE tblShipment
	SET HistoryFlg=0
	WHERE StationID=@StationID
END CATCH
END
GO
