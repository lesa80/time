# Vremya — desktop clock for macOS

[Русский](README.md) · [English](README.en.md)

**Время (Vremya) 2.5.0** is a desktop clock app with an always-on-top mode. It includes 25 themes: four light and dark Minimalism variants and 21 models in the Raketa section. The app displays your Mac's local time, works offline, and remembers your settings.

**[Download Vremya for macOS](https://github.com/lesa80/time/releases/download/v2.5.0/Vremya-2.5.0-macOS-universal.zip)** · [All releases](https://github.com/lesa80/time/releases) · [SHA-256](https://github.com/lesa80/time/releases/download/v2.5.0/SHA256SUMS)

Requires **macOS 13 or later**. One universal archive for Apple Silicon and Intel. The current release is a test build with an ad-hoc signature and no Apple notarization. [Compatibility details](docs/RELEASE_NOTES.md) (in Russian).

| Minimalism | Minimalism 24 | Minimalism — Dark | Minimalism 24 — Dark |
|:---:|:---:|:---:|:---:|
| <img src="assets/minimalism/preview-full.png" width="170" alt="Minimalism: light 12-hour dial with bezel and strap"> | <img src="assets/minimalism-24/preview-full.png" width="170" alt="Minimalism 24: light 24-hour dial with bezel and strap"> | <img src="assets/minimalism-dark/preview-full.png" width="170" alt="Minimalism — Dark: 12-hour dial with bezel and strap"> | <img src="assets/minimalism-24-dark/preview-full.png" width="170" alt="Minimalism 24 — Dark: 24-hour dial with bezel and strap, the default theme"> |

## Features

- Russian, English, German, French, and Spanish interface.
- 12- and 24-hour dials, light and dark designs, and counterclockwise hands on supported models.
- Dial-only mode or a complete watch with bezel and strap.
- Drag to reposition, keep the clock above other windows, or lock its position and let clicks pass through.
- Five sizes: 180, 240, 280, 360, and 466 points.
- Smooth seconds hand with an option to hide it.
- Launch at login.
- Theme, size, position, and display settings saved between launches.
- Help, the watch collection, and project information in the About window.

The default theme is **Minimalism 24 — Dark**. All four Minimalism variants appear in the main theme list. Manufacturer models are under **Theme → Raketa**.

![Raketa collection: 21 models](assets/about/collection.png)

## Installation

1. [Download the ZIP](https://github.com/lesa80/time/releases/download/v2.5.0/Vremya-2.5.0-macOS-universal.zip) and extract it.
2. Move `Время.app` to Applications and open it.
3. Drag the clock to your preferred position. Right-click the clock or its menu bar icon to open settings.

If macOS blocks the test build, allow it to open in System Settings → Privacy & Security.

## Interface language

At launch, the app follows the primary macOS language: Russian, English, German, French, or Spanish. Unsupported languages fall back to English. Regional variants such as Austrian German are supported. Restart the app after changing the language in macOS.

## Controls

| Action | Result |
|---|---|
| Click the clock | Switch between the dial and the full watch with bezel and strap |
| Drag the clock | Move it |
| Left-click the menu bar icon | Toggle always-on-top mode |
| Right-click or Control-click | Open settings |
| Lock position | Let clicks pass through the clock; settings remain accessible from the menu bar |
| Return to screen | Bring the clock back onto the screen and unlock its position |

To launch at login, enable **Launch at login** in the app menu. If macOS requests approval, allow it in System Settings → General → Login Items.

## Build from source

Requires macOS, Command Line Tools for Xcode with Swift 6, Node.js 22+, and npm. Run these commands in the project directory:

```sh
npm ci
npm run build
```

The app and ZIP will be placed in `dist/macos/`. [Developer instructions](CONTRIBUTING.md) (in Russian) · [GitHub Actions](https://github.com/lesa80/time/actions).

## License and credits

The code is licensed under [MIT](LICENSE). The БОЛТ42 (BOLT42) logo and app icon belong to the project author, [@lesa80](https://github.com/lesa80), who retains the rights to them. [License scope](LICENSE_SCOPE.md) · [Third-party notices](THIRD_PARTY_NOTICES.md) (in Russian).

Vremya is an independent, unofficial app and is not affiliated with the Raketa watch manufacturer. [Manufacturer's official website](https://raketa.com/).
