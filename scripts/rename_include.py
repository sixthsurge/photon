import os
import sys
import glob

path_old = sys.argv[1]
path_new = sys.argv[2]
path_old_from_root = f"shaders/{path_old}"
path_new_from_root = f"shaders/{path_new}"

# Rename file 

if not os.path.isfile(path_old_from_root):
    raise RuntimeError(f"{path_old_from_root} is not a file")

os.rename(path_old_from_root, path_new_from_root)

# Update includes

paths = glob.glob("shaders/**", recursive=True) 
extensions = [".glsl", ".fsh", ".vsh", ".csh"]

for path in paths:
    if not os.path.isfile(path):
        continue
    if not os.path.splitext(path)[1] in extensions:
        continue

    with open(path, "r") as file:
        file_content = file.read()

    file_lines = file_content.splitlines()
    updated_lines = []
    modified = False

    for line in file_lines:
        if line.startswith("#include") and path_old in line:
            line = line.replace(path_old, path_new)
            modified = True

        updated_lines.append(line)

    if modified:
        with open(path, "w") as file:
            file.write("\n".join(updated_lines))
