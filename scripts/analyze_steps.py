import re

with open('steps_detail.txt', 'r', encoding='utf-8') as f:
    text = f.read()

steps = re.split(r'=== STEP (\d+): (.*?) ===', text)

step_info = []
for i in range(1, len(steps), 3):
    step_num = int(steps[i])
    step_name = steps[i+1]
    step_body = steps[i+2].strip()
    sps = re.findall(r'EXEC(?:UTE)?\s+([a-zA-Z0-9_]+)', step_body, re.IGNORECASE)
    step_info.append({
        'num': step_num,
        'name': step_name,
        'sps': list(dict.fromkeys(sps)),
        'body': step_body
    })

for s in step_info:
    print(f"Step {s['num']}: {s['name']} -> SPs: {s['sps']}")
