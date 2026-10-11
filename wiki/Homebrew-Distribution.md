# Homebrew Cask Distribution

TabFlow is distributed via the official tap: `mgabs/homebrew-tap`.

---

## Cask Definition

The formula lives at:
`https://github.com/mgabs/homebrew-tap/blob/main/Casks/tab-flow.rb`

```ruby
cask "tab-flow" do
  version "1.2.0"
  sha256 "..."

  url "https://github.com/mgabs/tab-flow/releases/download/v#{version}/TabFlow-#{version}.zip",
      verified: "github.com/mgabs/tab-flow/"
  name "TabFlow"
  desc "Alt-Tab window switcher for macOS"
  homepage "https://tabflow.app/"

  auto_updates true
  depends_on macos: ">= :monterey"

  app "TabFlow.app"

  caveats <<~EOS
    If macOS blocks launch with a malware warning or error -128, run:
      xattr -dr com.apple.quarantine /Applications/TabFlow.app
  EOS
end
```

---

## Automated Updates on Release

When a new version tag is pushed (e.g. `v1.2.0`), the CI release job runs `scripts/update_homebrew_tap.sh`:

1. Downloads the newly built release asset.
2. Computes the SHA256 checksum.
3. Clones or fetches `mgabs/homebrew-tap`.
4. Updates version and hash in `Casks/tab-flow.rb`.
5. Commits and pushes back to `origin/main`.
