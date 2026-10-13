/****** Object:  UserDefinedFunction [dbo].[fnGetLatestPickupDate]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[fnGetLatestPickupDate](
       @TransferID INT,
	   @SiteCode VARCHAR(15)
       )
    RETURNS DATETIME
    AS
    BEGIN


	  -- Declare the return variable here
       DECLARE @Return DATETIME
	   --SELECT @Return =MAX([dbo].[fnConvertToDatetime](ttd.PickupDate)) FROM tblTransferTransportDelivery ttd WHERE ttd.TransferID=@TransferID
	   SELECT @Return =[dbo].[fnConvertToDatetime](ttt.TransportDate) FROM tblTransferTransport ttt WHERE ttt.TransferID=@TransferID AND ttt.PlantCode=@SiteCode
       RETURN @Return
    END
GO
