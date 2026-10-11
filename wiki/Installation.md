# Installation Guide

TabFlow can be installed via Homebrew or downloaded directly from GitHub Releases.

---

## 1. Homebrew (Recommended)

To install TabFlow using Homebrew:

```bash
brew install --cask mgabs/tap/tab-flow
```

Alternatively, tap the repository first:

```bash
brew tap mgabs/tap
brew install --cask tab-flow
```

### Upgrading via Homebrew

```bash
brew upgrade --cask tab-flow
```

---

## 2. Direct Download

1. Download the latest `TabFlow-x.x.x.zip` from [GitHub Releases](https://github.com/mgabs/tab-flow/releases/latest).
2. Extract the `.zip` archive.
3. Move `TabFlow.app` into `/Applications`.
4. If prompted with a quarantine/malware warning on launch, run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/TabFlow.app
   ```
5. Launch `TabFlow.app`.
