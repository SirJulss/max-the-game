"""Author original Max VFX as Pixel Composer HLSL + Glow + Export node graphs.

This tool writes editable PXC projects; Pixel Composer itself renders the PNGs.
The public PXC loader supports JSON and PXCX/zlib containers. No image renderer
is used here. CLI reference: https://docs.pixel-composer.com/misc/command_line.html
Source format: Ttanasart-pt/Pixel-Composer scripts/load_function/load_function.gml.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
KINDS = ["ring", "disc", "swipe", "charge", "crosshair", "impact", "slash",
         "projectile", "jet_flame", "puddle", "bottle", "shadow", "halo"]


def read_pxc(path: Path) -> dict:
    raw = path.read_bytes()
    if raw[:4] == b"PXCX":
        raw = raw[struct.unpack_from("<I", raw, 4)[0]:]
    try:
        raw = zlib.decompress(raw)
    except zlib.error:
        pass
    return json.loads(raw.rstrip(b"\0"))


def write_pxc(path: Path, project: dict) -> None:
    # Compact native envelope; a thumbnail is optional in Pixel Composer.
    metadata = struct.pack("<I", 121070) + b"1.21.7\0"
    header = b"PXCX" + struct.pack("<I", 16 + len(metadata))
    header += b"META" + struct.pack("<I", len(metadata)) + metadata
    raw = json.dumps(project, ensure_ascii=False, separators=(",", ":")).encode() + b"\0"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + zlib.compress(raw, 9))


def value(data, **extra):
    return {"def_val": data, "r": {"d": data}, "m": 1, "unit": 0, **extra}


def node(kind, name, inputs, x, y):
    return {"version": 121070, "type": kind, "name": name, "iname": name,
            "id": name, "x": x, "y": y, "renamed": True, "renamedManual": True,
            "inputs": inputs, "outputs": [{}], "attriTool": {},
            "attri": {"process": True, "show_preview": True, "preview_size": 128,
                      "color_depth": 1, "cache": False, "show_timeline": False}}


def connection(name):
    return value(-4, from_node=name, from_index=0)


COMMON = """// Original Max: Chat Has Hands effect, rendered in Pixel Composer.
// Timeline keyframes drive effect_phase; native Render Spritesheet packs 12frames.
// Every frame is centered at (64,64), nominal radius48 plus16px glow margin.
float t = effect_phase;
float2 q = floor(input.uv * 128.0) + 0.5 - 64.0;
float r = length(q);
float angle = atan2(q.y, q.x);
float a = 0.0;
float3 rgb = float3(1.0, 1.0, 1.0);
"""

RECIPES = {
    "ring": "a = (r<=48.0 && r>=44.0+sin(t*6.283)) ? (1.0 - t*0.25) : 0.0; if(abs(r-(12.0+32.0*t))<1.2) a=max(a,0.45*(1.0-t));",
    "disc": "a = r <= 48.0 ? 0.07 : 0.0; if(r <= 48.0*(0.08+0.92*t)) a = 0.42; if(abs(r-46.5)<1.5) a=0.95;",
    "swipe": "float edge = acos(0.1); if(r <= 48.0 && abs(angle) <= edge) a=0.12; if(abs(r-46.0)<2.0 && abs(angle)<=edge) a=0.9; float scan=-edge+2.0*edge*t; if(abs(angle-scan)<0.08 && r<48.0) a=0.65;",
    "charge": "if(abs(q.x)<48.0 && abs(q.y)<19.0) a=0.16; if(abs(q.x)<48.0 && abs(abs(q.y)-18.0)<1.5) a=0.9; if(q.x>34.0 && abs(q.y)<(48.0-q.x)*0.9) a=1.0; float dash=frac((q.x+48.0)/19.0-t); if(abs(q.y)<4.0 && dash<0.45 && q.x<35.0) a=0.7;",
    "crosshair": "if(abs(r-45.5)<2.0) a=0.62; if((abs(q.x)<2.0 && abs(q.y)>32.0 && abs(q.y)<48.0)||(abs(q.y)<2.0 && abs(q.x)>32.0 && abs(q.x)<48.0)) a=1.0; if(abs(q.x)<4.0 && abs(q.y)<4.0) a=0.75+0.25*sin(t*6.283);",
    "impact": "float spokes=pow(abs(cos(angle*4.0+t*1.5)),12.0); float reach=12.0+36.0*min(t*2.5,1.0); if(r<reach*(0.3+0.7*spokes) && r>max(0.0,(t-0.3)*50.0)) a=1.0-t*0.78; if(abs(r-reach)<1.7 && t<0.6) a=max(a,0.5*(1.0-t));",
    "slash": "float arc=abs(angle-(t-0.5)*1.4); float rad=34.0+10.0*t; if(arc<1.4 && abs(r-rad)<(5.5-3.0*t)*(1.0-arc/1.8)) a=1.0-t*0.35; if(arc<1.2 && abs(r-(rad-8.0))<1.0) a=max(a,0.4*(1.0-t));",
    "projectile": "float2 p=q/float2(1.0,0.55); if(abs(p.x)<36.0 && abs(p.y)<9.0) a=0.88; if(p.x>=22.0 && p.x<48.0 && abs(p.y)<(48.0-p.x)*0.8) a=1.0; if(q.x<0.0 && q.x>-48.0 && abs(q.y)<4.0+2.0*sin(t*17.0+q.x*0.5)) a=max(a,(0.3+0.3*frac(t*3.0))*(1.0+q.x/48.0));",
    "jet_flame": "float width=5.0+(48.0-q.x)*0.25; float flicker=sin(q.x*0.42+t*12.0)*2.2; if(q.x>-38.0 && q.x<48.0 && abs(q.y+flicker)<width*(q.x+38.0)/86.0) a=0.6; if(q.x>-15.0 && q.x<38.0 && abs(q.y)<width*0.42) a=1.0;",
    "puddle": "float edge=43.0+3.0*sin(angle*5.0)+2.0*cos(angle*9.0); if(r<edge){ a=0.75; rgb=float3(0.72,0.43,0.12); } if(r>edge-3.0 && r<edge){ a=0.95;rgb=float3(1.0,0.86,0.47); } float bubbles=sin(q.x*0.46+t*3.0)*cos(q.y*0.39-t*2.0); if(r<edge-5.0 && bubbles>0.92){a=0.9;rgb=float3(1.0,0.95,0.73);}",
    "bottle": "if(abs(q.x)<13.0 && q.y>-13.0 && q.y<40.0){a=1.0;rgb=float3(0.28,0.46,0.19);} if(abs(q.x)<6.0 && q.y>-40.0 && q.y<=-13.0){a=1.0;rgb=float3(0.42,0.65,0.27);} if(abs(q.x)<8.0 && q.y>-42.0 && q.y<-37.0){a=1.0;rgb=float3(0.93,0.85,0.55);} if(abs(q.x)<12.0 && q.y>0.0 && q.y<20.0){a=1.0;rgb=float3(0.96,0.85,0.53);} if(q.x>-9.0 && q.x<-6.0 && q.y>-7.0 && q.y<33.0){a=1.0;rgb=float3(0.68,0.81,0.46);}",
    "shadow": "a = r < 48.0 ? pow(max(0.0,1.0-r/48.0),0.75)*(0.76+0.04*sin(t*6.283)) : 0.0;",
    "halo": "a = r < 48.0 ? pow(max(0.0,1.0-r/48.0),1.8)*(0.75+0.12*sin(t*6.283)) : 0.0;",
}


def build_project(output_dir: Path, kinds=KINDS):
    solid = node("Node_Solid", "Max_Frame_Canvas", [value([128, 128]), value(0), value(False)], -420, 0)
    solid["inputs"][0]["attri"] = {"use_project_dimension": 0}
    nodes = [solid]
    for row, kind in enumerate(kinds):
        phase = value(0.0, anim=True)
        phase["r"] = [[[0,0],0.0,[0,1],[0,0],0,0,True,0], [[0,11],1.0,[0,1],[0,0],0,0,True,0]]
        formula = RECIPES[kind]
        if kind == "bottle":
            formula += " if(a>0.0 && abs(q.y-(-30.0+60.0*t))<1.5) rgb=lerp(rgb,float3(1.0,1.0,0.85),0.35);"
        shader = node("Node_HLSL", "Max_"+kind,
                      [value(""), value(COMMON+formula+"\noutput.color=float4(rgb,a);"),
                       connection(solid["id"]), value(""), value(""), value("effect_phase"), value(0), phase], -100, row*240)
        shader.update(input_fix_len=5, data_length=3)
        nodes.append(shader)
        glow_values = [-4, 0, 3.0, 0.27, 0xffffffff, -4, 1, True, False, 0, 1, True, 0, 3, True]
        glow_inputs = [value(v) for v in glow_values]
        glow_inputs[0] = connection(shader["id"])
        glow = node("Node_Glow", "Max_"+kind+"_Baked_Glow", glow_inputs, 180, row*210)
        nodes.append(glow)
        for suffix, source in [("",shader),("_glow",glow)]:
            sheet_vals = [-4,0,1,0,12,0,0,[0,0,0,0],[1,12],[0,0],False,False,False]
            sheet_inputs = [value(v) for v in sheet_vals]
            sheet_inputs[0] = connection(source["id"])
            sheet = node("Node_Render_Sprite_Sheet", "Sheet_"+kind+suffix, sheet_inputs, 460 if not suffix else 740, row*240)
            nodes.append(sheet)
            vals = [-4, output_dir.as_posix()+"/", "%d%n", 0, 0, True, False, .02,
                    24, 0, 23, 0, [1,12], 2, 1, False, True, False, 2, 1, kind+suffix, 0, False, 2]
            inputs = [value(v) for v in vals]
            inputs[0] = connection(sheet["id"])
            export = node("Node_Export", "Export_"+kind+suffix, inputs, 1010 if not suffix else 1270, row*240)
            export["attri"]["clear_directory"] = False
            nodes.append(export)
    return {"version":121070, "nodes":nodes, "attributes": {
                "surface_dimension":[128,128], "color_depth":1, "oversample":3,
                "interpolate":0, "palette_fix":False, "strict":False, "autosave":False,
                "export_dir":output_dir.as_posix()+"/"},
            "animator":{"framerate":24,"frames_total":12,"playback":0},
            "global_node":{"inputs":[],"attri":{}}, "load_layout":False,
            "previewNode":"Max_impact" if "impact" in kinds else "Max_"+kinds[0],
            "notes":[], "data":{}, "freeze":False,
            "metadata":{"author":"Max: Chat Has Hands","description":"Original animated pixel VFX; timeline keyframes drive HLSL, native Glow bakes bloom before Render Spritesheet. 12x128 cells, nominal radius48."}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT/"Assets/FX/PixelComposer")
    parser.add_argument("--project", type=Path, default=ROOT/"Art/PixelComposer/Max-VFX.pxc")
    parser.add_argument("--kind", choices=KINDS, action="append")
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    project = build_project(output_dir, args.kind or KINDS)
    write_pxc(args.project, project)
    # Human-readable companion makes all original formulas reviewable in git.
    args.project.with_suffix(".json").write_text(json.dumps(project,indent=2),encoding="utf8")
    print(args.project.resolve())


if __name__ == "__main__":
    main()
