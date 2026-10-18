# Исходники коллекции Raketa

Добавлены все 20 оставшихся вариантов из [каталога](https://raketa.com/watches), снятого 18 октября 2026 по московскому времени. Вместе с «Авангардом» представлены все 21 модели каталога, в том числе распроданные. Исходные белые «Полярные» сохранены отдельной темой; всего 22.

| Модель | Часов за оборот | Направление всех стрелок | Материалы | Источник |
|---|---:|---|---|---|
| Ракета Су 0331 | 12 | По часовой | [PNG и геометрия](raketa-su/theme.json) | [Референс](https://raketa.com/product/raketa-su) |
| Золотой Ключик 0328 | 12 | По часовой | [PNG и геометрия](zolotoy-klyuchik/theme.json) | [Референс](https://raketa.com/product/zolotoy-klyuchik) |
| Современник 0352 | 12 | По часовой | [PNG и геометрия](sovremennik/theme.json) | [Референс](https://raketa.com/product/sovremennik) |
| Русский код 0302 | 12 | Против часовой | [PNG и геометрия](russkiy-kod-0302/theme.json) | [Референс](https://raketa.com/product/russkiy-kod-0302) |
| Русский код · Меридиан 0344 | 12 | Против часовой | [PNG и геометрия](russkiy-kod-0344/theme.json) | [Референс](https://raketa.com/product/russkiy-kod-0344) |
| BIG ZERO Лебедев 0333 | 12 | По часовой | [PNG и геометрия](raketa-x-lebedev/theme.json) | [Референс](https://raketa.com/product/raketa-x-lebedev) |
| Байконур 0325 | 24 | По часовой | [PNG и геометрия](baykonur-0325/theme.json) | [Референс](https://raketa.com/product/baykonur-0325) |
| BIG ZERO Янковская 0330 | 12 | По часовой | [PNG и геометрия](big-zero-yankovskaya/theme.json) | [Референс](https://raketa.com/product/big-zero-yankovskaya) |
| BIG ZERO Лазурь 0308 | 12 | По часовой | [PNG и геометрия](big-zero-azur-blue/theme.json) | [Референс](https://raketa.com/product/big-zero-azur-blue) |
| Амфибия 0321 | 12 | По часовой | [PNG и геометрия](amfibiya-0321/theme.json) | [Референс](https://raketa.com/product/amfibiya-0321) |
| Коперник 0307 | 12 | По часовой | [PNG и геометрия](kopernik-0293/theme.json) | [Референс](https://raketa.com/product/kopernik-0293) |
| Подводник 0317 | 24 | По часовой | [PNG и геометрия](podvodnik-0317/theme.json) | [Референс](https://raketa.com/product/podvodnik-0317) |
| Полярные 0300 | 24 | По часовой | [PNG и геометрия](polyarnye-0300/theme.json) | [Референс](https://raketa.com/product/polyarnye-0300) |
| Лётчик 0301 | 12 | По часовой | [PNG и геометрия](letchik/theme.json) | [Референс](https://raketa.com/product/letchik) |
| BIG ZERO Синий 0294 | 12 | По часовой | [PNG и геометрия](big-zero-blue/theme.json) | [Референс](https://raketa.com/product/big-zero-blue) |
| BIG ZERO Чёрный 0341 | 12 | По часовой | [PNG и геометрия](big-zero-black-0341/theme.json) | [Референс](https://raketa.com/product/big-zero-black-0341) |
| BIG ZERO 0283 | 12 | По часовой | [PNG и геометрия](big-zero-0283/theme.json) | [Референс](https://raketa.com/product/big-zero-0283) |
| Ракета × Avgvst 0316 · серебро | 12 | По часовой | [PNG и геометрия](raketa-avgvst-0316/theme.json) | [Референс](https://raketa.com/product/raketa-avgvst-0316) |
| Ракета × Avgvst 0315 · золото | 12 | По часовой | [PNG и геометрия](raketa-avgvst/theme.json) | [Референс](https://raketa.com/product/raketa-avgvst) |
| Ракета × Avgvst 0320 · чёрный | 12 | По часовой | [PNG и геометрия](raketa-avgvst-0320/theme.json) | [Референс](https://raketa.com/product/raketa-avgvst-0320) |

## Материалы и воспроизведение

В каждой папке — dial.png (2048×2048), bezel.png (корпус и ремешок), отдельные растровые стрелки, центральный колпачок при наличии, theme.json и registration.json. Прямоугольные Avgvst используют две стрелки; звезда Янковской — секундная стрелка; агатовый диск «Коперника» остаётся неподвижным. Дополнительные компасные/GMT кольца «Байконура» сохраняют положение с фотографии и не являются отдельными регулируемыми механизмами.

Официальные фронтальные PNG 900×1400 и данные моделей сохранены в ../../reference/catalog/. Для «Ракеты Су» исходная витринная картинка показывает комплект: часы выпрямлены и отделены от фона по отдельной официальной фотографии. Это восстановленное изображение, не оригинальный фронтальный PNG производителя.

Закрытые неподвижными стрелками области циферблатов восстановлены встроенным **image_gen**. Генерация применяется только в этих областях с запасом под тени; остальные пиксели, надписи и фактура перенесены с оригинального фото. Тонкие полигональные и кольцевые стрелки отдельно извлечены встроенным image_gen, затем совмещены с измеренными осями. Остальные стрелки вырезаны из растровых исходников масками. Эти маски не рисуют видимое векторное оформление. Чистые мастера находятся в source/.

Полный [набор промптов](generation-prompts.json) содержит тексты всех вызовов встроенного image_gen. Пересборка не обращается к генератору и не требует сети. Физически закрытая печать восстановлена по референсу; исходные фотографии ограничивают реальную детализацию, а 2048×2048 — размер итогового растрового холста.

Сборка: npm run build:artwork; npm run build. Реестр всех вариантов: ../../themes.json. Скрипты: ../../scripts/prepare-catalog.mjs, catalog-layout.mjs, catalog-hand-masters.mjs. Новые модели входят в приложение macOS и браузерное превью.
