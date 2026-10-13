/****** Object:  StoredProcedure [dbo].[spChangePartner]    Script Date: 2026. 10. 13. 8:28:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spChangePartner](
	@CargoID INT
)
AS 
BEGIN

DECLARE @PartnerID VARCHAR(50), @Direction BIT, @CarrierID VARCHAR(50), @PartnerType SMALLINT, @CarrierType SMALLINT
SELECT @PartnerID=CASE tc.Direction WHEN 1 THEN tc.DestinationPartnerID ELSE tc.SourcePartnerID END,@CarrierID=ts.CarrierID  FROM tblCargo tc 
INNER JOIN tblShipment ts ON ts.TransportID=tc.TransportID
WHERE tc.id=@CargoID

SELECT @CarrierType=tp.PartnerType FROM tblPartner tp WHERE tp.GLABsID=@CarrierID
SELECT @PartnerType=tp.PartnerType FROM tblPartner tp WHERE tp.GLABsID=@PartnerID

DECLARE @PartnerUpdate TABLE(
	GLABsID VARCHAR(50),
	PartnerType SMALLINT
)

IF(@CarrierID<>@PartnerID)
BEGIN
	IF(@PartnerType<>1)
	BEGIN
		INSERT INTO @PartnerUpdate
		SELECT @PartnerID,1
	END

	IF(@CarrierType<>1)
	BEGIN
		INSERT INTO @PartnerUpdate
		SELECT @CarrierID,3
	END
END
ELSE
BEGIN
	IF(@PartnerType<>1)
	BEGIN
		INSERT INTO @PartnerUpdate
		SELECT @PartnerID,1
	END
END

UPDATE tp
SET PartnerType=pu.PartnerType
FROM tblPartner tp INNER JOIN @PartnerUpdate pu ON
pu.GLABsID=tp.GLABsID

DECLARE 	
	@SiteCode VARCHAR(15),
	@ID INT,
	@GLABsID VARCHAR(50),
	@SuccessFlg BIT

DECLARE @ProcessTable TABLE(
	SiteCode VARCHAR(15),
	PartnerID INT
)

INSERT INTO @ProcessTable
SELECT tp.SiteCode,tp.id FROM tblPartner tp INNER JOIN @PartnerUpdate pu ON
pu.GLABsID=tp.GLABsID

WHILE EXISTS(SELECT * FROM @ProcessTable)
BEGIN
	SELECT TOP 1 @SiteCode=SiteCode, @ID=PartnerID FROM @ProcessTable ORDER BY PartnerID

	EXECUTE spCreatePartner
	@SiteCode=@SiteCode,
	@PartnerID=@ID,
	@GLABsID=@GLABsID OUT,
	@SuccessFlg=@SuccessFlg OUT

	SELECT 'PartnerUpdate',@CargoID AS CargoID,@SiteCode,@ID,@GLABsID,@SuccessFlg

	DELETE FROM @ProcessTable WHERE PartnerID=@ID

END

END

GO
