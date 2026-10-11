# Testing & CI/CD Pipeline

Overview of TabFlow's continuous integration, automated tests, and release lifecycle.

---

## 1. Unit Test Suite

TabFlow maintains comprehensive unit tests covering:
- Window order & MRU resolution (`WindowOrderResolverTests`)
- Event tap & keyboard decoding (`KeyboardEventsTests`)
- Space transitions and topology queries (`WindowEventReducerSpaceTests`)
- Window surface inventory & lifecycle (`WindowSurfaceInventoryTests`)
- Preference serialization and migrations (`PreferencesMigrationsTests`)

### Running Tests Locally

```bash
make test
```

Runs all 1170+ tests synchronously with clean output via `xcbeautify`.

---

## 2. GitHub Actions Pipeline

Defined in `.github/workflows/ci_cd.yml`:

- **Lint & Mutation Testing**: Runs code hygiene, Swift formatting checks, and unit tests on macOS runners.
- **Build & Release**:
  - Compiles Release scheme via `make release`.
  - Packages `.zip` and notarizes application with Apple Developer ID.
  - Updates Sparkle `appcast.xml` for auto-updates.
  - Publishes GitHub Release with auto-extracted changelog.
  - Automatically commits updated SHA256 hash to `mgabs/homebrew-tap`.
- **Wiki Synchronization**:
  - `.github/workflows/wiki.yml` automatically propagates documentation changes in `wiki/**` directly to GitHub Wiki.
