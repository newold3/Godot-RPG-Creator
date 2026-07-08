import os
import subprocess
import shutil
import stat
import time

## Configuration for the AI context sync tool
OUTPUT_FILE = "full_project_code.txt"
EXTENSIONS = (".gd", ".shader", ".json")
IGNORE_DIRS = {".godot", ".git", ".import", "export"}
REMOTE_URL = "https://github.com/newold3/rpg_creator_ia_source.git"
BRANCH_NAME = "main"

def remove_readonly(func, path, excinfo):
    ## Forces removal of read-only files (common in .git folder on Windows)
    os.chmod(path, stat.S_IWRITE)
    func(path)

def run_command(command, cwd=None):
    try:
        subprocess.run(command, check=True, shell=True, capture_output=True, text=True, cwd=cwd)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error: {e.stderr}")
        return False

def generate_project_context():
    file_count = 0
    with open(OUTPUT_FILE, "w", encoding="utf-8") as outfile:
        outfile.write("### PROJECT STRUCTURE (TREE)\n\n")
        for root, dirs, files in os.walk("."):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            level = root.replace(os.getcwd(), '').count(os.sep)
            indent = ' |   ' * level
            outfile.write(f"{indent}|-- {os.path.basename(root)}/\n")
            for f in files:
                if f.endswith(EXTENSIONS):
                    outfile.write(f"{' |   ' * (level + 1)}|-- {f}\n")
        
        outfile.write("\n\n")
        for root, dirs, files in os.walk("."):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            for file in files:
                if file.endswith(EXTENSIONS):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, "r", encoding="utf-8") as infile:
                            outfile.write(f"{'='*80}\nPATH: {os.path.normpath(file_path)}\n{'='*80}\n")
                            outfile.write(infile.read())
                            outfile.write("\n\n")
                            file_count += 1
                    except:
                        continue
    return file_count

def sync_isolated(total_files):
    temp_dir = "temp_ai_sync"
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir, onexc=remove_readonly)
    os.makedirs(temp_dir)
    
    try:
        ## Move the generated file to the clean folder
        shutil.move(OUTPUT_FILE, os.path.join(temp_dir, OUTPUT_FILE))
        
        ## Isolated Git commands
        run_command("git init", cwd=temp_dir)
        run_command(f"git remote add origin {REMOTE_URL}", cwd=temp_dir)
        run_command("git checkout -b main", cwd=temp_dir)
        run_command(f"git add {OUTPUT_FILE}", cwd=temp_dir)
        run_command(f'git commit -m "Update source context - Files: {total_files}"', cwd=temp_dir)
        
        print("Uploading to private repository...")
        if run_command("git push origin main --force", cwd=temp_dir):
            print("Success: Private repository updated.")
        else:
            print("Error: Could not push to GitHub.")
            
    finally:
        ## Comenta estas líneas para que no borre el archivo
        # time.sleep(1)
        # if os.path.exists(temp_dir):
        #    shutil.rmtree(temp_dir, onexc=remove_readonly)
        #    print("Cleanup: Temporary folder and file removed.")
        pass # Añade este pass para que el bloque finally no quede vacío

if __name__ == "__main__":
    print("Generating context file...")
    total = generate_project_context()
    
    if total > 0:
        print(f"Total files processed: {total}")
        sync_isolated(total)
    else:
        print("No source files found.")