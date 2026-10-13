import os
import re

def clean_name(name):
    return name.replace('[dbo].', '').replace('[', '').replace(']', '')

def main():
    schema_path = 'Cemix_schema.sql'
    with open(schema_path, 'r', encoding='utf-16') as f:
        content = f.read()

    # Split by the object header pattern:
    # /****** Object:  <type> <name>    Script Date: ... ******/
    header_pattern = re.compile(r'(/\*{6}\s+Object:\s+([^\s]+)\s+([^\s]+)[^\n]*\*{6}/)')
    
    matches = list(header_pattern.finditer(content))
    print(f"Found {len(matches)} object headers in {schema_path}")

    # Prepare directories
    base_dir = 'database'
    dirs = {
        'Table': os.path.join(base_dir, 'tables'),
        'View': os.path.join(base_dir, 'views'),
        'StoredProcedure': os.path.join(base_dir, 'stored_procedures'),
        'UserDefinedFunction': os.path.join(base_dir, 'functions'),
        'SqlAssembly': os.path.join(base_dir, 'assemblies'),
        'Index': os.path.join(base_dir, 'indexes'),
        'Type': os.path.join(base_dir, 'types'),
        'Job': os.path.join(base_dir, 'jobs')
    }
    for d in dirs.values():
        os.makedirs(d, exist_ok=True)

    # Dictionary to collect table extra SQL (indexes and defaults)
    table_extras = {}

    # Extract default constraints between line 3201 and 3220 (approx)
    # They are between the last Index (IX_tblShipment1) and the first StoredProcedure (spAddCargoItem)
    # Let's inspect where they appear
    index_objs = {}
    
    # Store objects
    extracted_objects = []
    for idx, match in enumerate(matches):
        start_pos = match.start()
        end_pos = matches[idx + 1].start() if idx + 1 < len(matches) else len(content)
        
        obj_type = match.group(2)
        raw_name = match.group(3)
        chunk = content[start_pos:end_pos]
        
        extracted_objects.append((obj_type, raw_name, chunk))

    # Parse objects
    table_files = {}
    proc_count = 0
    func_count = 0
    view_count = 0
    table_count = 0
    assembly_count = 0

    for obj_type, raw_name, chunk in extracted_objects:
        clean = clean_name(raw_name)
        
        if obj_type == 'Table':
            table_files[clean] = chunk
            table_count += 1
        elif obj_type == 'View':
            file_path = os.path.join(dirs['View'], f"{clean}.sql")
            with open(file_path, 'w', encoding='utf-8') as out:
                out.write(chunk.strip() + '\n')
            view_count += 1
        elif obj_type == 'UserDefinedFunction':
            file_path = os.path.join(dirs['UserDefinedFunction'], f"{clean}.sql")
            with open(file_path, 'w', encoding='utf-8') as out:
                out.write(chunk.strip() + '\n')
            func_count += 1
        elif obj_type == 'StoredProcedure':
            # Note: the last stored procedure might contain trailing "USE [master] \n GO \n ALTER DATABASE..."
            if 'USE [master]' in chunk:
                chunk = chunk.split('USE [master]')[0]
            file_path = os.path.join(dirs['StoredProcedure'], f"{clean}.sql")
            with open(file_path, 'w', encoding='utf-8') as out:
                out.write(chunk.strip() + '\n')
            proc_count += 1
        elif obj_type == 'SqlAssembly':
            file_path = os.path.join(dirs['SqlAssembly'], f"{clean}.sql")
            with open(file_path, 'w', encoding='utf-8') as out:
                out.write(chunk.strip() + '\n')
            assembly_count += 1
        elif obj_type == 'Index':
            # Clean index chunk: cut off any trailing ALTER TABLE
            idx_chunk = chunk.split('ALTER TABLE')[0].strip()
            tbl_match = re.search(r'ON\s+\[dbo\]\.\[(\w+)\]', idx_chunk)
            if tbl_match:
                tbl = tbl_match.group(1)
                table_extras.setdefault(tbl, []).append(idx_chunk)
            else:
                print(f"Could not find table for index {clean}")

    # Now let's find the ALTER TABLE statements that were after the indexes
    # Look at the chunk of the last index (IX_tblShipment1)
    last_index_chunk = [c for t, n, c in extracted_objects if t == 'Index' and 'IX_tblShipment1' in n][0]
    # Check if ALTER TABLE ... ADD DEFAULT is in it
    alter_matches = list(re.finditer(r'ALTER TABLE\s+\[dbo\]\.\[(\w+)\]\s+ADD\s+DEFAULT[^\n;]+FOR\s+\[\w+\]\s*\nGO', content))
    print(f"Found {len(alter_matches)} ALTER TABLE DEFAULT statements")
    for am in alter_matches:
        tbl = am.group(1)
        statement = am.group(0).strip()
        table_extras.setdefault(tbl, []).append(statement)

    # Now write each table with its extras (indexes and default constraints)
    for tbl, chunk in table_files.items():
        # Remove any leaked ALTER TABLE from the table chunk if present
        table_code = chunk.strip()
        
        # If this table was the last one before index, it might not contain alters because alters were after IX_tblShipment1.
        # But if IX_tblShipment1 chunk contained alters, clean it:
        extras = table_extras.get(tbl, [])
        if extras:
            table_code += "\n\n-- Indexes & Constraints\n" + "\n\n".join(extras)
        
        file_path = os.path.join(dirs['Table'], f"{tbl}.sql")
        with open(file_path, 'w', encoding='utf-8') as out:
            out.write(table_code + '\n')

    # Also make sure types/.gitkeep exists
    with open(os.path.join(dirs['Type'], '.gitkeep'), 'w') as f:
        pass

    print(f"Done splitting:")
    print(f"  Tables: {table_count}")
    print(f"  Views: {view_count}")
    print(f"  Functions: {func_count}")
    print(f"  Stored Procedures: {proc_count}")
    print(f"  Assemblies: {assembly_count}")

if __name__ == '__main__':
    main()
