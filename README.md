# Mobile Nebula

[Play Store](https://play.google.com/store/apps/details?id=net.defined.mobile_nebula&hl=en_US&gl=US) | [App Store](https://apps.apple.com/us/app/mobile-nebula/id1509587936)

## Setting up dev environment

Install all of the following things:

- [`xcode`](https://apps.apple.com/us/app/xcode/)
- [`android-studio`](https://developer.android.com/studio)
- [`flutter` 3.29.0](https://docs.flutter.dev/get-started/install)
- [`gomobile`](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile)
- [Flutter Android Studio Extension](https://docs.flutter.dev/get-started/editor?tab=androidstudio)

Ensure your path is set up correctly to execute flutter

Run `flutter doctor` and fix everything it complains before proceeding

*NOTE* on iOS, always open `Runner.xcworkspace` and NOT the `Runner.xccodeproj`

### Before first compile

- Copy `env.sh.example` and set it up for your machine
- Ensure you have run `gomobile init`
- In Android Studio, make sure you have the current NDK installed by going to Tools → SDK Manager, go to the SDK Tools tab, check the `Show package details` box, expand the NDK section and select `27.0.12077973` version.
- Ensure you have downloaded an NDK via android studio, this is likely not the default one, and you need to check the
  `Show package details` box to select the correct version. The correct version comes from the error when you try and compile
- Make sure you have `gem` installed with `sudo gem install`
- If on macOS arm64, `sudo gem install ffi -- --enable-libffi-alloc`

If you are having issues with iOS pods, try blowing it all away! `cd ios && rm -rf Pods/ Podfile.lock && pod install --repo-update`

# Formatting

`dart format` can be used to format the code in `lib` and `test`.  We use a line-length of 120 characters.

Use:
```sh
dart format lib/ test/ -l 120
```

In Android Studio, set the line length using Preferences → Editor → Code Style → Dart → Line length, set it to 120.  Enable auto-format with Preferences → Languages & Frameworks → Flutter → Format code on save.

# Prerelease

Push a git tag `v#.#.#-##`, e.g. `v0.5.1-0`, and `.github/release.yml` will build a draft release and publish it to iOS TestFlight and Android internal track.

`./swift-format.sh` can be used to format Swift code in the repo.

Once `swift-format` supports ignoring directories (<https://github.com/swiftlang/swift-format/issues/870>), we can move to a method of running it more like what <https://calebhearth.com/swift-format-github-action> describes.

# Release

1. Manually promote a prerelease build from TestFlight and Android internal track to the corresponding public app stores. 
2. Mark the associated draft release as published, removing the `-##` from it, ending with a release in the format `v#.#.#`, e.g. `v0.5.1`.
3. Remove the old draft releases that will never be published.
4. Add the notable changes to the app to the release summary, e.g.: <https://github.com/DefinedNet/mobile_nebula/releases/tag/v0.5.1>.