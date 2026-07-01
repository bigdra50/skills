---
description: "Blenderシーンを検査後、Unity向けFBXとしてエクスポートする。検査FAILがあれば中断。"
---

# /blender-export

検査を実行し、PASSした場合のみFBXエクスポートを行う。

## 手順

### 1. 検査実行

/blender-inspect の手順を実行する。FAILが残っている場合はエクスポートを中断し、修正が必要な項目をユーザーに報告する。

### 2. エクスポート前処理

以下を `execute_blender_code` で実行:

```python
import bpy

# Triangulate（未適用のメッシュに対して）
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        bpy.context.view_layer.objects.active = obj
        # 既にTriangulateモディファイアがなければ追加・適用
        has_tri = any(m.type == 'TRIANGULATE' for m in obj.modifiers)
        if not has_tri:
            mod = obj.modifiers.new(name="Triangulate", type='TRIANGULATE')
            mod.quad_method = 'BEAUTY'
            bpy.ops.object.modifier_apply(modifier=mod.name)

# Camera, Light を選択解除
for obj in bpy.context.scene.objects:
    obj.select_set(obj.type == 'MESH')

result = {"prepared": True, "mesh_count": sum(1 for o in bpy.context.scene.objects if o.type == 'MESH' and o.select_get())}
```

### 3. FBXエクスポート

```python
import bpy
import os
from datetime import datetime

export_dir = os.path.join(bpy.path.abspath("//"), "..", "exports")
if not os.path.exists(export_dir):
    export_dir = "/tmp/blender-lab-exports"
    os.makedirs(export_dir, exist_ok=True)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
filename = f"export_{timestamp}.fbx"
filepath = os.path.join(export_dir, filename)

bpy.ops.export_scene.fbx(
    filepath=filepath,
    use_selection=True,
    apply_scale_options='FBX_SCALE_UNITS',
    axis_forward='-Z',
    axis_up='Y',
    use_mesh_modifiers=True,
    mesh_smooth_type='FACE',
    use_tspace=True,
    path_mode='COPY',
    embed_textures=True,
)

# 結果集計
tri_count = 0
for obj in bpy.context.selected_objects:
    if obj.type == 'MESH':
        depsgraph = bpy.context.evaluated_depsgraph_get()
        eval_obj = obj.evaluated_get(depsgraph)
        tri_count += sum(len(p.vertices) - 2 for p in eval_obj.data.polygons)

result = {
    "exported": True,
    "filepath": filepath,
    "triangle_count": tri_count,
    "settings": {
        "forward": "-Z",
        "up": "Y",
        "apply_transform": True,
        "scale": "FBX_SCALE_UNITS",
    },
}
```

### 4. 結果レポート

```
=== Export Report ===
File: exports/export_20260412_143000.fbx
Triangles: 2,700
Objects: 5
Settings: Forward=-Z Up=Y ApplyTransform=ON FBXUnitScale

Inspection: ALL PASS
Export: SUCCESS
```
