import subprocess

tables = [
    'tblTransferOut',
    'tblTransferIn',
    'tblShipmentDocument',
    'tblLog',
    'JSONText',
    'tblTransferTransportDeliveryItemArchive'
]

print("=== Estimating Compression Savings on Top Tables ===")
print(f"{'Table':<42} {'Type':<6} {'Current MB':>12} {'Compressed MB':>15} {'Savings %':>12}")
print("-" * 90)

for t in tables:
    for comp in ['ROW', 'PAGE']:
        sql = f"SET NOCOUNT ON; EXEC sp_estimate_data_compression_savings 'dbo', '{t}', NULL, NULL, '{comp}';"
        cmd = ['sqlcmd', '-S', 'localhost', '-E', '-d', 'Cemix_Dev', '-W', '-s', '|', '-Q', sql]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        total_curr = 0
        total_req = 0
        found = False
        for line in res.stdout.splitlines():
            parts = [p.strip() for p in line.split('|')]
            if len(parts) >= 8 and parts[4].isdigit() and parts[5].isdigit():
                total_curr += int(parts[4])
                total_req += int(parts[5])
                found = True
        if found:
            pct = round((total_curr - total_req) / total_curr * 100, 1) if total_curr > 0 else 0.0
            print(f"{t:<42} {comp:<6} {total_curr/1024:>12.2f} {total_req/1024:>15.2f} {pct:>11.1f}%")
