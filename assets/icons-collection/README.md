# Легендарные модели

Коллекция из 11 вариантов пяти семейств часов. [Submariner: семь конфигураций](SUBMARINER.md). [Проверка приложения](../../docs/LOCAL_TESTING.md), [официальные источники](../../reference/icons/sources.json).

| Тема | Мастер и параметры генерации |
|---|---|
| Rolex Submariner | [PNG](rolex-submariner/source/master.png) · [Промпт](rolex-submariner/source/generation.json) |
| Omega Speedmaster Moonwatch | [PNG](omega-speedmaster/source/master.png) · [Промпт](omega-speedmaster/source/generation.json) |
| Cartier Tank Must | [PNG](cartier-tank/source/master.png) · [Промпт](cartier-tank/source/generation.json) |
| Audemars Piguet Royal Oak | [PNG](ap-royal-oak/source/master.png) · [Промпт](ap-royal-oak/source/generation.json) |
| Casio G-Shock DW-5600 | [PNG](casio-gshock/source/master.png) · [Промпт](casio-gshock/source/generation.json) |

Мастера содержат циферблаты без живых стрелок и экран без цифр. `scripts/prepare-icons-collection.mjs` совмещает растровые слои по `scripts/icon-layout.mjs`, создаёт отдельные PNG стрелок и атласы символов. При сборке изображения не генерируются. Корпус, ремешок и лицо используют единую регистрацию. Дата Royal Oak и поля LCD рисуются при каждом обновлении времени, а не входят в статический кэш.

У Omega часы и минуты имеют общую центральную ось, текущие секунды — отдельную ось слева. Центральная стрелка хронографа и два счётчика управляются в меню Interaction: запуск, пауза, продолжение и сброс. Веб-превью и статические экспорты показывают хронограф в нуле; управление доступно в приложении macOS через Interaction и механические кнопки корпуса. У Tank две стрелки. У Casio стрелок нет; цифровые показания обновляются раз в секунду.

Открытое пространство пряжки и отверстия ремешков имеют альфа-вырезы. Сами ремешки и металл непрозрачные; сглаживание сохраняется по контуру. Источники и графика имеют отдельный статус, описанный в [LICENSE_SCOPE.md](../../LICENSE_SCOPE.md) и [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).
