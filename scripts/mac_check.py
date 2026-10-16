#!/usr/bin/env python3
"""
Static macOS compatibility checker for Photon.

Simulates what Iris does on Apple Silicon (OpenGL 4.1 core over Metal):
resolves #includes, applies a settings profile, injects Iris' standard macros
(MC_OS_MAC etc.), then compiles every enabled program with glslangValidator at
GLSL 4.10 and counts the samplers each stage actually uses. Apple's driver
rejects any stage that uses more than 16 samplers, and has no compute shaders,
image load/store or SSBOs.

Usage: scripts/mac_check.py [--profile low|medium|high|ultra] [--set OPT=VAL ...]
                            [--dh] [--world world0] [--no-mac] [-v]
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shaders")
ROOT = os.path.normpath(ROOT)
MAX_SAMPLERS = 16
# GL_SAMPLER_* / GL_INT_SAMPLER_* / GL_UNSIGNED_INT_SAMPLER_* enums
SAMPLER_TYPES = set(range(0x8b5d, 0x8b65)) | set(range(0x8dc0, 0x8dd9)) \
    | set(range(0x900c, 0x9010)) | set(range(0x9108, 0x910e))
RENDER_STAGES = ("NONE SKY SUNSET CUSTOM_SKY SUN MOON STARS VOID TERRAIN_SOLID TERRAIN_CUTOUT_MIPPED TERRAIN_CUTOUT ENTITIES BLOCK_ENTITIES DESTROY OUTLINE DEBUG HAND_SOLID TERRAIN_TRANSLUCENT TRIPWIRE PARTICLES CLOUDS RAIN_SNOW WORLD_BORDER HAND_TRANSLUCENT").split()
STAGES = {".vsh": "vert", ".fsh": "frag", ".gsh": "geom", ".csh": "comp"}

INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"')
DEFINE_RE = re.compile(r'^(\s*)(//\s*)?#define\s+(\w+)(\s+[^/\n]*)?(.*)$')


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def resolve_includes(path, seen=None):
    out = []
    for line in read(path).splitlines():
        m = INCLUDE_RE.match(line)
        if m:
            inc = m.group(1)
            inc_path = os.path.join(ROOT, inc.lstrip("/")) if inc.startswith("/") \
                else os.path.join(os.path.dirname(path), inc)
            out.append(resolve_includes(os.path.normpath(inc_path), seen))
        else:
            out.append(line)
    return "\n".join(out)


def apply_options(src, opts):
    """opts: name -> True/False/str value. Rewrites #define lines in settings."""
    if not opts:
        return src
    lines = []
    for line in src.splitlines():
        m = DEFINE_RE.match(line)
        if m and m.group(3) in opts:
            name, val = m.group(3), opts[m.group(3)]
            has_value = m.group(4) and m.group(4).strip()
            if has_value:
                if isinstance(val, str):
                    line = f"#define {name} {val}"
            else:
                line = f"#define {name}" if val is True else f"// #define {name}"
        lines.append(line)
    return "\n".join(lines)


def parse_profiles():
    profiles = {}
    for line in read(os.path.join(ROOT, "shaders.properties")).splitlines():
        m = re.match(r"^profile\.(\w+)\s*=\s*(.*)$", line)
        if not m:
            continue
        opts = {}
        for tok in m.group(2).split():
            if tok.startswith("!"):
                opts[tok[1:]] = False
            elif "=" in tok:
                k, v = tok.split("=", 1)
                opts[k] = v
            else:
                opts[tok] = True
        profiles[m.group(1)] = opts
    return profiles


def iris_macros(mac, dh, mc=12001):
    m = [
        f"MC_VERSION {mc}", "MC_GL_VERSION 410" if mac else "MC_GL_VERSION 460",
        "MC_GLSL_VERSION 410" if mac else "MC_GLSL_VERSION 460",
        "IS_IRIS", "MC_RENDER_QUALITY 1.0", "MC_SHADOW_QUALITY 1.0",
        "MC_HAND_DEPTH 0.125", "MC_NORMAL_MAP", "MC_SPECULAR_MAP",
        "MC_TEXTURE_FORMAT_LAB_PBR", "MC_TEXTURE_FORMAT_LAB_PBR_1_3",
        "IRIS_TAG_SUPPORT 2", "IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS",
        "IRIS_FEATURE_CUSTOM_TEXTURES", "IRIS_FEATURE_ENTITY_TRANSLUCENT",
        "IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE",
    ] + [f"MC_RENDER_STAGE_{s} {i}" for i, s in enumerate(RENDER_STAGES)]
    if mac:
        m += ["MC_OS_MAC", "MC_GL_VENDOR_OTHER", "MC_GL_RENDERER_OTHER"]
    else:
        m += ["MC_OS_LINUX", "MC_GL_VENDOR_NVIDIA", "MC_GL_RENDERER_GEFORCE",
              "IRIS_FEATURE_COMPUTE_SHADERS", "MC_GL_ARB_compute_shader",
              "MC_GL_ARB_shader_image_load_store"]
    if dh:
        m += ["DISTANT_HORIZONS"] + [f"DH_BLOCK_{b} {i}" for i, b in enumerate(
            "UNKNOWN LEAVES STONE WOOD METAL DIRT LAVA DEEPSLATE SNOW SAND "
            "TERRACOTTA NETHER_STONE WATER GRASS AIR ILLUMINATED".split())]
    return m


def preprocess_properties(macros):
    """Evaluate the #if blocks of shaders.properties with cpp, return text."""
    args = ["cpp", "-P", "-undef", "-traditional-cpp"]
    for d in macros:
        k, _, v = d.partition(" ")
        args.append(f"-D{k}={v}" if v else f"-D{k}")
    r = subprocess.run(args, input=read(os.path.join(ROOT, "shaders.properties")),
                       capture_output=True, text=True)
    return r.stdout


def enabled_programs(world, props, opts):
    """program.<world>/<name>.enabled = <OPTION|true|false>"""
    enabled = {}
    for line in props.splitlines():
        m = re.match(rf"^\s*program\.{re.escape(world)}/(\w+)\.enabled\s*=\s*(\S+)", line)
        if m:
            enabled[m.group(1)] = m.group(2)
    return enabled


def option_value(name, settings_src):
    """Is boolean option `name` on in the (option-applied) settings source?"""
    for line in settings_src.splitlines():
        m = DEFINE_RE.match(line)
        if m and m.group(3) == name:
            return not m.group(2)
    return None


def compile_stage(path, macros, opts):
    src = resolve_includes(path)
    src = re.sub(r"\\\n", "", src)  # Iris' preprocessor joins line continuations
    src = apply_options(src, opts)
    lines = src.splitlines()
    ver = lines[0]
    assert ver.startswith("#version"), path
    stage = STAGES[os.path.splitext(path)[1]]
    num = int(ver.split()[1])
    if stage != "comp":
        ver = f"#version {max(num, 410)} compatibility"
    body = "\n".join(lines[1:])
    header = [ver] + [f"#define {d}" for d in macros]
    if os.path.basename(path).startswith("dh_") and stage == "vert":
        header.append("in int dhMaterialId;")  # injected by Iris for DH programs
    text = "\n".join(header) + "\n#line 2\n" + body + "\n"
    with tempfile.NamedTemporaryFile("w", suffix="." + stage, delete=False) as f:
        f.write(text)
        tmp = f.name
    r = subprocess.run(["glslangValidator", "-l", "-q", "-S", stage, tmp],
                       capture_output=True, text=True)
    os.unlink(tmp)
    out = r.stdout + r.stderr
    samplers = []
    in_uniforms = False
    for line in out.splitlines():
        if line.startswith("Uniform reflection:"):
            in_uniforms = True
            continue
        if in_uniforms and (line.endswith("reflection:") or line.startswith("Buffer")):
            in_uniforms = False
        m = re.match(r"^(\w+): offset -?\d+, type ([0-9a-f]+),", line)
        if in_uniforms and m and int(m.group(2), 16) in SAMPLER_TYPES:
            samplers.append(m.group(1))
    errors = [l for l in out.splitlines() if l.startswith("ERROR")]
    return samplers, errors, text


# Texture units Iris binds itself (see IrisSamplers / ProgramSamplers):
#  - world programs (gbuffers, shadow, dh) reserve units 0-2 for the atlas,
#    lightmap and overlay
#  - fullscreen passes: Iris 1.7.x reserves units 1 and 2; colortex0 is the
#    "default sampler" and always takes unit 0, even when unused
# Units are shared by all stages of a program, so the budget applies to the
# union of vertex + fragment samplers.
WORLD_RESERVED_NAMES = {"gtexture", "texture", "tex", "lightmap", "iris_overlay", "overlay"}


def iris_budget(prog, samplers, iris):
    world = prog.startswith(("gbuffers_", "dh_", "shadow")) and not prog.startswith("shadowcomp")
    if world:
        return MAX_SAMPLERS - 3, [x for x in samplers if x not in WORLD_RESERVED_NAMES]
    reserved = 2 if iris == "legacy" else 0
    return MAX_SAMPLERS - reserved - 1, [x for x in samplers if x not in ("colortex0", "gcolor")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", default=None)
    ap.add_argument("--set", action="append", default=[])
    ap.add_argument("--dh", action="store_true")
    ap.add_argument("--world", action="append")
    ap.add_argument("--no-mac", action="store_true")
    ap.add_argument("-v", action="store_true")
    ap.add_argument("--dump")
    ap.add_argument("--mc", type=int, default=12001, help="MC_VERSION, e.g. 12001 = 1.20.1")
    ap.add_argument("--iris", choices=["legacy", "latest"], default="legacy",
                    help="legacy = Iris 1.7.x (MC 1.20.1), latest = Iris 1.9+")
    a = ap.parse_args()

    mac = not a.no_mac
    opts = {}
    if a.profile:
        opts.update(parse_profiles()[a.profile])
    for s in a.set:
        k, _, v = s.partition("=")
        opts[k] = {"true": True, "false": False}.get(v.lower(), v) if v else True

    macros = iris_macros(mac, a.dh, a.mc)
    props = preprocess_properties(macros)
    settings = apply_options(read(os.path.join(ROOT, "settings.glsl")), opts)
    worlds = a.world or ["world0", "world-1", "world1"]
    failures = 0
    programs = {}
    for world in worlds:
        wdir = os.path.join(ROOT, world)
        enabled = enabled_programs(world, props, opts)
        for fn in sorted(os.listdir(wdir)):
            base, ext = os.path.splitext(fn)
            if ext not in STAGES:
                continue
            prog = base
            if not a.dh and prog.startswith("dh_"):
                continue
            if prog.endswith("_voxels") or prog.startswith("clrwl_"):
                continue  # Voxy / Colorwheel, optional mods
            flag = enabled.get(prog)
            if flag is not None and flag not in ("true",):
                if flag == "false" or not option_value(flag.lstrip("!"), settings) ^ flag.startswith("!"):
                    continue
            path = os.path.join(wdir, fn)
            stage = STAGES[ext]
            if mac and stage == "comp":
                print(f"FAIL {world}/{fn}: compute shader (not supported on macOS GL 4.1)")
                failures += 1
                continue
            samplers, errors, text = compile_stage(path, macros, opts)
            if a.dump and a.dump == f"{world}/{fn}":
                print(text)
            programs.setdefault((world, prog), []).append((fn, samplers, errors))
    for (world, prog), stages in sorted(programs.items()):
        union = sorted({x for _, smp, _ in stages for x in smp})
        budget, counted = iris_budget(prog, union, a.iris)
        problems = []
        for fn, smp, errors in stages:
            if len(smp) > MAX_SAMPLERS:
                problems.append(f"{fn}: driver limit, {len(smp)} > {MAX_SAMPLERS} samplers in one stage")
            problems += [f"{fn}: {e}" for e in errors[:5]]
        if len(counted) > budget:
            problems.append(f"Iris ({a.iris}) texture units: {len(counted)} > {budget} -> {', '.join(counted)}")
        if problems:
            failures += 1
        if problems or a.v:
            tag = "FAIL" if problems else "ok  "
            print(f"{tag} {world}/{prog}: {len(counted)}/{budget} units"
                  + (f" [{', '.join(union)}]" if a.v else ""))
            for pr in problems:
                print("     " + pr)
    print(f"\n{failures} failing program(s)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
