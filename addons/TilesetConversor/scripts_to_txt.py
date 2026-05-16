import os

# --- CONFIGURATION ---
OUTPUT_FILE = "full_project_code.txt"
# Extensions to include in the context file
EXTENSIONS = (".gd", ".shader", ".json")
# Directories to ignore completely
IGNORE_DIRS = {".godot", ".git", ".import", "export"}

def generate_project_context():
    print(f"Starting scan in directory: {os.getcwd()}")
    file_count = 0
    
    try:
        with open(OUTPUT_FILE, "w", encoding="utf-8") as outfile:
            
            # SECTION 1: VISUAL FILE TREE
            outfile.write("################################################################################\n")
            outfile.write("### PROJECT STRUCTURE (TREE)\n")
            outfile.write("################################################################################\n\n")
            
            for root, dirs, files in os.walk("."):
                # Filter ignored directories
                dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
                
                level = root.replace(os.getcwd(), '').count(os.sep)
                indent = ' |   ' * level
                folder_name = os.path.basename(root)
                outfile.write(f"{indent}|-- {folder_name}/\n")
                
                subindent = ' |   ' * (level + 1)
                for f in files:
                    if f.endswith(EXTENSIONS):
                        outfile.write(f"{subindent}|-- {f}\n")
            
            outfile.write("\n\n")

            # SECTION 2: FILE CONTENTS
            for root, dirs, files in os.walk("."):
                dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
                
                for file in files:
                    if file.endswith(EXTENSIONS):
                        file_path = os.path.join(root, file)
                        # Normalize path for readability
                        clean_path = os.path.normpath(file_path)
                        directory = os.path.dirname(clean_path)
                        
                        # --- HEADER FORMAT REQUESTED ---
                        outfile.write("================================================================================\n")
                        outfile.write(f"DIRECTORY: {directory}\n")
                        outfile.write(f"FILENAME:  {file}\n")
                        outfile.write(f"FULL PATH: {clean_path}\n")
                        outfile.write("================================================================================\n")
                        
                        try:
                            with open(file_path, "r", encoding="utf-8") as infile:
                                content = infile.read()
                                outfile.write(content)
                                outfile.write("\n\n") # Extra space between files
                            
                            print(f"Processed: {file}")
                            file_count += 1
                        except Exception as e:
                            print(f"Error reading {file}: {e}")
                            outfile.write(f"\n[ERROR READING FILE: {e}]\n\n")

        print("-" * 50)
        print(f"SUCCESS! Context generated.")
        print(f"Total files processed: {file_count}")
        print(f"File saved as: {os.path.abspath(OUTPUT_FILE)}")
        print("-" * 50)

    except Exception as e:
        print(f"CRITICAL ERROR: {e}")

if __name__ == "__main__":
    generate_project_context()