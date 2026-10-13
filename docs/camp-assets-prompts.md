# Палатка, табір і вогнище

Інструмент: вбудований imagegen, з увімкненою справжньою прозорістю. Обрані PNG збережені в проєкті без зміни пікселів після генерації; імпорт Godot використовує mipmaps.

| Спрайт | Файл | Логічна площа | Ширина основи у PNG |
| --- | --- | --- | --- |
| Палатка | [war_tent_lv1_grid_v2.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/war_tent_lv1_grid_v2.png) | 3×3 | 1100 px |
| Табір | [unit_camp_lv1_grid_v2.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/unit_camp_lv1_grid_v2.png) | 5×5 | 1100 px |
| Вогнище | [campfire_lv1.png](C:/Users/yarik/Desktop/coc/assets/sprites/buildings/campfire_lv1.png) | Центральна клітинка табору | 820 px |

Експорти: 1254×1254 RGBA. Для всіх застосовується спільний автоматичний ground anchor. Вогнище в локальній клітинці (2,2), масштаб його кам'яного кільця — 0,7 ширини клітинки. Воно входить у зарезервовані 5×5 табору. Навколо залишено прохідне кільце із восьми клітинок та вхід (2,4); центр заблокований для ходьби. Навчання й вигляд юнітів відкладено за уточненням користувача.

Растрові ребра не мають гарантованого збігу в кожному пікселі. За нижнім контуром (альфа від 128) нахили палатки приблизно +36,07° / −35,85°, табору +36,77° / −36,60°; ціль сітки ±36,87°. Позиції площ та вогнища обчислюються точно через спільну сітку, без ручних поправок координат.

## war_tent_grid_v2

```text
Use case: sketch-to-render. Transform THIS exact blockout into a finished cream canvas military tent game sprite. The blockout is the EDIT TARGET and its camera, square-plan geometry and ground diamond boundary are LOCKED. Do not change to the usual shallow generic isometric view. Keep the left and right ground edges at +0.75/-0.75 slopes, symmetric4:3 diamond in this orthographic view. The low wooden square floor retains the exact guide shape, rear(512,300),right(912,600),front(512,900),left(112,600) in a1024 export. The floor front vertex is its lowest contact point. Texture the simple tent volume with ivory canvas folds and stitched seams, thick amber wooden poles with small gray metal caps, tightly wrapped golden ropes, and a tied-open split curtain entrance on the screen-right gabled front. Add a compact rack of3spears and two small wooden crates on the screen-left part of the floor. Pegs and ropes stay inside the floor; entrance is level with the floor, no projecting stair. Leave the floor's straight perimeter visible for exact grounding. No broad surrounding terrain pad; this is only the tent's shallow structural wood floor. Logical building3x3. Match a polished hand-painted medieval mobile strategy-game style: chunky wood, cream cloth, gray stones, warm top-left light and self-shading. Keep all architectural details modest and readable. Output real transparent alpha; remove the gray backdrop and geometric outlines. No grass, terrain, outside ground shadow, characters, extra buildings, text, UI or watermark. Keep safe transparent margins.
```

## unit_camp_grid_v2

```text
Use case: sketch-to-render. Transform THIS exact camp platform blockout into a polished detailed transparent camp sprite. Preserve the exact ground diamond, camera, footprint and entrance gap from the input. The floor is a square in world space viewed orthographically, with symmetric4:3 projected diamond and straight boundary slopes +0.75/-0.75. DO NOT choose a lower camera angle. In the1024 guide the ground corners are rear(512,300),right(912,600),front(512,900),left(112,600), width800 height600. Keep these exact ground contacts. Texture the platform as warm packed sandy earth, and the short rails as chunky amber wood with small square posts and wrapped ropes. Put just a few compact props in the outer one-cell border of this logical5x5 camp: two small crates, short stacked logs, a small spear rack and a few small gray stones by the posts. The center3x3 (central60% of width anddepth) stays empty dirt. All props inside the floor footprint, no large rocks or decorations in the center. Keep the gap in the lower-left rail wide and clear, one fifth of the edge length, for future units. Absolutely no fire, cooking pot, tripod, soldiers, people or centerpiece; the central fire is a separate game sprite. The bottom dirt edge must retain the exact clean straight diamond of the guide; no protruding grass or bevel outside it. Polished hand-painted cartoon3D medieval game-art style, warm top-left lighting, soft self-shadowing, crisp silhouette. Remove the gray backdrop and guide outlines, retain real alpha transparency outside the camp. No extra grass band, terrain pad, outside shadow, labels, coordinates, grid, UI or watermark.
```

## campfire_lv1

```text
Use case: precise-object-edit. Derive ONE SEPARATE CENTRAL CAMPFIRE game sprite from this reference camp's fire style. Output only a compact isolated ring of chunky gray stones with short charred wood logs and warm orange/yellow flames in the middle. Remove the reference's pot, tripod and cooking support; this is an unobstructed simple fire pit that soldiers can run around. No crates, fences, camp floor or any other props. Polished hand-painted cartoon3D game-art finish matching the reference's warm wood and stone shading. Orthographic view above the fire, symmetric horizontal ground axes slope+0.75/-0.75 for a4:3 projected ground diamond. The stone ring fits inside a single square game cell in plan view, centered in the image, with an even projected footprint. For a1024-square composition the occupied ground footprint is approximately512px wide and384px deep, centered at(512,680), front ground contact(512,872). Visible lively flames rise above the logs but do not obscure the stone ring. Clean genuine transparent alpha background with comfortable margins. No soil tile, grass, cast ground shadow, people, smoke cloud, surrounding scene, text, UI, watermark, labels or guide lines. Keep all rocks inside the compact footprint.
```

