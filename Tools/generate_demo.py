"""Generate an original uncopyrighted geometry stress scene for the Metal loader."""
from pathlib import Path
import json
from gltf_to_raven import write_scene

vertices, indices = [], []

def box(cx,cy,cz,sx,sy,sz,color):
    x0,x1=cx-sx/2,cx+sx/2
    y0,y1=cy-sy/2,cy+sy/2
    z0,z1=cz-sz/2,cz+sz/2
    pts=[(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
         (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    faces=[(0,1,2,3),(5,4,7,6),(4,0,3,7),(1,5,6,2),(3,2,6,7),(4,5,1,0)]
    for face in faces:
        base = len(vertices)
        for i in face:
            x,y,z=pts[i];vertices.append((x,y,z,1,*color,1))
        indices.extend([base,base+1,base+2,base,base+2,base+3])

box(0,-.25,-2, 32,.5,50,(.23,.29,.25))
box(-16,2,-2, .5,4,50,(.31,.39,.43))
box(16,2,-2, .5,4,50,(.31,.39,.43))
box(0,2,-27, 32,4,.5,(.39,.41,.47))
box(-4,.75,-11, 3,1.5,2,(.57,.42,.23))
box(5,1,-14, 2,2,3,(.48,.58,.53))
box(0,1,-5.5, 1,2,1,(.81,.26,.20))
if __name__ == '__main__':
    asset_dir = Path(__file__).resolve().parents[1] / 'Assets'
    write_scene(asset_dir / 'demo.rvn', vertices, indices)
    def bounds(x, y, z, sx, sy, sz):
        return {'min': [x-sx/2, y-sy/2, z-sz/2], 'max': [x+sx/2, y+sy/2, z+sz/2]}
    metadata = {
        'schemaVersion': 1, 'name': 'Original diagnostic range',
        'playerSpawn': [0, 1.65, 4],
        'boxes': [bounds(-16,2,-2,.5,4,50), bounds(16,2,-2,.5,4,50),
                  bounds(0,2,-27,32,4,.5), bounds(-4,.75,-11,3,1.5,2),
                  bounds(5,1,-14,2,2,3)],
        'targets': [bounds(0,1,-5.5,1,2,1)]
    }
    (asset_dir / 'demo.level.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print('Wrote original geometric test scene and sidecar.')
