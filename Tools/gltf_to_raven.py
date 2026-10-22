#!/usr/bin/env python3
"""Convert ordinary glTF 2.0 static meshes to compact, native Metal-friendly RVNMAP01.

No game files are distributed. Supports .gltf and .glb: triangles, node matrices/TRS,
32/16/8-bit indices, baseColorFactor. Not yet supported: skinning, textures, animation,
collision BVH, morphs, compressed KTX2/Draco/meshopt, transparent materials.
"""
import argparse
import base64
import json
import math
from pathlib import Path
import struct

MAGIC = b'RVNMAP01'
COMPONENT = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
COMPONENT_COUNT = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}


def load_gltf(path):
    raw = path.read_bytes()
    glb_bin = None
    if path.suffix.lower() == '.glb':
        if raw[:4] != b'glTF' or struct.unpack_from('<I', raw, 4)[0] != 2:
            raise ValueError('Not a glTF 2.0 GLB file')
        n = struct.unpack_from('<I', raw, 8)[0]
        if n != len(raw):
            raise ValueError('GLB length mismatch')
        chunks = {}; cursor = 12
        while cursor < len(raw):
            length, kind = struct.unpack_from('<II', raw, cursor)
            cursor += 8
            chunks[kind] = raw[cursor:cursor+length]; cursor += length
        obj = json.loads(chunks[0x4E4F534A]); glb_bin = chunks.get(0x004E4942)
    else:
        obj = json.loads(raw)
    buffers = []
    for i, entry in enumerate(obj.get('buffers', [])):
        uri = entry.get('uri')
        if uri and uri.startswith('data:'):
            payload = base64.b64decode(uri.split(',', 1)[1])
        elif uri:
            payload = (path.parent / uri).resolve().read_bytes()
        elif i == 0 and glb_bin is not None:
            payload = glb_bin
        else:
            raise ValueError(f'Buffer {i} has no supported source')
        if len(payload) < entry.get('byteLength', 0):
            raise ValueError(f'Truncated buffer {i}')
        buffers.append(payload)
    return obj, buffers


def accessor(obj, buffers, index):
    a = obj['accessors'][index]
    if 'sparse' in a:
        raise NotImplementedError('Sparse accessors')
    view = obj['bufferViews'][a['bufferView']]
    kind, size = COMPONENT[a['componentType']]
    n = COMPONENT_COUNT[a['type']]
    stride = view.get('byteStride', size*n)
    offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    buf = buffers[view['buffer']]
    code = '<' + kind*n
    result = []
    for i in range(a['count']):
        at = offset + i*stride
        if at + size*n > len(buf):
            raise ValueError('Accessor out of bounds')
        value = struct.unpack_from(code, buf, at)
        result.append(value if n > 1 else value[0])
    return result


def multiply(a, b):
    return [[sum(a[r][k]*b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def node_transform(node):
    if 'matrix' in node:
        m = node['matrix']
        return [[float(m[c*4+r]) for c in range(4)] for r in range(4)]
    tx,ty,tz = node.get('translation', [0,0,0])
    x,y,z,w = node.get('rotation', [0,0,0,1])
    sx,sy,sz = node.get('scale', [1,1,1])
    return [
        [(1-2*(y*y+z*z))*sx, 2*(x*y-z*w)*sy, 2*(x*z+y*w)*sz, tx],
        [2*(x*y+z*w)*sx, (1-2*(x*x+z*z))*sy, 2*(y*z-x*w)*sz, ty],
        [2*(x*z-y*w)*sx, 2*(y*z+x*w)*sy, (1-2*(x*x+y*y))*sz, tz],
        [0,0,0,1],
    ]


IDENTITY = [[1.,0.,0.,0.],[0.,1.,0.,0.],[0.,0.,1.,0.],[0.,0.,0.,1.]]


def collect(obj, buffers, scale=1.0):
    vertices, indices = [], []
    nodes = obj.get('nodes', [])
    scenes = obj.get('scenes', [])
    scene_index = obj.get('scene', 0)
    roots = scenes[scene_index].get('nodes', []) if scenes else list(range(len(nodes)))

    def walk(index, parent, ancestors):
        if index in ancestors:
            raise ValueError('Scene node cycle')
        node = nodes[index]
        matrix = multiply(parent, node_transform(node))
        mesh_index = node.get('mesh')
        if mesh_index is not None:
            mesh = obj['meshes'][mesh_index]
            for primitive in mesh['primitives']:
                if primitive.get('mode', 4) != 4:
                    continue
                attributes = primitive['attributes']
                if 'POSITION' not in attributes:
                    continue
                positions = accessor(obj, buffers, attributes['POSITION'])
                if len(vertices)+len(positions) >= (1<<32):
                    raise ValueError('Too many vertices')
                material = obj.get('materials', [])
                matidx = primitive.get('material')
                color = ([.64,.72,.81,1.] if matidx is None else
                         material[matidx].get('pbrMetallicRoughness', {}).get('baseColorFactor', [1,1,1,1]))
                base = len(vertices)
                for px,py,pz in positions:
                    new = [px,py,pz,1.]
                    transformed = [sum(matrix[r][j]*new[j] for j in range(4))*scale for r in range(3)]
                    vertices.append(tuple(transformed + [1.] + list(color[:3]) + [1.]))
                local_index = (accessor(obj, buffers, primitive['indices'])
                               if 'indices' in primitive else list(range(len(positions))))
                if len(local_index) % 3:
                    raise ValueError('Triangle index count not divisible by 3')
                for ind in local_index:
                    if ind < 0 or ind >= len(positions):
                        raise ValueError('Index outside primitive vertex range')
                    indices.append(base+ind)
        for child in node.get('children', []):
            walk(child, matrix, ancestors | {index})
    for root in roots:
        walk(root, IDENTITY, set())
    return vertices, indices


def write_scene(destination, vertices, indices):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if len(vertices) >= (1<<32) or len(indices) >= (1<<32):
        raise ValueError('32-bit index count overflow')
    with destination.open('wb') as out:
        out.write(MAGIC)
        out.write(struct.pack('<II', len(vertices), len(indices)))
        for v in vertices:
            out.write(struct.pack('<8f', *v))
        for i in indices:
            out.write(struct.pack('<I', i))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('source', type=Path, help='Static .glb or .gltf export')
    ap.add_argument('output', type=Path, help='Destination .rvn')
    ap.add_argument('--scale', type=float, default=1.0,
                    help='Uniform asset-to-meters scale (default 1; choose based on source units)')
    args = ap.parse_args()
    obj, buffers = load_gltf(args.source)
    v, i = collect(obj, buffers, args.scale)
    write_scene(args.output, v, i)
    print(f'Created {args.output}: {len(v)} vertices, {len(i)//3} triangles')


if __name__ == '__main__':
    main()
