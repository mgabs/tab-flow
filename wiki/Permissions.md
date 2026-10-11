# macOS Permissions Guide

TabFlow interacts with macOS window management, focus manipulation, and screen rendering. To function properly, it requires two system permissions.

---

## 1. Accessibility

- **Why it is needed:**
  Allows TabFlow to observe window lifecycle events, detect active application focus, switch between windows, and read window accessibility titles.
- **How to grant:**
  Go to **System Settings > Privacy & Security > Accessibility** and ensure **TabFlow** is enabled.

---

## 2. Screen Recording

- **Why it is needed:**
  Required by macOS (`CGWindowListCreateImage` and ScreenCaptureKit) to capture and render live window thumbnail previews inside the switcher UI.
- **Privacy Assurance:**
  *TabFlow runs 100% locally on your Mac.* It never records video to disk, stores captured screens, or transmits any screen data over the network.
- **How to grant:**
  Go to **System Settings > Privacy & Security > Screen Recording** and toggle **TabFlow** on.

---

## Resetting Permissions

If permissions become corrupted after updating or re-installing:

```bash
tccutil reset Accessibility com.mgabs.tabflow-macos
```
