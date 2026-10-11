# Building from Source

TabFlow builds directly using Xcode and standard command-line tools without third-party package managers.

---

## Prerequisites

- macOS 12.0 or newer
- Xcode 14+ or Command Line Tools

---

## Build Targets

Using the provided `Makefile`:

```bash
# 1. Setup local self-signed certificate (bypasses repeated permission prompts during development)
scripts/codesign/setup_local.sh

# 2. Build Debug configuration
make debug

# 3. Build & launch Debug app with logging
make run

# 4. Run full unit test suite (1100+ tests)
make test

# 5. Build Release configuration
make release

# 6. Clean build artifacts
make clean
```
