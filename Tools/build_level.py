#!/usr/bin/env python3
"""Import user-supplied glTF meshes and world markers into native scene + level sidecar.

Conventions (not BO1-specific):
  SPAWN_PLAYER : translation becomes the player's eye-height spawn position.
  COL_*        : mesh world-space AABB becomes blocking collision.
  TARGET_*     : mesh world-space AABB becomes a target.

Original T5 .ff or .map files are NOT parsed here. First export with a separately
licensed tool. Rotated colliders become conservative axis-aligned bounds.
"""
import argparse
import json
from pathlib import Path
from gltf_to_raven import load_gltf, collect, write_scene, accessor, multiply, node_transform, IDENTITY

def transformed_bounds(mesh, matrix, obj, buffers, scale):
    coords = []
    for prim in mesh.get('primitives', []):
        ai = prim.get('attributes', {}).get('POSITION')
        if ai is None:
            continue
        for xyz in accessor(obj, buffers, ai):
            pos = [*xyz[:3], 1.0]
            coords.append([sum(matrix[r][c] * pos[c] for c in range(4)) * scale for r in range(3)])
    if not coords:
        raise ValueError('Marker mesh has no POSITION data')
    return {'min': [min(c[i] for c in coords) for i in range(3)],
            'max': [max(c[i] for c in coords) for i in range(3)]}

def build_metadata(obj, buffers, scale=1.0, name='Imported scene'):
    nodes = obj.get('nodes', [])
    scenes = obj.get('scenes', [])
    selected = obj.get('scene', 0)
    roots = scenes[selected].get('nodes', []) if scenes else list(range(len(nodes)))
    result = {'schemaVersion': 1, 'name': name, 'playerSpawn': [0, 1.65, 4],
              'boxes': [], 'targets': []}
    spawn_count = 0

    def walk(i, parent, visited):
        nonlocal spawn_count
        if i in visited:
            raise ValueError('Cycle in glTF scene tree')
        node = nodes[i]
        matrix = multiply(parent, node_transform(node))
        key = node.get('name', '').upper()
        if key == 'SPAWN_PLAYER':
            result['playerSpawn'] = [matrix[r][3] * scale for r in range(3)]
            spawn_count += 1
        if key.startswith(('COL_', 'TARGET_')):
            if 'mesh' not in node:
                raise ValueError(f'Named marker {key} requires a mesh')
            bounds = transformed_bounds(obj['meshes'][node['mesh']], matrix, obj, buffers, scale)
            result['boxes' if key.startswith('COL_') else 'targets'].append(bounds)
        for child in node.get('children', []):
            walk(child, matrix, visited | {i})

    for root in roots:
        walk(root, IDENTITY, set())
    if spawn_count > 1:
        raise ValueError('Multiple SPAWN_PLAYER markers are ambiguous')
    if not result['boxes']:
        print('WARNING: no COL_* markers, scene has no blocking collision')
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='Owned/authorized glTF export (.gltf or .glb)')
    parser.add_argument('output_folder', type=Path)
    parser.add_argument('--scale', type=float, default=1.0)
    parser.add_argument('--name', default='Imported scene')
    args = parser.parse_args()
    if args.scale <= 0 or args.scale > 100000:
        parser.error('scale must be between 0 and 100000')
    obj, buffers = load_gltf(args.input)
    vertices, indices = collect(obj, buffers, scale=args.scale)
    metadata = build_metadata(obj, buffers, scale=args.scale, name=args.name)
    args.output_folder.mkdir(parents=True, exist_ok=True)
    write_scene(args.output_folder / 'scene.rvn', vertices, indices)
    (args.output_folder / 'scene.level.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    print(f'Wrote {len(indices)//3} triangles; {len(metadata["boxes"])} blockers, '
          f'{len(metadata["targets"])} targets to {args.output_folder}')

if __name__ == '__main__':
    main()
