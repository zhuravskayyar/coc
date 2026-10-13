# Шахта й сховище золота Lv.1

Обидва спрайти створені вбудованим imagegen із прозорим фоном. Вихідні зображення скопійовані до проєкту без редагування пікселів; масштаб у грі рівномірний, позиція походить зі спільної сітки.

| Будівля | Файл | PNG | Площа | Ширина основи у PNG |
| --- | --- | --- | --- | --- |
| Шахта Lv.1 | [gold_mine_lv1_grid_v2.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/gold_mine_lv1_grid_v2.png) | 1254×1254, RGBA | 3×3 | 1132 px |
| Сховище золота Lv.1 | [gold_storage_lv1_grid_v1.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/gold_storage_lv1_grid_v1.png) | 1254×1254, RGBA | 3×3 | 1111 px |

Ширину основи виміряно за непрозорим контуром при альфа ≥ 0,5. Спільний алгоритм ground anchor дає центри землі приблизно (624,41; 745,00) для шахти й (629,08; 720,875) для сховища. Кутові пікселі PNG повністю прозорі.

Логічна геометрія сітки точна: ромб 96×72, напрямки країв ±36,87°. Власні намальовані краї PNG приблизні: передні краї шахти +38,22° / −37,57°, сховища +35,82° / −36,03°. Найбільше відхилення від напрямку сітки — близько 1,35°. Прив’язка спільна; окремих поправок координат, поворотів або деформації PNG немає.

Трава додається на карті зовні площі з відступом 0,5 клітинки. Шахта й сховище блокують ходьбу через свої дев’ять клітинок. Вигляд наповненого сховища — поточний статичний спрайт; видобуток, збір золота й місткість ще не реалізовані.

Перший варіант шахти збережено як `gold_mine_lv1_grid_v1.png`; активний — v2. Геометричні допоміжні зразки створено за проєкцією `(x,y,z) → (512 + (x−y)×80, 600 + (x+y)×60 − z×80)`, межі квадратної основи x,y = ±2,5.

## Фінальний промпт шахти

Вхід 1 — перший варіант шахти `assets/sprites/buildings/gold_mine_lv1_grid_v1.png`; вхід 2 — геометричний зразок `.godot/mine-projection-template.png`. Режим редагування, прозорий фон.

```text
Use case: precise-object-edit.
Asset: transparent Level 1 gold mine sprite for a 3x3 square game grid.
Input image 1 is the mine to preserve. Input image 2 is the authoritative camera and ground-plane geometry guide.
Change ONLY the ground-plane projection and the corresponding orthographic camera of the mine so it matches the geometric guide exactly. Keep the recognizable mine design, rocky outcrop, dark entrance, timber reinforcement, lamp, gold-filled ore cart, short rails, pickaxe and barrel, colors, materials and painted cartoon 3D quality unchanged.
The current pad's lower edges are too shallow: about 35 degrees. The correct ground axes have slopes +0.75 and -0.75 (EXACTLY +/-36.87 degrees). The foundation of this mine must be a symmetrical 4:3 ground diamond, not 2:1 and not an irregular quadrilateral. Use the same fixed orthographic view as image 2. Opposing edges are parallel. The camera has no perspective convergence.
Use a SQUARE output canvas. Ground-plane left and right corners are at equal height. The front vertex is directly under the rear vertex, on the ground center's vertical line. The pad's projected total ground height is precisely 0.75 times its projected width. Its forward halves each rise by 0.375 times that width from side corners to front. Preserve these proportions after any uniform resizing.
All mine walls, beams and rails follow the exact same orthographic projection as the pad. Keep props and all opaque contact points inside the square footprint. The bottom front contact belongs to the pad, no floor thickness or shadow should extend below it.
Genuine transparent background, preserve alpha. No new grass, no surrounding environment, no units, no labels, no badge, no watermarks. Avoid cropping. The goal is a camera-aligned sprite, with no manual per-building game offsets or warps needed.
```

## Фінальний промпт сховища

Вхід 1 — геометричний зразок `.godot/gold-storage-projection-template.png`. Режим генерації, прозорий фон.

```text
Use case: stylized-concept.
Asset type: one transparent game building sprite, Level 1 GOLD STORAGE, logical footprint 3x3 square cells.
Primary request: Paint a finished cozy medieval strategy-game gold storage from the supplied orthographic geometric blockout. It is a large sturdy open square wooden storage bin reinforced with chunky corner posts, dark gray iron bands and rivets, filled with a generous visible heap of golden coins and a few small gold bars. The bin is visually substantial but simple Level 1 construction. Do not make a mine, house, castle or tall fantasy vault.
Input image 1 role: authoritative CAMERA AND GROUND GEOMETRY guide. Replace the diagram's plain box walls with rich amber wood planks and thick timber braces, and replace the plain yellow top with an unmistakable pile of round gold coins. Preserve the exact projected square ground plane, parallel sides and orientation. The reference is not a flat illustration style to imitate.
Style: polished hand-painted cartoon 3D medieval game sprite, thick rounded wood, beveled gray iron, crisp dark material outlines, warm upper-left lighting, clear simple silhouette readable at small size. Warm amber wood and brilliant yellow-orange gold, subtle ochre earth. Match a village using creamy tents, timber mining supports and orange tiled roofs.
CRITICAL GROUND PROJECTION: the guide uses the fixed orthographic axes (80,60) and (-80,60). All ground edges must have slopes +0.75 and -0.75, angles exactly +/-36.87 degrees. The square pad's projected width:height is exactly 4:3. Use no perspective convergence and do not substitute a flatter 2:1 isometric camera. Keep vertical posts screen-vertical. In the 1024x1024 guide the ground pad vertices are rear (512,300), right (912,600), front (512,900), left (112,600), ground center (512,600). Uniformly rescale the geometry if necessary without changing these proportions.
Composition: SQUARE output canvas, one whole building, no clipping. Storage bin fills most of its pad. The front pad vertex is directly below the ground center and is the lowest opaque contact. Keep every coin and gold bar inside the bin, no scattered items beyond the footprint. Ground pad is a thin square of packed earth with a modest wooden rim flush to the ground, its front two edges remain clearly visible and straight. No projecting foundations, stairs or outside shadows. Ground anchor is the CENTER OF THE FOOTPRINT, not the image center.
Background: genuine transparent alpha outside the sprite. No grass, no surrounding terrain, no characters, no text, no resource badge, no UI, no labels or watermarks. The game separately adds tall grass in a half-cell margin OUTSIDE the occupied 3x3.
```

