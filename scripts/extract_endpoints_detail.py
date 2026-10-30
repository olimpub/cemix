import os
import re

sp_dir = r"C:\Dev\SQL\Cemix\database\stored_procedures"

files = sorted(os.listdir(sp_dir))
results = []

for f in files:
    if not f.endswith(".sql"):
        continue
    filepath = os.path.join(sp_dir, f)
    with open(filepath, "r", encoding="utf-8") as handle:
        c = handle.read()
    if "tblTransferOut" in c or "spSendWebRequest" in c or "spSendWebBinaryRequest" in c:
        methods = list(set(re.findall(r"@MsgMethod\s*=\s*'([^']+)'", c, re.IGNORECASE)))
        urls = re.findall(r"@URL\s*=\s*([^;\r\n]+)", c)
        transfer_types = re.findall(r"@TransferType\s*=\s*([^;\r\n]+)", c)
        json_types = list(set(re.findall(r'["\']type["\']\s*:\s*["\']([^"\']+)["\']', c)))
        openjson = re.findall(r"OPENJSON\((.*?)\)\s*WITH\s*\((.*?)\)", c, re.DOTALL | re.IGNORECASE)
        results.append({
            "file": f,
            "methods": methods,
            "urls": urls[:3],
            "transfer_types": transfer_types[:2],
            "json_types": json_types,
            "has_openjson": len(openjson) > 0,
            "openjson_defs": [oj[1].strip() for oj in openjson[:2]]
        })

with open("scripts/endpoints_summary.txt", "w", encoding="utf-8") as out:
    for r in results:
        out.write(f"=== {r['file']} ===\n")
        out.write(f"  Methods: {r['methods']}\n")
        out.write(f"  URLs: {r['urls']}\n")
        out.write(f"  TransferType: {r['transfer_types']}\n")
        out.write(f"  JSON types: {r['json_types']}\n")
        if r['openjson_defs']:
            out.write(f"  OPENJSON: {r['openjson_defs'][0][:150]}...\n")
        out.write("\n")

print(f"Written summary for {len(results)} procedures to scripts/endpoints_summary.txt")
