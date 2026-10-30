import subprocess

tables = [
    'tblXrefBorder',
    'tblXrefDocumentType',
    'tblXrefExceptions',
    'tblXrefQtyUnit',
    'tblXrefServiceLevel',
    'tblXrefShipmentOrganizer',
    'tblXrefShipmentRule',
    'tblXrefTaxCode'
]

with open('scripts/xref_analysis.txt', 'w', encoding='utf-8') as out:
    for t in tables:
        out.write(f"==================== {t} ====================\n")
        # Get schema
        cmd_schema = f'sqlcmd -S localhost -E -d Cemix_Dev -Q "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=\'{t}\' ORDER BY ORDINAL_POSITION;"'
        res_schema = subprocess.run(cmd_schema, shell=True, capture_output=True, text=True)
        out.write("SCHEMA:\n" + res_schema.stdout + "\n")
        
        # Get all rows
        cmd_rows = f'sqlcmd -S localhost -E -d Cemix_Dev -Q "SELECT * FROM {t};"'
        res_rows = subprocess.run(cmd_rows, shell=True, capture_output=True, text=True)
        out.write("DATA:\n" + res_rows.stdout + "\n\n")

print("Dumped X-Ref analysis to scripts/xref_analysis.txt")
