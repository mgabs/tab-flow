# Troubleshooting & Gatekeeper Guide

Common issues, macOS security prompts, and how to resolve them.

---

## 1. Error -128 or "App is damaged and can't be opened"

This occurs when downloading TabFlow outside the Mac App Store because macOS applies the `com.apple.quarantine` extended attribute.

### Solution

Run the following command in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/TabFlow.app
```

Then re-launch TabFlow.

---

## 2. Secure Input Warning

When another process enables macOS **Secure Event Input** (such as Bitwarden, 1Password, or a password prompt in Terminal), macOS blocks all background apps from listening to global keystrokes.

- While Secure Input is active, TabFlow cannot intercept your hotkeys.
- TabFlow displays a menubar icon warning indicating Secure Input is engaged and identifying the blocking application.
- Closing or locking the password prompt immediately restores hotkey functionality.

---

## 3. Thumbnails Show Grey / Placeholder Windows

- Ensure **Screen Recording** permission is enabled in **System Settings > Privacy & Security > Screen Recording**.
- If toggling permissions does not take effect, restart TabFlow or reset permissions via:
  ```bash
  tccutil reset ScreenCapture com.mgabs.tabflow-macos
  ```
