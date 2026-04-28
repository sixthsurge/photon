import zipfile, os, pathlib

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / "Photon_1.3b.zip"
INCLUDE = ["shaders", "LICENSE", "README.md"]

with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    for item in INCLUDE:
        p = ROOT / item
        if p.is_dir():
            for f in p.rglob("*"):
                if f.is_file():
                    z.write(f, f.relative_to(ROOT))
        elif p.is_file():
            z.write(p, p.relative_to(ROOT))

print(f"Built: {OUT.name} ({OUT.stat().st_size / 1024:.0f} KB)")
