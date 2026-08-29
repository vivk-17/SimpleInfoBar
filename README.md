# SimpleInfoBar

**Русский** · [English](#english)

Компактная информационная панель для клиента Emberveil (WoW 1.12.1).

Одна строка сверху экрана вместо десятка окошек:

    Зона Степи · Лагерь Тайфуна | Деньги 1g 81s 97c | Сумки 23/60 |
    Сеть 58 fps · 84 ms | Профессии Кожевничество 145/150 | Память 14 MB

## Что показывает

- **Местность** — зона и подзона
- **Деньги** — золото, серебро, медь
- **Сумки** — свободных слотов из общего числа, жёлтым при 8 и меньше, красным при 3 и меньше
- **Сеть** — FPS и задержка, цвет от зелёного к красному
- **Профессии** — основные профессии с рангом, жёлтым при достижении потолка
- **Память** — расход памяти скриптами

Любой блок отключается, порядок блоков настраивается.

## Управление

- **Правая кнопка** по панели — меню со всеми настройками
- **Левая кнопка** — перетаскивание, позиция запоминается
- Команды /sib или /simpleinfobar

| Команда | Действие |
|---|---|
| /sib menu | Открыть меню |
| /sib zone, money, bags, net, prof, mem | Включить или выключить блок |
| /sib labels | Подписи блоков |
| /sib bg | Постоянный фон панели |
| /sib lock, unlock | Закрепить положение |
| /sib lang ru, en, auto | Язык |
| /sib pos X Y | Задать положение числами |
| /sib reset | Вернуть на место по умолчанию |

## Установка

Распакуйте папку SimpleInfoBar в Interface/AddOns/

## Языки

Русский и английский, определяется по языку клиента, переключается вручную.

---

## English

A compact info bar for the Emberveil client (WoW 1.12.1). One line at the top of the screen instead of a dozen little windows:

    Zone Barrens · Camp Taurajo | Money 1g 81s 97c | Bags 23/60 |
    Net 58 fps · 84 ms | Professions Leatherworking 145/150 | Memory 14 MB

### What it shows

- **Zone** — zone and subzone
- **Money** — gold, silver, copper
- **Bags** — free slots out of total, yellow at 8 or fewer, red at 3 or fewer
- **Net** — FPS and latency, coloured from green to red
- **Professions** — primary professions with rank, yellow when capped
- **Memory** — script memory usage

Every block can be switched off and the order of blocks is configurable.

### Usage

- **Right click** the bar for the settings menu
- **Left click** to drag it, the position is remembered
- Slash commands: /sib or /simpleinfobar

| Command | Action |
|---|---|
| /sib menu | Open the menu |
| /sib zone, money, bags, net, prof, mem | Toggle a block |
| /sib labels | Block labels |
| /sib bg | Always show the panel background |
| /sib lock, unlock | Lock the position |
| /sib lang ru, en, auto | Language |
| /sib pos X Y | Set the position numerically |
| /sib reset | Move back to the default spot |

### Installation

Unpack the SimpleInfoBar folder into Interface/AddOns/

### Languages

Russian and English, picked from the client locale, switchable by hand.

---

## Лицензия / License

MIT
