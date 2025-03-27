**This project is not accepting PRs.  These instructions are for employees of Defined Networking.**

## Setting up dev environment

Install all of the following things:

- [`xcode`](https://apps.apple.com/us/app/xcode/)
- [`android-studio`](https://developer.android.com/studio)
- [`flutter` 3.29.2](https://docs.flutter.dev/get-started/install)
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

## Formatting

`dart format` can be used to format the code in `lib` and `test`.  We use a line-length of 120 characters.

Use:
```sh
dart format lib/ test/ -l 120
```

In Android Studio, set the line length using Preferences → Editor → Code Style → Dart → Line length, set it to 120.  Enable auto-format with Preferences → Languages & Frameworks → Flutter → Format code on save.

