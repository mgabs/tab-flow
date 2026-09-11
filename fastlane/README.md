fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac test

```sh
[bundle exec] fastlane mac test
```

Run the Test scheme (Release configuration, mirrors CI)

### mac build

```sh
[bundle exec] fastlane mac build
```

Build the Release scheme. Pass code_sign_identity:/current_project_version: to override release.xcconfig's real Developer ID and the CI-only VERSION_FILE injection (e.g. for local testing)

### mac notarize_and_package

```sh
[bundle exec] fastlane mac notarize_and_package
```

Notarize+staple the built .app and zip it. Requires a real Developer ID cert plus APPLE_ID/APPLE_PASSWORD/APPLE_TEAM_ID (an app-specific password, not the Apple ID password); Apple will reject a Local Self-Signed build

### mac release

```sh
[bundle exec] fastlane mac release
```

Full production release pipeline, as run by CI on every push to master

### mac local_release

```sh
[bundle exec] fastlane mac local_release
```

Build a Release .app locally for manual testing/distribution, signed with the Local Self-Signed dev cert unless real Apple credentials are set. Notarizes too if APPLE_ID/APPLE_PASSWORD/APPLE_TEAM_ID (a real Developer ID cert) are set

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
