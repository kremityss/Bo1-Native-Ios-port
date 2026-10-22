import base64
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Tools'))
from gltf_to_raven import MAGIC, load_gltf, collect, write_scene
from scan_install import scan


class PipelineTests(unittest.TestCase):
    def test_gltf_triangle_translation(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            raw = struct.pack('<9f', 0,0,0, 1,0,0, 0,1,0) + struct.pack('<3H', 0,1,2)
            model = {'asset': {'version':'2.0'},
                     'buffers':[{'byteLength':len(raw),'uri':'data:application/octet-stream;base64,'+base64.b64encode(raw).decode()}],
                     'bufferViews':[{'buffer':0,'byteLength':36},{'buffer':0,'byteOffset':36,'byteLength':6}],
                     'accessors':[{'bufferView':0,'componentType':5126,'count':3,'type':'VEC3'},
                                  {'bufferView':1,'componentType':5123,'count':3,'type':'SCALAR'}],
                     'meshes':[{'primitives':[{'attributes':{'POSITION':0},'indices':1}]}],
                     'nodes':[{'mesh':0,'translation':[2,3,4]}],
                     'scenes':[{'nodes':[0]}], 'scene':0}
            p = d/'fixture.gltf'; p.write_text(json.dumps(model))
            obj, bufs = load_gltf(p)
            verts, inds = collect(obj, bufs, scale=0.5)
            self.assertEqual(verts[0][:3], (1.0,1.5,2.0))
            self.assertEqual(inds, [0,1,2])
            out = d/'test.rvn'; write_scene(out, verts, inds)
            content = out.read_bytes()
            self.assertEqual(content[:8], MAGIC)
            self.assertEqual(struct.unpack_from('<II', content, 8), (3,3))
            self.assertEqual(len(content), 16+3*32+3*4)

    def test_scan_inventory(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'zone'; p.mkdir()
            (p/'mp_test.ff').write_bytes(b'xxxx')
            result = scan(Path(d))
            self.assertEqual(result['total_files'], 1)
            self.assertEqual(result['extensions']['.ff']['bytes'], 4)

if __name__ == '__main__':
    unittest.main()
