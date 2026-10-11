# Instant Search Filter

TabFlow features a zero-delay fuzzy search filter that lets you jump to any window or application instantly.

---

## Activating Instant Search

While the TabFlow switcher is open on screen:

1. Press <kbd>/</kbd> to activate the search bar.
2. Type any part of the window title, application name, or browser tab name.
3. The switcher filters the grid in real-time, sorting matching windows to the front.
4. Press <kbd>Enter</kbd> or release modifier keys to focus the top matching window.

---

## Search-on-Release Mode

Under **Settings > Appearance > After keys are released**:

- Selecting **Search** automatically places keyboard focus directly into the search input when the shortcut trigger is released, without dismissing the switcher.
- Allows you to summon TabFlow with a quick tap, then type to search without needing to hold down modifier keys.

---

## Fuzzy Matching & Scoring

- Matches acronyms (e.g. `gc` matches `Google Chrome`).
- Tolerates partial substring matches across multi-word titles.
- Prioritizes recent focus order when multiple windows match equally.
