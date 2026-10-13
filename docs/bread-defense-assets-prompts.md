# Хліб, оборонна башта й частокіл Lv.1

Усі п’ять фінальних PNG створені вбудованим `imagegen` зі справжнім прозорим фоном і скопійовані до проєкту без редагування пікселів. Це чотири типи об’єктів; частокіл має дві прямі секції для різних осей сітки.

## Файли й розміри

| Спрайт | Файл | Орієнтир площі для арту | PNG | Ширина основи |
| --- | --- | --- | --- | --- |
| Збирач хліба | [bread_collector_lv1_grid_v1.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/bread_collector_lv1_grid_v1.png) | 3×3 | 1254×1254, RGBA | 1081 px |
| Сховище хліба | [bread_storage_lv1_grid_v1.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/bread_storage_lv1_grid_v1.png) | 3×3 | 1254×1254, RGBA | 1136 px |
| Дерев’яна оборонна башта | [defense_tower_lv1_grid_v1.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/defense_tower_lv1_grid_v1.png) | 2×2 | 1254×1254, RGBA | 1018 px |
| Частокіл X | [palisade_lv1_x_grid_v1.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/palisade_lv1_x_grid_v1.png) | 1×1 | 1254×1254, RGBA | 1031 px |
| Частокіл Y | [palisade_lv1_y_grid_v1.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/palisade_lv1_y_grid_v1.png) | 1×1 | 1254×1254, RGBA | 1034 px |

Хлібні будівлі намальовані з орієнтиром на квадратний ресурсний майданчик 3×3. Їхній логічний розмір потрібно узгодити під час підключення до гри: у цьому запиті змінено тільки арт і документацію. Наявні каталог будівель та стартова сцена збережені. Башта 2×2 і секція частоколу 1×1 відповідають наявному плану сітки.

Збирач — невелика пекарня з піччю, колоссям, мішком борошна й видимими буханцями. Сховище — дерев’яний комір із хлібом і полотняним навісом над задньою частиною. Башта — проста дерев’яна платформа з огорожею, підкосами й драбиною; майданчик порожній. Частокіл — п’ять загострених дерев’яних кілків із двома поперечинами та мотузками.

## Прив’язка й перевірка

Камера у промптах відповідає спільній проєкції гри: 96×72, квадратна основа в проєкції — ромб 4:3, напрямки країв ±36,87°. Трава малюється грою окремо; у PNG немає зовнішньої трав’яної рамки.

Ширину основи виміряно за непрозорим контуром при альфа ≥128. Орієнтовні центри землі обчислено тим самим правилом нижньої смуги, яке використовує `VillageBuilding._get_source_ground_anchor`; це результати вимірювання, а не нові індивідуальні зміщення в коді.

| Спрайт | Центр землі в PNG (x; y) | Нижній лівий край | Нижній правий край |
| --- | --- | --- | --- |
| Збирач хліба | (624.258; 822.125) | +36.84° | -36.17° |
| Сховище хліба | (645.716; 786.5) | +37.25° | -36.09° |
| Дерев’яна оборонна башта | (615.625; 836.75) | +37.57° | -35.65° |
| Частокіл X | (627.985; 776.875) | +37.54° | -37.29° |
| Частокіл Y | (631.632; 823.75) | +36.36° | -36.39° |

Растрові краї приблизні: найбільше виміряне відхилення від напрямку сітки — близько 1,22°. Всі PNG мають RGBA, прозорість від 0 до 255; чотири кутові пікселі кожного файлу повністю прозорі. Спрайти оглянуті візуально; контури споруд і кілків не обрізані.

Частокіл X проходить з верхнього лівого до нижнього правого; Y — з верхнього правого до нижнього лівого. Кілки розташовані вздовж середини майданчика. Перевірка точного стику сусідніх секцій і кутів у сцені Godot залишається для етапу підключення: готової системи з’єднань стін у цій зміні немає.

Для частоколу використані окремі геометричні зразки `.godot/palisade-x-projection-template.png` та `.godot/palisade-y-projection-template.png`. Їх створює `.godot/palisade_projection_template.gd`, який успішно виконано через наявний Godot у headless-режимі. Формула зразка: `(x,y,z) → (512 + (x−y)×80, 700 + (x+y)×60 − z×80)`, межі землі x,y = ±2,5. X: y=0, центри кілків x=−2,−1,0,1,2; Y: x=0, центри кілків y=−2,−1,0,1,2. Зразки — допоміжна геометрія, а не ігрові спрайти.

## Фінальні промпти

### Збирач хліба

Входи: 1 — `gold_mine_lv1_grid_v2.png` як стиль; 2 — `.godot/gold-storage-projection-template.png` як геометрія; 3 — `temple_lv1_grid_v2.png` як матеріали даху й стін.

Режим: вбудований imagegen, `transparent_background: true`.

```text
Use case: stylized-concept.
Asset type: ONE finished transparent Level 1 BREAD COLLECTOR building sprite for a medieval mobile strategy village.
Primary request: Create a small rustic medieval BAKERY that clearly produces bread. A chunky timber-framed cream plaster building with a modest orange clay tile gabled roof, a small stone bread oven built into its front-right side with a dark arched opening and warm glow, and a shallow timber counter holding a few clearly visible golden-brown baked loaves. A single tied wheat sheaf and one flour sack tucked beside the wall communicate the resource. Simple starter construction, cohesive building silhouette, no people.
Input image 1 is STYLE AND MATERIAL reference only: existing gold mine. Match its rich amber beveled timber, chunky gray stone, crisp painted cartoon 3D shading and warm upper-left light. Do NOT depict a mine. Input image 2 is authoritative GROUND CAMERA geometry only: preserve its square plan and symmetric diamond projection, not its box subject or diagram colors. Input image 3 is roof and plaster MATERIAL reference only: match the orange roof and cream walls, do NOT include a chapel, bells or cross.
GROUND PROJECTION: fixed orthographic world axes (80,60) and (-80,60); ground lines slopes +0.75 and -0.75, exactly +/-36.87 degrees, symmetric 4:3 ground diamond, no perspective convergence. All architecture follows the same camera; vertical posts stay vertical. In a square 1024 guide, a ground pad with width 800 has corners rear(512,300), right(912,600), front(512,900), left(112,600), center(512,600). Uniform resizing permitted. Retain this ground aspect ratio.
Composition: whole compact bakery on one thin square packed-earth structural pad with a slim timber rim, safe transparent margin. All opaque props and contact points stay inside the pad. Show both front pad edges as straight clean lines. No thick floor extrusion or exterior shadow below the front vertex. Ground anchor is the CENTER of this pad. Resource-building artwork will use a roughly 3x3 footprint; no grid lines.
Style: polished hand-painted cartoon 3D game sprite, rounded chunky forms readable at small in-game size, natural warm ochre earth, amber wood, cream plaster, gray stone, orange tiles and golden bread.
Background: genuine transparent alpha, retain real transparency outside the isolated sprite. No grass, trees, surrounding terrain, smoke cloud, characters, signs, words, icons, UI, labels or watermark. Game supplies grass separately. Do not crop the roof or foundation.
```

### Сховище хліба

Входи: 1 — `gold_storage_lv1_grid_v1.png` як конструкція й матеріали; 2 — `.godot/gold-storage-projection-template.png` як геометрія; 3 — `bread_collector_lv1_grid_v1.png` як стиль і вигляд хліба.

Режим: вбудований imagegen, `transparent_background: true`.

```text
Use case: stylized-concept.
Asset type: ONE transparent game building sprite, Level 1 BREAD STORAGE for a medieval mobile strategy village.
Primary request: Create a sturdy LOW wooden bread storehouse, clearly different from a bakery. A large square timber storage bin with four chunky corner posts, gray iron bands and rivets, filled with visible golden-brown baked bread: large round scored loaves and a few oval loaves. A small cream canvas lean-to canopy protects the REAR HALF of the bin, supported by its rear posts; the FRONT HALF stays open so abundant BREAD is unmistakable. Simple starter construction. No oven, chimney or processing equipment. Bread, not grain or coins, is the dominant visible resource.
Input image 1 is DESIGN AND MATERIAL reference: the existing gold storage bin. Keep its broad square proportions, warm amber chunky wood and gray metal; reinterpret it as bread storage with a modest rear canopy. Do not copy gold coins. Input image 2 is authoritative GROUND CAMERA geometry only, not an illustration style. Input image 3 is BREAD AND STYLE reference: the new bakery. Match its toasted golden-brown scored bread, cream cloth/plaster color family and polished painted 3D finish.
GROUND PROJECTION: fixed orthographic ground axes (80,60) and (-80,60), parallel edges with slopes +0.75/-0.75, exactly +/-36.87 degrees. Structural pad is a symmetric 4:3 diamond in projection, NOT a flatter 2:1 diamond. In a square 1024 guide, pad corners are rear(512,300), right(912,600), front(512,900), left(112,600), center(512,600). Uniform rescaling permitted. Vertical posts remain screen-vertical; all structures share this camera with no perspective convergence.
Composition: square canvas, one whole compact LOW storehouse on a thin square packed-earth pad with a slim timber rim, safe transparent margins. Bin fills most of pad, every loaf and post stays inside it. Front ground vertex is the lowest opaque contact, ground anchor at the pad CENTER. Show two straight clean front pad edges. No projecting stairs, spilled loaves, thick foundations or external shadows. Artwork roughly 3x3 resource-building footprint, no grid drawn.
Style: polished hand-painted cartoon 3D medieval strategy sprite, chunky rounded timber, beveled iron, crisp dark material contours, warm upper-left lighting, soft self-shading. Clear silhouette and large readable loaves at small scale, avoid tiny clutter.
Background: genuine transparent alpha outside the sprite, not a drawn checkerboard. No grass, vegetation, surrounding terrain, people, units, signs, text, resource badge, UI, labels or watermark. Game supplies grass separately. Whole canopy and foundation visible, no cropping.
```

### Дерев’яна оборонна башта

Входи: 1 — `gold_mine_lv1_grid_v2.png` як стиль; 2 — `.godot/gold-storage-projection-template.png` як геометрія; 3 — `bread_collector_lv1_grid_v1.png` як стиль.

Режим: вбудований imagegen, `transparent_background: true`.

```text
Use case: stylized-concept.
Asset type: ONE transparent Level 1 DEFENSE TOWER building sprite for a medieval strategy village; logical square footprint 2x2 cells.
Primary request: a simple starter WOODEN ARCHER WATCHTOWER. Four chunky amber timber legs on small gray stone footings support a raised SQUARE wooden fighting platform. Short sturdy timber parapets with readable square gaps surround the platform; platform interior is empty and clearly visible from above. Heavy X braces strengthen the legs. A short compact ladder on the front-right face stays fully inside the foundation. Simple Level 1 rustic construction, taller than its width but not an enormous castle tower. No roof, no flag, no resident character, no mounted weapon.
Input image 1 is STYLE AND MATERIAL reference only: existing gold mine, match rich amber timber and chunky gray stone, beveled dark iron joints, painted cartoon 3D quality. Input image 2 is authoritative GROUND CAMERA GEOMETRY reference only: preserve symmetric square-plan diamond, not its box design. Input image 3 is STYLE consistency only: bakery from the same village, no bakery parts.
GROUND PROJECTION: orthographic axes (80,60) and (-80,60), ground line slopes +0.75/-0.75, angles +/-36.87 degrees; square ground pad is exactly a 4:3 diamond in projection, with parallel opposing sides and no perspective convergence. Every square platform, brace placement and timber structure shares this camera. Vertical posts screen-vertical. Reference pad corners rear(512,300), right(912,600), front(512,900), left(112,600), center(512,600); uniform rescaling or translation within the square canvas permitted to fit tower height, never flatten the ground diamond.
Composition: whole tower and ground pad visible, generous transparent top margin, no clipped parapets. One compact thin packed-earth square structural pad with slim timber rim. All stone feet, legs, ladder and platform projection within footprint. Front pad vertex is lowest opaque contact; no thick floor extrusion, exterior ground shadow or projecting stair. Ground anchor at CENTER of pad. Keep two clean straight front foundation edges.
Style: polished hand-painted cartoon 3D medieval mobile-game sprite, chunky simple shapes, warm upper-left light, crisp dark material contours, warm wood, gray stone and iron, muted ochre dirt. Readable silhouette at small scale. Defense building must look modest and match the existing village.
Genuine transparent alpha background; no grass, surrounding terrain, plants, units, characters, text, UI, badges, watermarks or diagram lines. Game adds its own exterior grass. Output only this single tower.
```

### Частокіл X

Входи: 1 — `.godot/palisade-x-projection-template.png` як ціль геометрії; 2 — `defense_tower_lv1_grid_v1.png` як матеріали й стиль.

Режим: вбудований imagegen, `transparent_background: true`.

```text
Use case: sketch-to-render.
Asset type: ONE transparent modular Lv1 wooden palisade wall sprite, X direction, 1x1 square game cell.
Input image1 is the EDIT TARGET: an exact geometry blockout. Convert THIS blockout to a finished painted game sprite. The camera, ground diamond, positions of every stake's foot, heights and outlines of the stakes, row length and cross-rail endpoints are LOCKED to image1. Do not change the composition or replace this blockout with a different generic palisade layout.
Input image2 is ONLY an amber WOOD MATERIAL AND PAINTED SHADING reference, taken from the same game's wooden watchtower. Do not add any tower parts. Match its chunky golden-brown timber, small dark material contours, warm upper-left highlights and polished hand-painted cartoon3D style.
Texture the five tightly adjacent pointed TIMBER STAKES in image1 with warm carved wood grain. Preserve their blocky squared cross-sections and pointed cut tops from the target; do not use wider round cylinders. The two existing cross rails become warm brown wooden support beams with compact rope ties around each stake. Keep rope within the silhouette. Preserve the target's thin square packed-earth pad; texture it subtly as sandy ochre earth.
Ground geometry must stay EXACTLY the guide's symmetric4:3 diamond, axes slope+0.75/-0.75, +/-36.87 degrees, no perspective convergence. Rear pad(512,400),right(912,700),front(512,1000),left(112,700) in1024 guide. Project(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80). Row centered along y=0, five stake centers x=-2,-1,0,1,2. The middle stake foot is at the CENTER of the ground pad. Do not shift the whole wall toward the foreground or the right. Pad remains square in world plan, NOT an elongated rectangle. Opposite row ends reach opposite edge midpoints for joining adjacent wall tiles.
Remove all black diagram edges and gray canvas background; retain real transparent alpha outside the sprite. Keep full ground pad visible with front vertex lowest opaque contact. Square output with safe margins. No thick pad extrusion, rim, grass, rocks, clutter, people, text, UI, scene or watermark. Output one section, upper-left to lower-right orientation, exactly as the blockout.
```

### Частокіл Y

Входи: 1 — `.godot/palisade-y-projection-template.png` як ціль геометрії; 2 — `palisade_lv1_x_grid_v1.png` як матеріали й стиль.

Режим: вбудований imagegen, `transparent_background: true`.

```text
Use case: sketch-to-render.
Asset type: ONE transparent modular Lv1 wooden palisade wall sprite, Y direction, 1x1 square game cell.
Input image1 is the EDIT TARGET: an exact geometry blockout for the Y direction. Convert THIS blockout to a finished painted game sprite. Its camera, ground diamond, every stake's foot position, heights and outlines, row length and cross-rail endpoints are LOCKED to image1. Preserve its UPPER-RIGHT to LOWER-LEFT orientation, do not replace it with the X-direction orientation.
Input image2 is ONLY a STYLE AND MATERIAL consistency reference: the final X-direction palisade sprite from the same game. Match its five pointed squared amber timber stakes, two wooden support rails, rope lashings, sandy dirt material, polished hand-painted cartoon3D finish and warm UPPER-LEFT lighting. Do not copy image2's row direction. This is a second matching modular section turned 90 degrees in WORLD PLAN, with lighting remaining upper-left, not an image mirrored with reversed lighting.
Texture the five tightly adjacent pointed TIMBER STAKES in image1 with warm carved wood grain. Preserve their squared cross-sections and pointed cut tops; do not use wider round cylinders. Add compact rope ties around each stake connecting the two existing cross rails, and keep the ropes within the silhouette. Match the thickness, heights and warm amber colors of image2 while following image1's locked geometry.
GROUND GEOMETRY: exact symmetric4:3 diamond, ground axes slope+0.75/-0.75, +/-36.87degrees, parallel edges with no perspective convergence. Rear pad(512,400),right(912,700),front(512,1000),left(112,700) in1024 guide. Projection(x,y,z)=(512+(x-y)*80,700+(x+y)*60-z*80). Row centered along x=0, five stake centers y=-2,-1,0,1,2. The middle stake foot is at the CENTER of the ground pad. This row's screen slope is -0.75. Do not move row toward the front or left corner. Row goes between opposite edge MIDPOINTS, not diagonal corners. Pad remains square in world plan, NOT elongated. Uniform resizing of the entire guide permitted, no individual geometry changes.
Preserve thin ochre packed-earth pad, no thick foundation or rim. Front pad vertex is the lowest opaque contact. Remove diagram outlines and gray canvas backdrop, output genuine transparent alpha outside the full sprite. Square output with safe margins, no crop. No grass, plants, rocks, clutter, people, text, UI, scene or watermark. Output one section in Y orientation exactly as image1.
```
