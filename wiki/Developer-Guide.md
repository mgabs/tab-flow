# Developer & Contributor Guide

Everything you need to know about developing, debugging, testing, and contributing to TabFlow.

---

## 🛠 Guides & References

- [[Architecture & Design Principles|Architecture]]: Pure Swift 5.8 + AppKit philosophy, latency budget, and zero-polling architecture.
- [[Building from Source|Building-from-Source]]: Cloning the repo, local self-signed code signing, and using `Makefile` targets.
- [[Testing & CI/CD Pipeline|Testing-and-CI-CD]]: Unit test architecture (1170+ tests) and GitHub Actions automation.
- [[Homebrew Cask Distribution|Homebrew-Distribution]]: How releases are packaged and pushed to `mgabs/homebrew-tap`.

---

## ⚡ Quick Dev Commands

```bash
# Setup local self-signed certificate
scripts/codesign/setup_local.sh

# Build Debug app
make debug

# Run all unit tests
make test

# Launch debug build with live console logging
make run

# Clean build directory
make clean
```
