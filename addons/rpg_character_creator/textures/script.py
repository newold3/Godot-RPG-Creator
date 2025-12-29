import os
import sys

# Check for Pillow library
try:
    from PIL import Image
except ImportError:
    print("\n[CRITICAL ERROR] 'Pillow' library not found.")
    print("Please run: pip install pillow")
    input("\nPress ENTER to exit...")
    sys.exit()

VALID_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".tga", ".webp"}
OUTPUT_FILENAME = "image_list.txt"


def get_image_data(file_path):
    """
    Opens an image file and returns a dictionary with its dimensions and path.
    """
    try:
        with Image.open(file_path) as img:
            return {
                "path": file_path,
                "width": img.width,
                "height": img.height,
                "area": img.width * img.height
            }
    except Exception as e:
        print(f"Error reading: {os.path.basename(file_path)} -> {e}")
        return None


def scan_directory(start_path):
    """
    Recursively scans the directory for images.
    """
    image_list = []
    print(f"Scanning directory: {start_path} ...")

    for root, _, files in os.walk(start_path):
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext in VALID_EXTENSIONS:
                full_path = os.path.join(root, file)
                data = get_image_data(full_path)
                if data:
                    image_list.append(data)
    
    return image_list


def save_grouped_file(images, root_path, output_full_path):
    """
    Groups images by size and saves them to a formatted text file.
    """
    # 1. Group by dimensions (Width x Height)
    groups = {}
    for img in images:
        key = (img['width'], img['height'])
        if key not in groups:
            groups[key] = []
        groups[key].append(img)

    # 2. Sort groups by Area (largest resolution first)
    sorted_keys = sorted(groups.keys(), key=lambda k: k[0] * k[1], reverse=True)

    try:
        with open(output_full_path, "w", encoding="utf-8") as f:
            
            # Write Main Header
            total_imgs = len(images)
            unique_sizes = len(sorted_keys)
            main_header = f"REPORT: {total_imgs} IMAGES FOUND ({unique_sizes} unique sizes)"
            f.write(main_header + "\n")
            f.write("=" * len(main_header) + "\n\n")

            # Write Sections
            for width, height in sorted_keys:
                group_list = groups[(width, height)]
                count = len(group_list)
                
                # Section Header
                section_header = f"============ {width}x{height} (Total: {count}) ============"
                f.write(section_header + "\n")
                
                # List files in this group
                for img in group_list:
                    # Get relative path for readability
                    try:
                        rel_path = os.path.relpath(img["path"], root_path)
                    except ValueError:
                        rel_path = img["path"]
                    
                    f.write(f"{rel_path}\n")
                
                # Section Footer
                f.write("=" * len(section_header) + "\n\n")
        
        print(f"\n[SUCCESS] List saved to: {output_full_path}")
        
    except IOError as e:
        print(f"\n[ERROR] Could not write to file: {e}")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, OUTPUT_FILENAME)

    images = scan_directory(script_dir)

    if not images:
        print("\n[WARNING] No images found in this directory or subdirectories.")
    else:
        save_grouped_file(images, script_dir, output_path)

    input("\nScript finished. Press ENTER to close...")


if __name__ == "__main__":
    main()