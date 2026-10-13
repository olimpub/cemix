import subprocess
import json
import re

SERVER = "localhost"
DATABASE = "Cemix_Dev"

def run_query(sql):
    cmd = ["sqlcmd", "-S", SERVER, "-E", "-d", DATABASE, "-W", "-s", "|", "-Q", sql]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout

def main():
    print("=== Running Audit on Cemix_Dev ===")
    
    # Query 1: Top 10 Tables Size
    top10_sql = """
    SET NOCOUNT ON;
    SELECT TOP 10
        s.name AS [SchemaName],
        t.name AS [TableName],
        MAX(p.Row_Count) AS [RowCount],
        CAST(SUM(a.Data_MB) AS DECIMAL(18,2)) AS [DataSpaceMB],
        CAST(SUM(a.Index_MB) AS DECIMAL(18,2)) AS [IndexSpaceMB],
        CAST(SUM(a.Unused_MB) AS DECIMAL(18,2)) AS [UnusedSpaceMB],
        CAST(SUM(a.Total_MB) AS DECIMAL(18,2)) AS [TotalSpaceMB]
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN (
        SELECT 
            object_id,
            SUM(CASE WHEN index_id IN (0, 1) THEN rows ELSE 0 END) AS Row_Count
        FROM sys.partitions
        GROUP BY object_id
    ) p ON t.object_id = p.object_id
    INNER JOIN (
        SELECT 
            p.object_id,
            CAST(SUM(CASE 
                WHEN a.type = 1 AND p.index_id IN (0, 1) THEN a.data_pages 
                WHEN a.type IN (2, 3) THEN a.used_pages 
                ELSE 0 
            END) * 8.0 / 1024 AS DECIMAL(18, 2)) AS Data_MB,
            CAST(SUM(CASE 
                WHEN a.type = 1 AND p.index_id > 1 THEN a.used_pages 
                WHEN a.type = 1 AND p.index_id IN (0, 1) THEN (a.used_pages - a.data_pages) 
                ELSE 0 
            END) * 8.0 / 1024 AS DECIMAL(18, 2)) AS Index_MB,
            CAST(SUM(a.total_pages - a.used_pages) * 8.0 / 1024 AS DECIMAL(18, 2)) AS Unused_MB,
            CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18, 2)) AS Total_MB
        FROM sys.partitions p
        INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
        GROUP BY p.object_id
    ) a ON t.object_id = a.object_id
    WHERE t.is_ms_shipped = 0
    GROUP BY s.name, t.name
    ORDER BY [TotalSpaceMB] DESC;
    """
    out_top10 = run_query(top10_sql)
    print("--- Top 10 Tables ---")
    print(out_top10)

    # Query 2: Index Fragmentation
    frag_sql = """
    SET NOCOUNT ON;
    SELECT 
        OBJECT_SCHEMA_NAME(ips.object_id) AS [SchemaName],
        OBJECT_NAME(ips.object_id) AS [TableName],
        i.name AS [IndexName],
        i.type_desc AS [IndexType],
        ips.page_count AS [PageCount],
        CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS [FragmentationPct],
        CASE 
            WHEN ips.avg_fragmentation_in_percent > 30 AND ips.page_count > 1000 THEN 'ALTER INDEX REBUILD'
            WHEN ips.avg_fragmentation_in_percent BETWEEN 10 AND 30 AND ips.page_count > 500 THEN 'ALTER INDEX REORGANIZE'
            ELSE 'NONE / HEALTHY'
        END AS [RecommendedAction]
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count > 50
    ORDER BY ips.avg_fragmentation_in_percent DESC;
    """
    out_frag = run_query(frag_sql)
    print("--- Index Fragmentation ---")
    print(out_frag)

if __name__ == '__main__':
    main()
