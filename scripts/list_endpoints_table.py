import glob, re, os

print("Endpoint inventory:")
for f in sorted(glob.glob(r'database\stored_procedures\*.sql')):
    with open(f, 'r', encoding='utf-8', errors='ignore') as fp:
        c = fp.read()
    if '@URL' in c and ('tblClientParams' in c or 'tblGate' in c):
        sp = os.path.basename(f)
        m_method = re.search(r"@MsgMethod\s*=\s*'([^']+)'", c)
        m_type = re.search(r"@MsgType\s*=\s*'([^']+)'", c)
        m_ttype = re.search(r"@TransferType\s*=\s*(\d+)", c)
        m_url = re.search(r"@URL\s*=\s*([^\n;]+FROM\s+\[dbo\]\.\[tbl\w+\][^\n;]*)", c, re.DOTALL)
        if not m_url:
            m_url = re.search(r"@URL\s*=\s*([^\n;]+)", c)
        
        method = m_method.group(1) if m_method else '?'
        msg_type = m_type.group(1) if m_type else '?'
        ttype = m_ttype.group(1) if m_ttype else '-'
        url = m_url.group(1).strip() if m_url else '?'
        url = re.sub(r'\s+', ' ', url)
        # shorten url to the endpoint path
        url_clean = re.sub(r'tcpr\.\[url\]\s*\+\s*', '', url)
        url_clean = re.sub(r'FROM\s+\[dbo\].*$', '', url_clean)
        print(f"| `{sp}` | `{method}` | `{ttype}` | `{msg_type}` | `{url_clean.strip()}` |")
