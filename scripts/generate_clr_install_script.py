import os
import re

def get_dll_hex(dll_path):
    with open(dll_path, 'rb') as f:
        return '0x' + f.read().hex().upper()

def get_assembly_hex_from_schema(schema_path, assembly_name):
    with open(schema_path, 'r', encoding='utf-16') as f:
        content = f.read()
    pattern = rf'CREATE ASSEMBLY \[{assembly_name}\][\s\S]*?FROM (0x[0-9A-Fa-f]+)'
    m = re.search(pattern, content)
    if m:
        return m.group(1)
    return None

def main():
    dll_path = r'clr\WebRequest\bin\Debug\net472\WebRequestJson.dll'
    schema_path = 'Cemix_schema.sql'

    webrequest_hex = get_dll_hex(dll_path)
    base64_hex = get_assembly_hex_from_schema(schema_path, 'Base64Dll')
    base64_decode_hex = get_assembly_hex_from_schema(schema_path, 'Base64DecodeDll')

    # 1. Dedicated script for WebRequest in clr/WebRequest/deploy_webrequest_clr.sql
    webrequest_script = f"""-- ============================================================================
-- SQL CLR Deployment Script: WebRequestJson / WebRequestDllJson
-- Target Database: Cemix_Dev
-- Runtime: .NET Framework 4.7.2 / 4.8
-- ============================================================================

-- Step 1: Server and Database Configuration for CLR Execution
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
GO
-- SQL Server 2017+ requires clr strict security to be disabled or assemblies to be signed/trusted
EXEC sp_configure 'clr strict security', 0;
RECONFIGURE;
GO

-- Ensure sa ownership for TRUSTWORTHY
ALTER AUTHORIZATION ON DATABASE::Cemix_Dev TO sa;
GO
ALTER DATABASE CURRENT SET TRUSTWORTHY ON;
GO

-- Step 2: Drop existing procedures if they exist
IF OBJECT_ID(N'[dbo].[spSendWebBinaryRequestCLR]', N'PC') IS NOT NULL
    DROP PROCEDURE [dbo].[spSendWebBinaryRequestCLR];
GO
IF OBJECT_ID(N'[dbo].[spSendWebRequestCLR]', N'PC') IS NOT NULL
    DROP PROCEDURE [dbo].[spSendWebRequestCLR];
GO
IF OBJECT_ID(N'[dbo].[BinaryWebReqMsg]', N'PC') IS NOT NULL
    DROP PROCEDURE [dbo].[BinaryWebReqMsg];
GO
IF OBJECT_ID(N'[dbo].[WebReqMsg]', N'PC') IS NOT NULL
    DROP PROCEDURE [dbo].[WebReqMsg];
GO

-- Step 3: Drop and Recreate Assemblies
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'WebRequestDllJson')
    DROP ASSEMBLY [WebRequestDllJson];
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'WebRequestJson')
    DROP ASSEMBLY [WebRequestJson];
GO

CREATE ASSEMBLY [WebRequestDllJson]
AUTHORIZATION [dbo]
FROM {webrequest_hex}
WITH PERMISSION_SET = UNSAFE;
GO

-- Step 4: Create T-SQL Stored Procedure Wrappers

-- Wrapper 1: BinaryWebReqMsg
CREATE PROCEDURE [dbo].[BinaryWebReqMsg]
    @URL [nvarchar](MAX),
    @Header [nvarchar](MAX),
    @Msg [nvarchar](MAX),
    @ResponseAccept [nvarchar](MAX),
    @MsgType [nvarchar](MAX),
    @MsgMethod [nvarchar](MAX),
    @StatusCode [int] OUTPUT,
    @StatusDesc [nvarchar](MAX) OUTPUT,
    @RetMsg [nvarchar](MAX) OUTPUT
AS EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[BinaryWebReqMsg];
GO

-- Wrapper 2: WebReqMsg
CREATE PROCEDURE [dbo].[WebReqMsg]
    @URL [nvarchar](MAX),
    @Header [nvarchar](MAX),
    @Msg [nvarchar](MAX),
    @ResponseAccept [nvarchar](MAX),
    @MsgType [nvarchar](MAX),
    @MsgMethod [nvarchar](MAX),
    @StatusCode [int] OUTPUT,
    @StatusDesc [nvarchar](MAX) OUTPUT,
    @RetMsg [nvarchar](MAX) OUTPUT
AS EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[WebReqMsg];
GO

-- Wrapper 3: spSendWebBinaryRequestCLR
CREATE PROCEDURE [dbo].[spSendWebBinaryRequestCLR]
    @URL [nvarchar](max),
    @Header [nvarchar](max),
    @Msg [nvarchar](max),
    @ResponseAccept [nvarchar](max),
    @MsgType [nvarchar](max),
    @MsgMethod [nvarchar](20),
    @StatusCode [int] OUTPUT,
    @StatusDesc [nvarchar](max) OUTPUT,
    @RetMsg [nvarchar](max) OUTPUT
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[BinaryWebReqMsg];
GO

-- Wrapper 4: spSendWebRequestCLR
CREATE PROCEDURE [dbo].[spSendWebRequestCLR]
    @URL [nvarchar](max),
    @Header [nvarchar](max),
    @Msg [nvarchar](max),
    @ResponseAccept [nvarchar](max),
    @MsgType [nvarchar](max),
    @MsgMethod [nvarchar](20),
    @StatusCode [int] OUTPUT,
    @StatusDesc [nvarchar](max) OUTPUT,
    @RetMsg [nvarchar](max) OUTPUT
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[WebReqMsg];
GO
"""

    with open(r'clr\WebRequest\deploy_webrequest_clr.sql', 'w', encoding='utf-8') as f:
        f.write(webrequest_script)
    print("Wrote clr/WebRequest/deploy_webrequest_clr.sql")

    # 2. Master script for all assemblies including Base64Dll and Base64DecodeDll
    all_assemblies_script = f"""-- ============================================================================
-- All SQL CLR Assemblies Deployment Script
-- Assemblies: Base64Dll, Base64DecodeDll, WebRequestDllJson, WebRequestJson
-- ============================================================================

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
GO
EXEC sp_configure 'clr strict security', 0;
RECONFIGURE;
GO
-- Ensure sa ownership for TRUSTWORTHY
ALTER AUTHORIZATION ON DATABASE::Cemix_Dev TO sa;
GO
ALTER DATABASE CURRENT SET TRUSTWORTHY ON;
GO

-- Base64Dll
IF OBJECT_ID(N'[dbo].[fnBase64CLR]', N'FS') IS NOT NULL
    DROP FUNCTION [dbo].[fnBase64CLR];
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'Base64Dll')
    DROP ASSEMBLY [Base64Dll];
GO
CREATE ASSEMBLY [Base64Dll]
AUTHORIZATION [dbo]
FROM {base64_hex}
WITH PERMISSION_SET = SAFE;
GO
CREATE FUNCTION [dbo].[fnBase64CLR](@Input [nvarchar](max))
RETURNS [nvarchar](max) WITH EXECUTE AS CALLER
AS EXTERNAL NAME [Base64Dll].[UserDefinedFunctions].[Base64Decode];
GO

-- Base64DecodeDll
IF OBJECT_ID(N'[dbo].[fnBase64DecodeCLR]', N'FS') IS NOT NULL
    DROP FUNCTION [dbo].[fnBase64DecodeCLR];
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'Base64DecodeDll')
    DROP ASSEMBLY [Base64DecodeDll];
GO
CREATE ASSEMBLY [Base64DecodeDll]
AUTHORIZATION [dbo]
FROM {base64_decode_hex}
WITH PERMISSION_SET = SAFE;
GO
CREATE FUNCTION [dbo].[fnBase64DecodeCLR](@data [nvarchar](max))
RETURNS [varbinary](max) WITH EXECUTE AS CALLER
AS EXTERNAL NAME [Base64DecodeDll].[UserDefinedFunctions].[DecodeBase64];
GO

-- WebRequest Assemblies & Wrappers
IF OBJECT_ID(N'[dbo].[spSendWebBinaryRequestCLR]', N'PC') IS NOT NULL
    DROP PROCEDURE [dbo].[spSendWebBinaryRequestCLR];
GO
IF OBJECT_ID(N'[dbo].[spSendWebRequestCLR]', N'PC') IS NOT NULL
    DROP PROCEDURE [dbo].[spSendWebRequestCLR];
GO
IF OBJECT_ID(N'[dbo].[BinaryWebReqMsg]', N'PC') IS NOT NULL
    DROP PROCEDURE [dbo].[BinaryWebReqMsg];
GO
IF OBJECT_ID(N'[dbo].[WebReqMsg]', N'PC') IS NOT NULL
    DROP PROCEDURE [dbo].[WebReqMsg];
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'WebRequestDllJson')
    DROP ASSEMBLY [WebRequestDllJson];
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'WebRequestJson')
    DROP ASSEMBLY [WebRequestJson];
GO

CREATE ASSEMBLY [WebRequestDllJson]
AUTHORIZATION [dbo]
FROM {webrequest_hex}
WITH PERMISSION_SET = UNSAFE;
GO

CREATE PROCEDURE [dbo].[BinaryWebReqMsg]
    @URL [nvarchar](MAX),
    @Header [nvarchar](MAX),
    @Msg [nvarchar](MAX),
    @ResponseAccept [nvarchar](MAX),
    @MsgType [nvarchar](MAX),
    @MsgMethod [nvarchar](MAX),
    @StatusCode [int] OUTPUT,
    @StatusDesc [nvarchar](MAX) OUTPUT,
    @RetMsg [nvarchar](MAX) OUTPUT
AS EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[BinaryWebReqMsg];
GO

CREATE PROCEDURE [dbo].[WebReqMsg]
    @URL [nvarchar](MAX),
    @Header [nvarchar](MAX),
    @Msg [nvarchar](MAX),
    @ResponseAccept [nvarchar](MAX),
    @MsgType [nvarchar](MAX),
    @MsgMethod [nvarchar](MAX),
    @StatusCode [int] OUTPUT,
    @StatusDesc [nvarchar](MAX) OUTPUT,
    @RetMsg [nvarchar](MAX) OUTPUT
AS EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[WebReqMsg];
GO

CREATE PROCEDURE [dbo].[spSendWebBinaryRequestCLR]
    @URL [nvarchar](max),
    @Header [nvarchar](max),
    @Msg [nvarchar](max),
    @ResponseAccept [nvarchar](max),
    @MsgType [nvarchar](max),
    @MsgMethod [nvarchar](20),
    @StatusCode [int] OUTPUT,
    @StatusDesc [nvarchar](max) OUTPUT,
    @RetMsg [nvarchar](max) OUTPUT
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[BinaryWebReqMsg];
GO

CREATE PROCEDURE [dbo].[spSendWebRequestCLR]
    @URL [nvarchar](max),
    @Header [nvarchar](max),
    @Msg [nvarchar](max),
    @ResponseAccept [nvarchar](max),
    @MsgType [nvarchar](max),
    @MsgMethod [nvarchar](20),
    @StatusCode [int] OUTPUT,
    @StatusDesc [nvarchar](max) OUTPUT,
    @RetMsg [nvarchar](max) OUTPUT
WITH EXECUTE AS CALLER
AS EXTERNAL NAME [WebRequestDllJson].[StoredProcedures].[WebReqMsg];
GO
"""
    with open(r'clr\deploy_all_clr.sql', 'w', encoding='utf-8') as f:
        f.write(all_assemblies_script)
    print("Wrote clr/deploy_all_clr.sql")

if __name__ == '__main__':
    main()
