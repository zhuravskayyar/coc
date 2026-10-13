# Будиночки будівельників Lv.1

Інструмент: вбудований imagegen, прозорий фон. PNG скопійовані без редагування пікселів після генерації. Активний спрайт — `assets/sprites/buildings/builder_hut_lv1_grid_v2.png`; v1 збережено як попередній варіант.

Активний PNG: 1254×1254, RGBA; ширина основи за альфа ≥ 0,5 — 1085 px. Усі чотири кути повністю прозорі. Матеріали: помаранчева черепиця, кремова штукатурка, дерев'яні балки, сірий камінь і метал. Над дверима — символ молотка; біля входу — верстак та дошки.

Два однакові екземпляри 2×2 розташовані у стартовій сцені в клітинках (18,14) і (21,14). Використано спільні прив'язку до центру землі, рівномірний масштаб, трав'яну основу та блокування клітинок. У HUD тип `builder_hut` має назву «Будиночок будівельника», доступний у категорії «Інше», підтримує вибір, інформацію й переміщення. Поведінка та юніти будівельників не входять у цю зміну.

Геометричний зразок: `(x,y,z) → (512 + (x−y)×80, 600 + (x+y)×60 − z×80)`, квадратна основа x,y = ±2,5. Краї логічної сітки мають кути ±36,87°. Намальований нижній контур PNG приблизний: +34,214° / −34,221°, симетричний, але не ідентичний сітці в кожному пікселі. Центр землі за спільним алгоритмом — приблизно (638,68; 794,625). Окремих поправок позиції, повороту чи деформації немає.

## Початковий промпт дизайну

```text
Use case: stylized-concept.
Asset type: one production-ready transparent PNG game building sprite for an existing 2D medieval mobile strategy village.
Primary request: ONE small cozy LEVEL 1 BUILDER'S HUT, a compact house-workshop with logical square footprint 2x2 game cells. The village's existing style has creamy plaster, warm honey-amber wood, chunky gray stone, orange terracotta tile roofs, polished hand-painted cartoon 3D shading and dark crisp material contours. This hut must visibly belong to that same family of art.
Subject: a modest squat single-storey cream-plaster cottage with substantial dark honey wood corner beams and a low orange terracotta gabled roof. The front entrance faces screen-right/front, with one sturdy wooden door. Over the door place a compact carved wooden sign with ONE clearly readable steel HAMMER SYMBOL (icon only, no letters). A simple little amber wood carpenter's workbench stands directly beside the doorway under the roof edge, with one mallet, and a small stack of timber planks against the other side. One small warm window on the visible screen-left side. Strong simple silhouette; builder's tools must read at small gameplay size. No luxury masonry, tall tower, church cross, chimney, flags, large canopy, huge clutter, or character.
Materials/textures: rich hand-painted wood grain, small convincing cream plaster variations, thick rounded terracotta tiles with warm orange highlights and deeper reddish joints, a little dark gray forged metal on the hammer and door hinges. Detailed enough to feel finished, but simple chunky construction appropriate to Level 1.
CRITICAL CAMERA AND GROUND: fixed orthographic view above the hut, yaw 45 degrees. Square ground foundation is a symmetric 4:3 diamond, ground axes projected with EXACT slopes +0.75 and -0.75 (angles +/-36.87 degrees). Use the steeper view matching a 96x72 game grid, not a generic flat 2:1 diamond. All parallel architectural edges follow that same camera; screen-vertical wall beams. No perspective convergence. In a conceptual 1024 square canvas the thin foundation's corners are rear (512,270), right (922,577.5), front (512,885), left (102,577.5), total width 820 and ground height 615. Adapt uniformly to final resolution. Rear and front corners share the same x; side corners share the same y.
Foundation: very thin square packed-earth workshop pad with a modest flush gray stone perimeter, entire house and props inside its square plan. Leave the front two straight edges visible for exact alignment in-game. The front pad vertex is the lowest opaque contact; NO protruding stair, thick vertical raised front face, projecting props, irregular grass, outside ground shadow or surrounding terrain. Ground anchor at the center of the ground diamond, not center of image.
Lighting: warm soft upper-left daylight, rich painted highlights, subtle self-shading and contact shading only inside the foundation. Game asset presentation, whole building centered, safe transparent margins.
Output: a SINGLE sprite on a SQUARE canvas, genuine alpha transparency everywhere outside the hut and its foundation. No grass, background scene, people, other buildings, comparison panels, label, text, watermark, UI, reference lines, grid or coordinate markers. Fully painted finished game art, not a wireframe or diagram.
```

## Фінальний промпт

Вхід 1: геометричний зразок `.godot/builder-hut-projection-template.png` — ціль редагування; вхід 2: `builder_hut_lv1_grid_v1.png` — стиль і дизайн.

```text
Use case: sketch-to-render.
Input 1 is the EDIT TARGET: the geometric house blockout. Input 2 is a STYLE AND DESIGN REFERENCE ONLY: a finished builder's hut.
Paint and texture INPUT 1 into a polished hand-painted cartoon 3D medieval builder's hut using input 2's exact materials and details. The CAMERA, GROUND DIAMOND AND ARCHITECTURAL EDGES OF INPUT 1 ARE LOCKED. Do not adopt input 2's shallower camera. Do not redraw input 2 unchanged.
Keep input 1's pad outline rear(512,300),right(912,600),front(512,900),left(112,600). This is a square world-space foundation projected to a symmetric 4:3 diamond with all ground edges slopes EXACTLY +0.75/-0.75, angles +/-36.87 degrees. Front-to-side depth is 300px for 400px horizontal distance. Preserve those exact proportions with uniform scaling. Side corners equal height. All wall and roof ground axes follow this same projection, vertical beams screen-vertical.
Texture the same compact cottage blockout: thick orange terracotta curved tiles, honey-brown chunky carved timber beams, pale cream plaster with slight wear, dark gray forged hinges, sturdy wooden front door. Add the reference's HAMMER ICON carved wooden plaque above the door, warm little left-side window, compact carpenter workbench with one steel mallet next to doorway, and short stack of timber planks at left side. All decorations within the exact guide floor. Maintain reference's lovely painted texture quality, warm upper-left lighting and crisp material contours.
The pad stays a perfectly straight thin flush packed-earth diamond with a small flat gray stone perimeter; no thick raised front face or stairs. Its front corner remains its lowest contact point. Preserve guide's geometry but remove all guide outlines and neutral background.
Single complete finished game sprite, square canvas, safe margins, genuine transparent alpha, no backdrop, no grass, no external shadows, no people, no church cross, no text, no UI, no watermark. Logical building footprint 2x2.
```

