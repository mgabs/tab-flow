<div align="center">

<a href="https://tabflow.app/"><img src="docs/readme/main.svg" alt="TabFlow — Windows alt-tab on macOS" width="100%"/></a>

<p align="center">
  <strong>TabFlow brings the power and familiarity of Windows alt-tab to macOS.</strong><br/>
  Switch, preview, search, and manage your open windows, tabs, and spaces with blistering speed.
</p>

[![Release](https://img.shields.io/github/v/release/mgabs/tab-flow?color=007AFF&label=Release&logo=apple)](https://github.com/mgabs/tab-flow/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-12.0%2B-blue?logo=apple)](https://github.com/mgabs/tab-flow)
[![Homebrew](https://img.shields.io/badge/homebrew-tabflow-orange?logo=homebrew)](https://github.com/mgabs/homebrew-tap)
[![License](https://img.shields.io/github/license/mgabs/tab-flow?color=green)](LICENSE)

</div>

---

## 🌟 Highlights

- **Window Thumbnails & Live Previews**: See true-to-life thumbnails of all your open windows, including minimized and hidden applications.
- **Native Tab Grouping**: Seamlessly switch between tabs inside Safari, Chrome, Terminal, and other tabbed apps as if they were standalone windows.
- **Instant Search**: Type `/` to immediately filter open windows and applications by title or app name.
- **Multi-Monitor & Spaces Aware**: Filter windows to your current screen, active Space, or show everything across all virtual desktops.
- **Power User Shortcuts**: Close (`W`), minimize (`M`), hide (`H`), quit (`Q`), or fullscreen (`F`) any window directly from the switcher.
- **Refined macOS Design**: Modern aesthetics with Liquid Glass and Frosted Glass materials matching macOS Sequoia and Tahoe.
- **Ultra-Low Overhead**: Written in pure Swift without heavy UI frameworks. Lightning-fast startup, sub-millisecond response, and negligible battery consumption.

---

## 📸 Preview

<div align="center">
  <img src="docs/readme/screenshot-source.webp" alt="TabFlow Switcher Interface" width="900"/>
</div>

---

## 🚀 Installation

### Via Homebrew (Recommended)

Install TabFlow directly using [Homebrew](https://brew.sh/):

```bash
# Tap the repository
brew tap mgabs/tap

# Install the TabFlow cask
brew install --cask tab-flow
```

Or as a single command:

```bash
brew install --cask mgabs/tap/tab-flow
```

To update TabFlow later:

```bash
brew upgrade --cask tab-flow
```

---

### Direct Download

1. Download the latest `TabFlow-x.x.x.zip` from [GitHub Releases](https://github.com/mgabs/tab-flow/releases/latest) or [tabflow.app](https://tabflow.app/).
2. Unzip the archive and move **TabFlow.app** into your `/Applications` folder.
3. If macOS blocks opening the app with a Gatekeeper / malware warning or error -128, remove the quarantine attribute:
   ```bash
   xattr -dr com.apple.quarantine /Applications/TabFlow.app
   ```
4. Launch **TabFlow**.

---

## 🔒 Permissions

TabFlow interacts with macOS window management and requires two permissions:

1. **Accessibility**: Allows TabFlow to detect window focus, switch active windows, and read window titles.
2. **Screen Recording**: Allows macOS to render live window thumbnails inside the switcher. *TabFlow runs entirely locally and never records, stores, or transmits your screen content.*

On first launch, TabFlow will guide you through granting these permissions under **System Settings > Privacy & Security**.

---

## ⌨️ Shortcuts & Controls

| Shortcut / Key | Action |
| :--- | :--- |
| <kbd>⌥ Option</kbd> + <kbd>⇥ Tab</kbd> | Open switcher and cycle forward |
| <kbd>⌥ Option</kbd> + <kbd>⇧ Shift</kbd> + <kbd>⇥ Tab</kbd> | Cycle backward |
| <kbd>→</kbd> / <kbd>←</kbd> / <kbd>↑</kbd> / <kbd>↓</kbd> | Navigate window tiles |
| <kbd>Enter</kbd> / <kbd>Space</kbd> | Focus selected window |
| <kbd>W</kbd> | Close selected window |
| <kbd>M</kbd> | Minimize selected window |
| <kbd>H</kbd> | Hide selected application |
| <kbd>Q</kbd> | Quit selected application |
| <kbd>/</kbd> | Start instant search filter |
| <kbd>Esc</kbd> | Dismiss switcher without switching |

*All shortcuts, modifier keys, appearance styles, and delays are fully customizable in **Preferences**.*

---

## 🛠 Building from Source

TabFlow has zero remote build dependencies — clone and build directly with `xcodebuild`:

```bash
# Clone the repository
git clone https://github.com/mgabs/tab-flow.git
cd tab-flow

# Setup local self-signed certificate (prevents permission prompts during dev)
scripts/codesign/setup_local.sh

# Build Debug app
xcodebuild -project tab-flow-macos.xcodeproj -scheme Debug -configuration Debug -derivedDataPath DerivedData

# Run Unit Tests
./scripts/run_tests.sh
```

---

## 🤝 Project Support

<div align="center">
  <a href="https://jb.gg/OpenSource">
    <img src="docs/readme/sponsor.svg" alt="Sponsored by JetBrains" width="900"/>
  </a>
</div>

---

## 📄 License

This project is open source and distributed under the terms of the GNU General Public License v3.0 or later. See [docs/acknowledgments.md](docs/acknowledgments.md) for third-party acknowledgments.
