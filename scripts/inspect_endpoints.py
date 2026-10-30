import glob
import re
import os

endpoints = []
for f in glob.glob(r'database\stored_procedures\*.sql'):
    with open(f, 'r', encoding='utf-8', errors='ignore') as fp:
        content = fp.read()
    
    # Check if this SP makes HTTP calls (has @URL or @MsgMethod)
    if '@URL' in content or 'spSendWebRequest' in content or 'spSendWebBinaryRequest' in content:
        sp_name = os.path.basename(f)
        
        urls = re.findall(r'@URL\s*=\s*([^\n;]+)', content)
        methods = re.findall(r'@MsgMethod\s*=\s*[\'"]?([A-Z]+)[\'"]?', content)
        types = re.findall(r'@MsgType\s*=\s*[\'"]?([^\'\";]+)[\'"]?', content)
        trans_types = re.findall(r'@TransferType\s*=\s*(\d+)', content)
        body_procs = re.findall(r'EXEC(?:UTE)?\s+([a-zA-Z0-9_]+Body[a-zA-Z0-9_]*)', content)
        
        endpoints.append({
            'sp': sp_name,
            'urls': [u.strip() for u in urls],
            'methods': list(set(methods)),
            'types': list(set(types)),
            'transfer_types': list(set(trans_types)),
            'body_generators': list(set(body_procs))
        })

print(f"Total SPs with web integration: {len(endpoints)}")
for ep in sorted(endpoints, key=lambda x: x['sp']):
    print(f"\n[{ep['sp']}]")
    print(f"  TransferType: {ep['transfer_types']}")
    print(f"  Method(s): {ep['methods']}")
    print(f"  MsgType: {ep['types']}")
    print(f"  Body Generator: {ep['body_generators']}")
    for u in ep['urls']:
        print(f"  URL Pattern: {u}")
