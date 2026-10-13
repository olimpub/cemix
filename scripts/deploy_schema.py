import os
import subprocess
import glob

SERVER = "localhost"
DATABASE = "Cemix_Dev"

def run_sqlcmd(file_path):
    cmd = ["sqlcmd", "-S", SERVER, "-E", "-d", DATABASE, "-b", "-i", file_path]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.returncode, res.stdout, res.stderr

CLR_ROUTINES = {
    "fnBase64CLR.sql",
    "fnBase64DecodeCLR.sql",
    "spSendWebBinaryRequestCLR.sql",
    "spSendWebRequestCLR.sql"
}

def deploy_folder(folder_path, name):
    files = sorted(glob.glob(os.path.join(folder_path, "*.sql")))
    print(f"\n--- Deploying {name} ({len(files)} files) ---")
    success = 0
    failures = []
    
    for f in files:
        fname = os.path.basename(f)
        if fname in CLR_ROUTINES:
            print(f"  [SKIP] {fname} (Managed by CLR deployment)")
            success += 1
            continue
        code, out, err = run_sqlcmd(f)
        if code == 0:
            success += 1
        else:
            failures.append((fname, out.strip(), err.strip()))
            print(f"  [ERROR] {fname}: {out} {err}".strip())
            
    print(f"Summary for {name}: {success}/{len(files)} succeeded.")
    return failures

def main():
    print(f"Starting deployment to {DATABASE} on {SERVER}...")

    # 1. Deploy CLR assemblies first
    print("\n--- Deploying CLR Assemblies ---")
    clr_script = r"clr\deploy_all_clr.sql"
    code, out, err = run_sqlcmd(clr_script)
    if code != 0:
        print(f"CLR Deployment Error: {out} {err}")
    else:
        print("CLR Deployment Succeeded.")

    # 2. Deploy Tables
    tbl_failures = deploy_folder(r"database\tables", "Tables")

    # 3. Deploy Functions
    func_failures = deploy_folder(r"database\functions", "Functions")

    # 4. Deploy Views
    view_failures = deploy_folder(r"database\views", "Views")

    # 5. Deploy Stored Procedures
    sp_failures = deploy_folder(r"database\stored_procedures", "Stored Procedures")

    total_failures = len(tbl_failures) + len(func_failures) + len(view_failures) + len(sp_failures)
    print(f"\n==========================================")
    print(f"Total Failures: {total_failures}")
    if total_failures > 0:
        print("Failed items:")
        for fn, out, err in tbl_failures + func_failures + view_failures + sp_failures:
            print(f"  - {fn}: {out} {err}")

if __name__ == '__main__':
    main()
