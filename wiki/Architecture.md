# Architecture & Engineering Principles

TabFlow is engineered specifically for ultra-low latency, responsiveness, and minimal battery overhead on macOS.

---

## Core Principles

1. **Pure Swift 5.8 + AppKit**:
   - No SwiftUI or Interface Builder overhead.
   - Hand-crafted AppKit hierarchy with explicit layout constraints.
2. **Main-Thread Latency Critical Path**:
   - Zero synchronous IPC or expensive stalls on the summoning loop.
   - LaunchServices lookups (`NSWorkspace`, `NSRunningApplication`) run off-main where safe.
   - Visible UI elements render first; accounting/state updates follow deferred.
3. **No Polling**:
   - Pure observer architecture using system event taps (`CGEventTap`), Workspace notifications, and Accessibility observers.
4. **Permanent Free Model**:
   - All features (App Icons, Titles, Thumbnails, Auto-Size, Multi-Shortcuts, Instant Search) are 100% unlocked with zero paywalls.
