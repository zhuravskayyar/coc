> Поточні анімації та нова модель будівельника описані в [unit-motion.md](unit-motion.md). Старі інструкції Blender нижче стосуються попередніх джерел.

# Лучниця: рух і постріл у 2D-поселенні

Гра використовує кадри з 3D-анімації, як обрав користувач. Тренування залишається 125 хліба / 10 секунд; табір, башта, navigation, швидкість переміщення та combat logic збережені.

## Джерело ходьби й бігу

Перевірено animation assets, GLB, Blender actions та імпортовані ресурси проєкту. Наявні Walk/Run були процедурними; їх не використано як основу. Оцінено `Walk_Loop`, `Jog_Fwd_Loop`, `Walk_Formal_Loop` і `Sprint_Loop` з [Universal Animation Library від Quaternius](https://quaternius.itch.io/universal-animation-library). Вибрано природні `Walk_Loop` та `Jog_Fwd_Loop` з безкоштовного Standard-пакета, ліцензія CC0.

Оригінали й ліцензія: `assets/animations/quaternius/`. Перенесення руху на наявний скелет виконує `tools/archer_locomotion.py`: пропорції ніг враховано, опору підошов підігнано до землі, рух руки з луком обмежено. Модель і 65 кісток не замінюються.

Walk — 40 кадрів при 30 FPS, Run — 56 при 60 FPS, Idle — 60 при 30 FPS. Біг має додаткові справжні проміжні пози, щоб при сповільненні playback у бокових напрямках зберегти щонайменше 30 різних поз на секунду. Це in-place анімації: вперед лучницю переміщує наявний controller. Швидкість програвання враховує реальну швидкість юніта, довжину кроку та проєкцію кожного з восьми напрямків. Штатні швидкості ходьби/бігу залишаються 42/130 px/s.

Idle ↔ Walk ↔ Run мають перехід 0,15 с у `scripts/archer_unit.gd`. Walk ↔ Run зберігає фазу кроку. Оскільки поселення працює через Sprite2D, перехід змішує два спрайтові кадри; живий AnimationTree у цій 2D-сцені не використовується. У середині змішування можливий короткий подвійний контур між різними позами. Постріл скасовує це змішування, щоб не розмити момент випуску.

## Модель, зброя й постріл

Вихідні `assets/units/archer/archer_source.glb` та `bow_source.glb` не перезаписуються. З дозволу користувача вихідний Mesh зброї розділено на лук (14990 полігонів) та стрілу (3460); усі 18450 полігонів, вихідні вершини, UV і матеріали збережені.

Робочий файл: `assets/units/archer/archer_animated.blend`; експорт: `archer_animated.glb`. Результат у Godot містить Skeleton3D, AnimationPlayer і BoneAttachment3D для обох рук. Назви кісток Godot: `mixamorig_LeftHand` / `mixamorig_RightHand` (Blender використовує двокрапку).

```text
ArcherRig
├── Archer — вихідний skinned mesh
├── LeftHandAttachment → mixamorig:LeftHand
│   └── BowOffset
│       └── Bow
│           └── BowMuzzle
└── RightHandAttachment → mixamorig:RightHand
    └── ArrowOffset
        └── HeldArrow
            ├── ArrowNock
            └── ArrowTip
```

Лук жорстко слідує за долонею через attachment. `BowOffset` і `ArrowOffset` редагуються в Blender; початкові значення для повторної генерації задані в `tools/animate_archer.py`. Лук не має окремих світових keyframes.

Тятива анімується через `StringDraw`: змінюються тільки вершини вихідної тятиви, кінці залишаються на місці. Середина йде за хвостовиком стріли під час натягу й повертається з коротким коливанням після випуску. Форма плечей лука та геометрія стріли збережені.

`tools/export_archer.py` експортує OBJECT і KEY action slots у режимі ACTIONS та об’єднує їх за назвами NLA-треків. У встановленому Blender 5.2 режим NLA_TRACKS семплював трек тятиви нулями; це перевірено на даних GLB й виправлено. Повторний експорт зі збереженого `.blend` не потребує рендеру й не змінює ключі поз.

Для перегляду 3D-анімацій у Godot використовується саме `archer_animated.glb`. Вбудований автоімпорт `.blend` у цій версії не переносить усі OBJECT/KEY slots і додає до тривалості 1/30 с. `.blend` є редагованим джерелом для Blender та рендеру; видимість стріли при його автоімпорті відновлюється з тих самих метаданих, але цей hook не виправляє стороннє обмеження імпорту тятиви. На кадри 2D-поселення та явний GLB-експорт це не впливає.

Постріл `archer_shoot` / спрайтовий `attack`: 27 кадрів при 30 FPS, тривалість 0,9 с. Підняття 0–5, натяг 5–12, повний натяг 12–14, **випуск на кадрі 15 (0,5 с)**, супровід 15–19, відновлення 19–26. Ліва рука майже пряма, права біля кута рота, правий лікоть відведений назад і не піднятий над кистю. Положення стріли на повному натягу піднято з Z 0,725 до 0,770 м; геометрія губ має Z 0,765–0,767 м. Це відповідає наданому користувачем референсу.

Стріли в руках немає в Idle, Walk, Run та відновленні. Вона видима тільки на кадрах 0–14 пострілу, а лук залишається видимим увесь час. У Blender це керується `hide_render`. GLB переносить стан STEP-треком масштабу 0,0001/1; ненульове значення запобігає помилці Godot при розкладанні трансформів. `tools/import_archer_visibility.gd` перетворює тільки цей трек на дискретний `visible`, повертає HeldArrow масштаб 1 та встановлює початковий стан невидимим. Скрипт призначено для імпорту `.glb` і `.blend`; стріла не стискається на очах. Стріли у вихідному сагайдаку збережені як частина моделі.

`fire_arrow()` використовує існуючу сцену снаряда й викликається один раз. Координати BowMuzzle перенесені з 3D для кожного кадру та напрямку в `clips.attack.muzzle_positions`. Снаряд, його atlas, політ, lifetime, шкода та AI не змінювалися. Запит під час активного пострілу не перериває його й не змінює ціль.

## Колір і перевірка

Блідість лучниці виправлено в її Blender-рендері: `Khronos PBR Neutral`, exposure 0; Key / Fill / Rim — 162 / 58,5 / 99 W. World використовує Background-node з кольором (0,050876; 0,050876; 0,050876) та strength 0,3. Попередня зміна `world.color` не впливала на освітлення, оскільки були ввімкнені nodes. У поселення немає WorldEnvironment чи 3D-сонця: ці кольори запікаються в спрайти. Інші юніти й карта не перефарбовуються.

Вихідна Albedo-текстура підключена до Base Color та використовує sRGB, Normal і Roughness/Metallic — Non-Color, множник кольору білий, Emission Strength 0. Текстури не перефарбовано, PNG не мають додаткової корекції яскравості. Контрольний рендер тієї самої пози з нейтральним освітленням підтвердив пересвіт шкіри від попереднього освітлення; фінальний крупний план не має обрізання RGB-каналів у перевіреній видимій ділянці шкіри.

1464 ігрових кадри у восьми напрямках. Унікальність поз перевіряється під час пакування. Повільний перегляд 0,5× відрендерено з додаткових проміжних положень скелета — 30 FPS без дублювання кадрів.

- `docs/archer-idle-keyposes.jpg`: Idle у восьми напрямках без стріли в руках.
- `docs/archer-arrow-visibility.jpg`: Idle / Walk / Run / full draw / release / recovery з фактичних ігрових кадрів.
- `docs/archer-lighting-comparison.jpg`: та сама поза й камери з попереднім та фінальним світлом.
- `docs/archer-walk-keyposes.jpg`: front / side / gameplay, фази 0%, 12,5%, 25%, 37,5%, 50%, 62,5%, 75%, 87,5%.
- `docs/archer-run-keyposes.jpg`: ті самі ракурси й фази бігу.
- `docs/archer-attack-keyposes.jpg`: ready / aim / draw / full draw / release / follow-through / recovery у двох протилежних напрямках.
- `docs/archer-animations-30fps.mp4`: Walk / Run / Attack спереду, збоку й з gameplay camera, звичайний темп та 0,5×.
- `docs/archer-in-game-30fps.mp4`: фактичне поселення зі штатною камерою, рух через navigation, переходи та два постріли.
- `docs/archer-in-game-detail-30fps.mp4`: збільшений фрагмент того самого запису, без зміни ігрової камери.

Перевірка джерела (`tools/verify_archer_animation.py`) вимірює реальні деформовані підошви, хват, тятива/хвостовик і повний натяг. На опорній фазі Walk дрейф стопи становить приблизно 4–6 мм, Run — до 10 мм; підошви не провалюються під землю в межах допуску 1 мм. Звіт: `.godot/archer_source_verification.json`. Ці виміри доповнюють візуальний перегляд, а не доводять його якість самі по собі.

Godot: 161 перевірка пострілу, 47 перевірок locomotion — без помилок. Джерело Blender: 18 перевірок без помилок. Повторний імпорт GLB і BLEND не має помилок чи попереджень; видимість стріли перевірено в початковому стані, Idle/Walk/Run, за 0,0001 с до випуску, точно на випуску, при відновленні та при переході з натягу в Idle. Мінімальна частота поз при фактичному playback: Walk 32,094 / Run 49,479 FPS; поріг 30 FPS перевірено для обох кліпів у восьми напрямках. Додаткові перевірки пострілу запускають саме імпортований GLB і вимірюють натяг StringDraw на кадрах 12–14 та повернення після snap. Фактичний запис поселення: 390 кадрів / 13 с, по 3,5 с ходьби й бігу, navigation доводить юніта до цілі, обидва постріли випускають по одній стрілі, camera zoom 0,3 не змінюється.

## Відтворення

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --python-exit-code 1 --python tools/animate_archer.py
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --python-exit-code 1 --python tools/render_archer_slow_review.py
C:/Python314/python.exe tools/pack_archer_animations.py
Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --python-exit-code 1 --python tools/verify_archer_animation.py
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/archer_shoot_test.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script tests/archer_locomotion_test.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script tools/archer_game_preview.gd
C:/Python314/python.exe tools/pack_archer_game_preview.py
```

Резервні копії: `.godot/archer_before_locomotion_fix` перед retarget; `.godot/archer_before_arrow_visibility_fix` перед приховуванням стріли, зміною висоти натягу й освітлення.
