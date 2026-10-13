/****** Object:  UserDefinedFunction [dbo].[spGetUnixTimestamp]    Script Date: 2026. 10. 13. 8:28:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[spGetUnixTimestamp](
@DateTime datetime
)
RETURNS integer
AS
BEGIN
  /* Function body */
  declare @return integer
  SELECT @Datetime=DATEADD(hour,DATEDIFF(hour, GETDATE(),GETUTCDATE()), @Datetime)
  SELECT @return = DATEDIFF(SECOND,{d '1970-01-01'}, @DateTime)
   
  return @return
END
GO
