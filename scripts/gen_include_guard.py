"""
Generate or update include guards for an include file

Usage:
python3 gen_include_guard include/example.glsl
"""

import os
import sys

path_from_shaders_dir = sys.argv[1]
path_absolute = f"shaders/{path_from_shaders_dir}"
path_without_extension = os.path.splitext(path_from_shaders_dir)[0]
guard_define = path_without_extension.replace("/", "_").upper()

with open(path_absolute, "r") as f:
    file_content = f.read()

file_lines = file_content.split("\n")

# remove existing guard
if file_lines[0].startswith("#if !defined INCLUDE_"):
    file_lines = file_lines[2:-1]

file_lines.insert(0, f"#if !defined {guard_define}")
file_lines.insert(1, f"#define {guard_define}")
file_lines.append(f"#endif // {guard_define}")

with open(path_absolute, "w") as f:
    f.write("\n".join(file_lines))

