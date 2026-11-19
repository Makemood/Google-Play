# Золотой Клёв

Портретная рыбалка на **Godot 4.3+** для Google Play. Один заброс: сила, ожидание клёва, подсечка и вываживание рамкой. Монеты, снасти, четыре водоёма, атлас из 16 рыб. Сохранение на устройстве, без сети и аккаунта.

## Как открыть

1. Установи [Godot 4.3](https://godotengine.org/download) или новее.
2. Import → папка этого репозитория → `project.godot`.
3. F5. Мышь и палец — одно и то же. Пробел жмёт главную кнопку.

## Как собрать Android App Bundle

1. Editor → Manage Export Templates → поставь шаблоны той же версии, что редактор.
2. Project → Install Android Build Template.
3. Editor Settings → Export → Android: укажи Android SDK (Android Studio).
4. Project → Export → Add → Android.
5. Package → Unique Name: `com.makemood.goldenbite`
6. Package → Name: `Золотой Клёв`
7. Version code `1`, version name `1.0.0`. Включи только `arm64-v8a`.
8. Включи gradle build и экспорт **AAB**, не APK.
9. Подпиши релиз своим upload-ключом. Пароль и keystore в репозиторий не клади.
10. Файл `.aab` загружается в Play Console → внутреннее тестирование.

Текст карточки магазина: [STORE_LISTING.md](STORE_LISTING.md).

## Управление

- Зажми «Заброс» и отпусти — дальность.
- Когда поплавок глубоко нырнёт, нажми в любом месте.
- На вываживании держи палец: зелёная рамка поднимается. Отпусти — опускается. Держи рыбу внутри рамки.
