# Сторонние материалы и зависимости

«Время» — независимый неофициальный проект. Он не связан с часовой мануфактурой «Ракета» и не представляет её. MIT относится к собственному коду проекта; [исключения из лицензии](LICENSE_SCOPE.md) распространяются на графику и референсы.

## Изображения, логотип и сведения о часах

| Материалы | Источник / локальная атрибуция | Статус в этом проекте |
|---|---|---|
| Каталожные фотографии и сведения о моделях | [Каталог Raketa](https://raketa.com/watches), `reference/catalog/index.json`, `reference/catalog/*/product.json` | Сторонние материалы, не MIT |
| Авангард 0292 | [Страница модели](https://raketa.com/product/avangard-0292), `reference/avangard/sources.json` | Сторонние фотографии и производная графика, не MIT |
| Логотип | `assets/icons/logo.svg`, логотип производителя | Исключён из MIT; разрешение на использование/распространение не заявлено |
| Восстановленные циферблаты, стрелки, корпус и ремешок | `assets/avangard/`, `assets/catalog/`; промпты рядом с мастерами | Производные материалы, не включены в лицензию MIT проекта |
| Коллаж коллекции и красный логотип | `assets/about/collection.png`, `assets/icons/RaketaLogo.png` | Наследуют исключения исходных изображений и логотипа |
| Логотип БОЛТ42 и иконка «Время» | Изображения автора проекта, предоставлены 18 октября 2026; `assets/branding/`, `assets/branding/sources.json` | Автор разрешил публикацию в репозитории `time` и приложении с сохранением прав за собой; оригиналы и производные не MIT. [Уведомление](assets/branding/RIGHTS.md) |
| Краткая информация в «О часах» | [Главная страница производителя](https://raketa.com/), `assets/about/sources.json` | Атрибуция источника; не разрешение на графику |

Отсутствие отдельного уведомления рядом с PNG не означает наличие разрешения на его распространение. AI-реставрация и изменение размера не сопровождаются в этом проекте заявлением о прекращении прав на исходные материалы. Наличие ссылок на источник не заменяет проверки прав.

Геометрия вариантов «Минимализма» и значки часов строки меню — оригинальная графика этого проекта по MIT. Встроенный в циферблаты логотип БОЛТ42 взят из предоставленного изображения и исключён из MIT; его контуры сохранены, слоган обрезан, для тёмного фона буквы адаптированы в белый. Общие корпус и ремешок всех вариантов созданы встроенным imagegen по текстовому описанию без входных фотографий и логотипов; это самостоятельный минималистичный концепт. Мастер, полный промпт и координаты совмещения — `assets/minimalism/source/`. При сборке генерация не вызывается. Шрифты Helvetica/Arial используются из системы для растеризации; файлы шрифтов не поставляются.

## Коллекция «Легендарные модели»

В версии 2.9.0 представлены 15 вариантов девяти семейств часов с корпусом и браслетом/ремешком. Исходные фотографии и сведения получены со страниц производителей; растровые основы доработаны для живых стрелок и цифровых полей. Материалы хранятся в `reference/icons/` и `assets/icons-collection/`, промпты — в `source/generation.json` каждой темы. Графика, названия, логотипы и дизайн соответствующих моделей исключены из MIT. Проект не связан с этими производителями.

| Тема | Официальный источник |
|---|---|
| Rolex Submariner / Submariner Date — семь конфигураций | [Каталог Rolex](https://www.rolex.com/watches/submariner/all-models) |
| Omega Speedmaster Moonwatch 310.30.42.50.01.001 | [Omega](https://www.omegawatches.com.hk/en-hk/watch-omega-speedmaster-moonwatch-professional-co-axial-master-chronometer-chronograph-42-mm-31030425001001) |
| Cartier Tank Must WSTA0041 | [Cartier](https://int.cartier.com/de-eu/kollektionen/watches/herrenuhren/tank/tank-must/wsta0041-tank-must-de-cartier.html) |
| Audemars Piguet Royal Oak 15510ST.OO.1320ST.06 | [Audemars Piguet](https://www.audemarspiguet.com/en/watch-collection/royal-oak/15510ST.OO.1320ST.06) |
| Casio G-Shock DW-5600E / DW-5600UE | [Casio](https://www.casio.com/us/watches/gshock/product.DW-5600E-1V/) |

Tank подготовлен по описанию модели без входной фотографии. У Moonwatch малая секундная стрелка на 9 часах показывает текущие секунды; центральная стрелка и счётчики хронографа управляются механическими кнопками корпуса и меню Interaction. Будильник и таймер не реализованы.

## Зависимости сборки

Версии фиксируются в `package-lock.json`. Полные тексты лицензий поставляются с соответствующими npm-пакетами. Эти библиотеки применяются при подготовке PNG и проверках и не включаются как исполняемый код в нативное приложение.

| Пакет | Версия | Лицензия | Исходники |
|---|---|---|---|
| `@resvg/resvg-js` | 2.6.2 | MPL-2.0 | [resvg-js](https://github.com/thx/resvg-js), [MPL-2.0](https://github.com/thx/resvg-js/blob/main/LICENSE) |
| `pngjs` | 7.0.0 | MIT | [pngjs](https://github.com/pngjs/pngjs), [MIT](https://github.com/pngjs/pngjs/blob/main/LICENSE) |

Нативная программа использует системные фреймворки Apple. Шрифты для растровых подписей коллекции берутся из системы при сборке; файлы шрифтов не включаются в репозиторий или приложение.

В CI используются официальные `actions/checkout`, `actions/setup-node` и `actions/upload-artifact`, закреплённые SHA. Их код не включается в приложение и сохраняет собственные условия лицензирования.

Добавлен Hamilton Pulsar P1 (1972). Источники: [Hamilton / Swatch Group](https://www.swatchgroup.com/en/services/archive/2020/hamilton-psr), [American Watch Museum](https://americanwatchmuseum.org/catalog/pulsar-p1-time-computer/). Графика и обозначения этой модели также исключены из MIT.

Темы версии 2.9.0: [Jaeger-LeCoultre Memovox Parking E858, 1958](https://www.jaeger-lecoultre.com/us-en/watches/collectibles/qve85801), [Omega Chronostop 145.009](https://shop.hodinkee.com/products/2578-omega-chronostop-w-paper), [Breitling Navitimer Ref. 806, дизайн 1959 года](https://www.breitling.com/fi-en/watches/navitimer/navitimer-ref-806-1959-re-edition/AB0910371B1X1/). Для Navitimer использовано официальное изображение точного переиздания 1959 Re-Edition; логарифмические шкалы построены заново по [инструкции производителя](https://www.breitling.com/media/document/2/archive-archive-archive-archive-archive-archive-archive-archive-archive-archive-archive-archive-archive-navitimer_slide_rule.pdf). Фотографии, обозначения и дизайн исключены из MIT. Источники и происхождение графики сохранены в `reference/icons/sources.json` и `source/generation.json` соответствующих тем.
