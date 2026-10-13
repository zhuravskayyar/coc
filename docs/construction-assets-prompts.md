# Арт будівельних лісів

Інструмент: вбудований `image_gen.imagegen`, `transparent_background: true`.

Файл: `assets/sprites/buildings/construction_scaffold_v1.png`. Оригінальний прозорий PNG скопійовано в проєкт без зміни альфа-каналу. У Godot увімкнені mipmaps для чистого відображення при віддаленні камери.

## Точний промпт

```text
Use case: stylized-concept
Asset type: transparent isometric construction scaffold sprite for a 2D village building game.
Primary request: a reusable square wooden construction scaffolding ring, open transparent center, surrounding an EMPTY construction footprint. NO building inside.
Style/medium: polished hand-painted cartoon fantasy strategy game sprite; chunky honey-brown timbers, amber highlights, deep warm outlines, rope lashings, a few iron nails, warm daylight from upper left. Match the village art shown in this conversation, with crisp readable forms at small size.
Composition: one isolated object centered on a square 1024x1024 canvas with transparent margins. Camera is orthographic isometric; square ground footprint reads as diamond, horizontal span to vertical ground span ratio 4:3 (edges slope +/-0.75, steeper than classic 2:1 iso). Four sides of wooden scaffolding enclose empty space, four chunky corner uprights, X cross braces, one low plank working platform on each side, short ladder on front right. Scaffolding height is about 35 percent of diamond ground width. It must remain a simple open ring, with a large transparent center to show a building sprite behind it. Rear supports are visibly behind, front supports visibly in front. Ground contact corners form a symmetric 4:3 diamond. NO ground plane or solid floor, no grass tile, no piles in center, no workers, no hammer, no text, no UI, no background, no cast shadow beyond the object. True transparent alpha around and through the ring.
```
