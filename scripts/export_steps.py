import re

with open('steps_detail.txt', 'r', encoding='utf-8') as f:
    text = f.read()

steps = re.split(r'=== STEP (\d+): (.*?) ===', text)

with open('scripts/all_steps_breakdown.txt', 'w', encoding='utf-8') as out:
    for i in range(1, len(steps), 3):
        step_num = steps[i]
        step_name = steps[i+1]
        step_body = steps[i+2].strip()
        out.write(f"############################################################\n")
        out.write(f"STEP {step_num}: {step_name}\n")
        out.write(f"############################################################\n")
        out.write(step_body + "\n\n")

print("Exported all steps breakdown.")
