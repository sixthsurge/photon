import os 
import glob 

find = input("find: ")
replace = input("replace with: ")

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
        if find in line:
            line = line.replace(find, replace)
            modified = True

        updated_lines.append(line)

    if modified:
        with open(path, "w") as file:
            file.write("\n".join(updated_lines))
