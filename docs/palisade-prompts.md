# Промпти частоколу Lv.1

Інструмент: вбудований `image_gen.imagegen`, прозорий фон. Кожен варіант генерується окремо. Вихідні результати генератора залишено в `.codex/generated_images`; відібрані PNG скопійовано у `assets/sprites/buildings/`.

Референси: [схема користувача](references/palisade-layout.png) з дев’ятьма прикладами з’єднань; початковий `palisade_lv1_x_grid_v1.png` для матеріалів; окремі геометричні напрямні під проєкцію 96:72. Напрямні можна відтворити командою `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/palisade_geometry_guides.gd`; вони зберігаються у `.godot/palisade-mask-XX-guide.png`.

Ролі входів: для маски 15 — напрямна, стиль початкового частоколу й схема користувача; для 00/05/10 — прийняте перехрестя як об’єкт редагування та напрямна; для решти — напрямна як об’єкт редагування і перехрестя як стильовий референс.

N/E/S/W — сусіди в логічній сітці, на екрані це відповідно верхній правий, нижній правий, нижній лівий та верхній лівий напрямки.

## 00 — Окремий стовп

```text
Use case: precise-object-edit.
Asset type: ONE transparent Lv1 modular wooden palisade tile, neighbor mask 0, logical square footprint1x1.
Input image1 is the EDIT TARGET and style master: the final four-way palisade crossing. Input image2 is the AUTHORITATIVE topology and geometry blockout for THIS specific variant.
Change ONLY which half-row arms exist. Preserve image1's thin square dirt pad outline, camera, central stake location, stake heights and thicknesses, materials, warm upper-left lighting, canvas size, scale and safe margins. Do not enlarge a remaining half-row to fill the entire tile.
KEEP these arms only: NONE; only ONE isolated pointed timber stake at the ground CENTER. REMOVE all other arms: N (upper-right), E (lower-right), S (lower-left), W (upper-left). EXACTLY 1 stakes in total. Their plan positions are center(0,0). Natural occlusion can hide part of a rear stake. Fill removed arms' former floor areas with the same packed earth. No stray stakes, rails or ropes in a removed direction. Remaining two support rails per arm run from the central stake to that side's EDGE MIDPOINT, not to diagonal corners. The center is one shared pole, never an empty gap or duplicated crossing pile.
Match image2's locked locations and geometry while preserving the rich painted3D art of image1, do not copy plain diagram colors. Ground projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80), x,y pad bounds±2.5, symmetric4:3 diamond, slopes+0.75/-0.75, no perspective convergence. The central stake foot is pad CENTER. Keep pad size and ground center visually identical to image1; no translation or zoom of the subject.
Keep squared pointed golden timber, carved grain, beveled beams and compact rope lashings, warm upper-left light and crisp cartoon3D shading. Genuine transparent alpha outside the complete pad and sprite; no gray backdrop, checkerboard, new grass, rocks, decoration, people, text, labels, UI or watermark. Output ONLY this one exact connection variant, not a sprite sheet.
```

## 01 — Кінець N

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask1, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: N upper-right. No arms at E lower-right, S lower-left, W upper-left. Exactly3 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
The central pole must not drift: keep its rear/base intersection at the exact guide center. This is a repaint of image1 with its silhouette locked, not a new composition. Keep the pad and row positions and all three post tips on the guide. Follow the guide before the material reference.
```

## 02 — Кінець E

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask2, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: E lower-right. No arms at N upper-right, S lower-left, W upper-left. Exactly3 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
The central pole must not drift: keep its rear/base intersection at the exact guide center. This is a repaint of image1 with its silhouette locked, not a new composition. Keep the pad and row positions and all three post tips on the guide. Follow the guide before the material reference.
```

## 03 — Кут N+E

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask3, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: N upper-right, E lower-right. No arms at S lower-left, W upper-left. Exactly5 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
```

## 04 — Кінець S

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask4, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: S lower-left. No arms at N upper-right, E lower-right, W upper-left. Exactly3 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
The central pole must not drift: keep its rear/base intersection at the exact guide center. This is a repaint of image1 with its silhouette locked, not a new composition. Keep the pad and row positions and all three post tips on the guide. Follow the guide before the material reference.
```

## 05 — Пряма N+S

```text
Use case: precise-object-edit.
Asset type: ONE transparent Lv1 modular wooden palisade tile, neighbor mask 5, logical square footprint1x1.
Input image1 is the EDIT TARGET and style master: the final four-way palisade crossing. Input image2 is the AUTHORITATIVE topology and geometry blockout for THIS specific variant.
Change ONLY which half-row arms exist. Preserve image1's thin square dirt pad outline, camera, central stake location, stake heights and thicknesses, materials, warm upper-left lighting, canvas size, scale and safe margins. Do not enlarge a remaining half-row to fill the entire tile.
KEEP these arms only: N (upper-right), S (lower-left). REMOVE all other arms: E (lower-right), W (upper-left). EXACTLY 5 stakes in total. Their plan positions are center(0,0), (0,-1),(0,-2), (0,1),(0,2). Natural occlusion can hide part of a rear stake. Fill removed arms' former floor areas with the same packed earth. No stray stakes, rails or ropes in a removed direction. Remaining two support rails per arm run from the central stake to that side's EDGE MIDPOINT, not to diagonal corners. The center is one shared pole, never an empty gap or duplicated crossing pile.
Match image2's locked locations and geometry while preserving the rich painted3D art of image1, do not copy plain diagram colors. Ground projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80), x,y pad bounds±2.5, symmetric4:3 diamond, slopes+0.75/-0.75, no perspective convergence. The central stake foot is pad CENTER. Keep pad size and ground center visually identical to image1; no translation or zoom of the subject.
Keep squared pointed golden timber, carved grain, beveled beams and compact rope lashings, warm upper-left light and crisp cartoon3D shading. Genuine transparent alpha outside the complete pad and sprite; no gray backdrop, checkerboard, new grass, rocks, decoration, people, text, labels, UI or watermark. Output ONLY this one exact connection variant, not a sprite sheet.
```

## 06 — Кут E+S

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask6, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: E lower-right, S lower-left. No arms at N upper-right, W upper-left. Exactly5 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
```

## 07 — Трійник N+E+S

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask7, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: N upper-right, E lower-right, S lower-left. No arms at W upper-left. Exactly7 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
```

## 08 — Кінець W

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask8, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: W upper-left. No arms at N upper-right, E lower-right, S lower-left. Exactly3 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
The central pole must not drift: keep its rear/base intersection at the exact guide center. This is a repaint of image1 with its silhouette locked, not a new composition. Keep the pad and row positions and all three post tips on the guide. Follow the guide before the material reference.
```

## 09 — Кут N+W

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask9, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: N upper-right, W upper-left. No arms at E lower-right, S lower-left. Exactly5 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
```

## 10 — Пряма E+W

```text
Use case: precise-object-edit.
Asset type: ONE transparent Lv1 modular wooden palisade tile, neighbor mask 10, logical square footprint1x1.
Input image1 is the EDIT TARGET and style master: the final four-way palisade crossing. Input image2 is the AUTHORITATIVE topology and geometry blockout for THIS specific variant.
Change ONLY which half-row arms exist. Preserve image1's thin square dirt pad outline, camera, central stake location, stake heights and thicknesses, materials, warm upper-left lighting, canvas size, scale and safe margins. Do not enlarge a remaining half-row to fill the entire tile.
KEEP these arms only: E (lower-right), W (upper-left). REMOVE all other arms: N (upper-right), S (lower-left). EXACTLY 5 stakes in total. Their plan positions are center(0,0), (1,0),(2,0), (-1,0),(-2,0). Natural occlusion can hide part of a rear stake. Fill removed arms' former floor areas with the same packed earth. No stray stakes, rails or ropes in a removed direction. Remaining two support rails per arm run from the central stake to that side's EDGE MIDPOINT, not to diagonal corners. The center is one shared pole, never an empty gap or duplicated crossing pile.
Match image2's locked locations and geometry while preserving the rich painted3D art of image1, do not copy plain diagram colors. Ground projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80), x,y pad bounds±2.5, symmetric4:3 diamond, slopes+0.75/-0.75, no perspective convergence. The central stake foot is pad CENTER. Keep pad size and ground center visually identical to image1; no translation or zoom of the subject.
Keep squared pointed golden timber, carved grain, beveled beams and compact rope lashings, warm upper-left light and crisp cartoon3D shading. Genuine transparent alpha outside the complete pad and sprite; no gray backdrop, checkerboard, new grass, rocks, decoration, people, text, labels, UI or watermark. Output ONLY this one exact connection variant, not a sprite sheet.
```

## 11 — Трійник N+E+W

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask11, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: N upper-right, E lower-right, W upper-left. No arms at S lower-left. Exactly7 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
```

## 12 — Кут S+W

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask12, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: S lower-left, W upper-left. No arms at N upper-right, E lower-right. Exactly5 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
```

## 13 — Трійник N+S+W

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask13, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: N upper-right, S lower-left, W upper-left. No arms at E lower-right. Exactly7 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
```

## 14 — Трійник E+S+W

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular palisade tile, mask14, logical1x1 square cell.
Input image1 is the EXACT GEOMETRY BLOCKOUT EDIT TARGET. Paint THIS target; LOCK its camera, pad outline, central pole, ALL stake foot locations, heights, row lengths, rail endpoints and composition. Input image2 is MATERIAL/PAINTING STYLE reference ONLY: the game's final cross junction. Do not copy image2's arm arrangement, silhouette or pole placement.
Topology: central pointed square timber stake plus ONLY these half-row arms: E lower-right, S lower-left, W upper-left. No arms at N upper-right. Exactly7 stakes total, as in the guide. Each arm has two additional stakes and two compact support rails with rope ties. One shared central pole, no empty junction gap. No leftover stakes in absent directions.
Texture guide stakes and beams with reference2's chunky amber wood grain, bevels and pointed cut tops; add compact golden-brown rope lashings around existing rail junctions. Preserve squared stake cross-sections and target stake HEIGHT. Resolve physically natural front/rear occlusion, do not flatten the art into diagram style.
CRITICAL: central stake's GROUND CONTACT is exactly at the ground diamond CENTER, not its front/back vertex. Keep guide's arm length: center to EDGE MIDPOINT, only HALF a cell, never stretch a short arm into a full-cell row. Ground plan x,y bounds±2.5; central pole x=0,y=0. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80); square pad rear(512,400),right(912,700),front(512,1000),left(112,700); stake base z=0, shoulder z=3.8, pointed tip z=4.5. Thin pad remains symmetric4:3 diamond, slopes±0.75, no perspective convergence. Uniform resize of WHOLE image permitted, never shift poles relative to pad. Use the guide as geometry, reference2 ONLY as rich painterly material finish.
Warm upper-left lighting, crisp dark material contours, polished cartoon3D game-art matching reference2. Thin packed-earth pad, no thick rim, every contact inside footprint. Replace guide gray backdrop and outlines with real transparent alpha outside finished sprite. Square canvas with safe margins, entire pad and pointed tops visible, front ground vertex lowest opaque contact. No grass, rocks, extra objects, people, text, UI, labels or watermark.
```

## 15 — Перехрестя

```text
Use case: sketch-to-render.
Asset type: ONE transparent Lv1 modular WOODEN PALISADE CROSS JUNCTION game sprite. Neighbor mask15: four arms N,E,S,W, square logical footprint1x1.
Input image1 is an exact geometry blockout. Render THIS exact layout in polished hand-painted cartoon3D art. Input image2 is STYLE AND MATERIAL reference only, the game's existing amber wooden palisade. Input image3 is the user's TOP-DOWN connection scheme; its last small square is the four-way crossing, which is the topology to render, not the flat UI style.
Subject: one CENTRAL POINTED TIMBER STAKE with four HALF-ROW palisade arms meeting at it. Each arm contains two additional tightly set pointed squared timber stakes and two cross rails tied with chunky cream-brown rope. Nine stakes total: center(0,0),(-1,0),(-2,0),(1,0),(2,0),(0,-1),(0,-2),(0,1),(0,2). Do not arrange four independent fences around the perimeter or leave the center empty. Preserve the contact locations from image1; resolve natural foreground occlusion correctly.
Match reference2 amber wood grain, pointed cut timber tops, beveled support beams, rope knots, warm upper-left lighting and painted cartoon3D quality. All stakes same height and thickness, starter construction, compact readable silhouette.
Ground camera: fixed orthographic projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80). Square ground pad bounds x,y=-2.5..2.5; rear(512,400),right(912,700),front(512,1000),left(112,700). The projected pad MUST remain symmetric4:3 diamond with edge slopes+0.75/-0.75, not flatter 2:1. Vertical timber stakes remain vertical. Middle stake foot is pad CENTER. Each rail arm reaches the appropriate EDGE MIDPOINT of the square, not a diagonal corner, for a seamless connection to adjacent cells. No perspective convergence.
One complete CROSS junction on a thin square packed-earth pad, no thick foundation rim. This pad and central stake define identical geometry for later isolated/end/straight/corner/T variants. Keep full pad and all pointed tops inside square canvas with safe margins, front vertex lowest opaque contact. Keep arms inside this one tile in plan view.
Genuine transparent alpha outside the sprite; remove guide gray backdrop and diagram outlines. No grass, loose rocks, decorations, people, extra structures, UI, text, labels or watermark. Output only this single four-way palisade tile.
```

