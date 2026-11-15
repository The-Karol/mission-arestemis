"""Bake ink plates from the same glTF surfaces used by the assembly hall."""
import json
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLATES = {
    "engine_s": "engines/rutherford", "engine_m": "engines/merlin_1d",
    "engine_l": "engines/rs25", "tank_s": "stages/upper_stage_body",
    "tank_m": "stages/second_stage_body", "tank_l": "stages/first_stage_body",
    "booster_s": "stages/booster_small", "booster_m": "stages/booster_medium",
    "interstage": "stages/interstage", "fairing_s": "fairings/fairing_small",
    "fairing_l": "fairings/fairing_large", "avionics": "stages/transition_ring",
    "payload": "stages/payload_adapter",
}
WIDTH, HEIGHT = 192, 256


def transform(p, node):
    x, y, z = [a*b for a, b in zip(p, node.get("scale", (1, 1, 1)))]
    a, b, c, w = node.get("rotation", (0, 0, 0, 1))
    u, v, t = 2*(b*z-c*y), 2*(c*x-a*z), 2*(a*y-b*x)
    tx, ty, tz = node.get("translation", (0, 0, 0))
    return (x+w*u+b*t-c*v+tx, y+w*v+c*u-a*t+ty, z+w*t+a*v-b*u+tz)


def geometry(path, isometric=False):
    raw = path.read_bytes()
    length, = struct.unpack_from("<I", raw, 12)
    doc = json.loads(raw[20:20+length])
    binary = raw[length+28:]
    def accessor(index):
        a = doc["accessors"][index]
        view = doc["bufferViews"][a["bufferView"]]
        code = {5121:"B",5123:"H",5125:"I",5126:"f"}[a["componentType"]]
        fmt = struct.Struct("<"+code*({"SCALAR":1,"VEC3":3}[a["type"]]))
        start = a.get("byteOffset",0)+view.get("byteOffset",0)
        return [fmt.unpack_from(binary, start+i*view.get("byteStride",fmt.size)) for i in range(a["count"])]
    def visit(index, parents):
        node = doc["nodes"][index]
        chain = [node]+parents
        if "mesh" in node:
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                points = []
                for point in accessor(prim["attributes"]["POSITION"]):
                    for item in chain:
                        point = transform(point,item)
                    x,y,z = point
                    if isometric:
                        across, depth = x*0.82-z*0.57, x*0.57+z*0.82
                        points.append((across,-y*0.89+depth*0.455,depth*0.89+y*0.455))
                    else:
                        across, depth = x*0.96-z*0.28, x*0.28+z*0.96
                        points.append((across, -y*0.997+depth*0.075, depth*0.997+y*0.075))
                indices = [i[0] for i in accessor(prim["indices"])]
                for i in range(0,len(indices),3):
                    yield [points[j] for j in indices[i:i+3]], (index, prim.get("material",0))
        for child in node.get("children",[]):
            yield from visit(child,chain)
    for root in doc["scenes"][0]["nodes"]:
        yield from visit(root,[])


def plate(path, target, isometric=False):
    faces = list(geometry(path,isometric))
    xy = [p for points,_ in faces for p in points]
    xmin, ymin = min(p[0] for p in xy), min(p[1] for p in xy)
    xmax, ymax = max(p[0] for p in xy), max(p[1] for p in xy)
    scale = min((WIDTH-6)/(xmax-xmin), (HEIGHT-6)/(ymax-ymin))
    w, h = math.ceil((xmax-xmin)*scale)+5, math.ceil((ymax-ymin)*scale)+5
    depth, groups, tones = [-1e20]*(w*h), [None]*(w*h), [0.]*(w*h)
    for points, group in faces:
        (ax,ay,az),(bx,by,bz),(cx,cy,cz) = [((x-xmin)*scale+2,(y-ymin)*scale+2,z*scale) for x,y,z in points]
        area = (bx-ax)*(cy-ay)-(cx-ax)*(by-ay)
        if abs(area)<0.0001: continue
        dx = ((bz-az)*(cy-ay)-(cz-az)*(by-ay))/area
        dy = ((bx-ax)*(cz-az)-(cx-ax)*(bz-az))/area
        tone = (0.55*dx+0.32*dy+0.35)/math.sqrt(1+dx*dx+dy*dy)
        for y in range(int(min(ay,by,cy)),math.ceil(max(ay,by,cy))+1):
            for x in range(int(min(ax,bx,cx)),math.ceil(max(ax,bx,cx))+1):
                u = ((x-ax)*(cy-ay)-(y-ay)*(cx-ax))/area
                v = ((bx-ax)*(y-ay)-(by-ay)*(x-ax))/area
                if u<0 or v<0 or u+v>1: continue
                z = az+u*(bz-az)+v*(cz-az)
                k=y*w+x
                if z>depth[k]:
                    depth[k], groups[k], tones[k] = z,group,tone
    scan = bytearray()
    for y in range(h):
        scan.append(0)
        for x in range(w):
            k=y*w+x
            alpha=0
            if groups[k] is not None:
                neighbours=(k-1,k+1,k-w,k+w)
                edge=any(groups[n]!=groups[k] or abs(tones[n]-tones[k])>0.20 or abs(depth[n]-depth[k])>3.4 for n in neighbours)
                alpha=248 if edge else int(16+37*(0.8-tones[k]))
                if not edge and tones[k]<0 and (x+y)%7==0: alpha+=40
            scan.extend((255,alpha))
    def chunk(kind,data):
        return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data))
    target.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">2I5B",w,h,8,4,0,0,0))+chunk(b"IDAT",zlib.compress(scan,9))+chunk(b"IEND",b""))


if __name__ == "__main__":
    folder = ROOT/"assets/ui/plates"
    folder.mkdir(parents=True,exist_ok=True)
    PLATES.update({"be4":"engines/be4","rl10c2":"engines/rl10c2","be3u":"engines/be3u","booster_heavy":"stages/booster_heavy"})
    for key, model in PLATES.items():
        plate(ROOT/"assets/models/rocket"/(model+".glb"),folder/(key+".png"))
    parts = json.loads((ROOT/"data/spacecraft_components.json").read_text(encoding="utf8"))
    models = ROOT/"assets/models/spacecraft"
    used = {models/"modules"/(part["model"]+".glb") for part in parts}
    used.update(p for p in models.glob("*/*.glb") if p.parent.name != "modules")
    for model in sorted(used):
        plate(model,folder/(model.stem+".png"),True)
