---
description: "Blenderシーンの3層品質検査。メッシュ品質→空間→ビジュアルの順に検査し、FAIL項目は自動修正を試行する。"
---

# /blender-inspect

Blenderシーン内の全メッシュオブジェクトに対し、3層検査を実行する。

## 手順

### 1. 検査スクリプトの読み込みと実行

`scripts/inspection/full_report.py` を読み込み、`execute_blender_code` で実行する。

### 2. Layer 1結果の解析

result.layer1.objects の各オブジェクトについて:
- `no_ngons`, `no_non_manifold`, `no_loose_verts`, `no_zero_area` → falseならFAIL
- `rotation_applied`, `scale_applied` → falseならFAIL
- `naming` → falseなら警告（FAILにはしない）

### 3. Layer 2結果の解析

- `grounding` の各エントリで `pass: false` → 浮遊または沈み込み
- `overlaps` にエントリがあれば交差

### 4. FAIL項目の自動修正（最大3回ループ）

FAILが見つかった場合、以下のコードを `execute_blender_code` で実行して修正:

非多様体の除去:
```python
import bpy
obj = bpy.data.objects["<NAME>"]
bpy.context.view_layer.objects.active = obj
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='DESELECT')
bpy.ops.mesh.select_non_manifold()
bpy.ops.mesh.delete(type='EDGE')
bpy.ops.object.mode_set(mode='OBJECT')
```

浮遊頂点の除去:
```python
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='DESELECT')
bpy.ops.mesh.select_loose()
bpy.ops.mesh.delete(type='VERT')
bpy.ops.object.mode_set(mode='OBJECT')
```

退化面の除去:
```python
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.dissolve_degenerate()
bpy.ops.object.mode_set(mode='OBJECT')
```

Transform適用:
```python
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
```

浮遊オブジェクトの修正（gapが正の場合）:
```python
obj = bpy.data.objects["<NAME>"]
obj.location.z -= <gap>
```

修正後、再度 `full_report.py` を実行して再検査する。3回修正してもFAILが残る場合はユーザーに報告。

### 5. Layer 3: ビジュアル確認

Layer 1/2がすべてPASSした後:
- `get_screenshot_of_window_as_image` でスクリーンショットを取得
- 全体の見た目を確認
- 問題があればユーザーに報告

### 6. レポート出力

検査結果を構造化して報告:

```
=== Blender Inspection Report ===

[Layer 1: Mesh Quality]
  Table_01: vertices=842 tris=1680 ngons=0 non_manifold=0 loose=0  PASS
  Chair_01: vertices=512 tris=1020 ngons=2 non_manifold=0 loose=0  FAIL(ngons)
    → 自動修正実行 → 再検査 PASS

[Layer 2: Spatial]
  Table_01: grounded gap=0.001m  PASS
  Chair_01: grounded gap=0.000m  PASS
  overlaps: none  PASS

[Layer 3: Visual]
  (screenshot attached)  PASS

Result: ALL PASS
```
