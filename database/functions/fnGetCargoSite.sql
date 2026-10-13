/****** Object:  UserDefinedFunction [dbo].[fnGetCargoSite]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnGetCargoSite](
	   @CargoID INT
       )
    RETURNS VARCHAR(50)
    AS
    BEGIN

       -- Declare the return variable here
       DECLARE @Return VARCHAR(50), @TransportNo VARCHAR(30)
	   SELECT @TransportNo = ISNULL(tp.MergeTransportNo,tp.TransportNo) FROM tblCargo tc INNER JOIN tblTransport tp ON tp.TransportNo=tc.TransportID
	   WHERE tc.id=@CargoID

	   SET @Return=(SELECT tp.SiteCode FROM tblTransport tp WHERE tp.TransportNo=@TransportNo)
    
       RETURN @Return
    END
GO
