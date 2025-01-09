# Mobile Nebula

[Play Store](https://play.google.com/store/apps/details?id=net.defined.mobile_nebula&hl=en_US&gl=US) | [App Store](https://apps.apple.com/us/app/mobile-nebula/id1509587936)

## Setting up dev environment

Install all of the following things:

- [`xcode`](https://apps.apple.com/us/app/xcode/)
- [`android-studio`](https://developer.android.com/studio)
- [`flutter` 3.27.0](https://docs.flutter.dev/get-started/install)
- [`gomobile`](https://pkg.go.dev/golang.org/x/mobile/cmd/gomobile)
- [Flutter Android Studio Extension](https://docs.flutter.dev/get-started/editor?tab=androidstudio)

Ensure your path is set up correctly to execute flutter

Run `flutter doctor` and fix everything it complains before proceeding

*NOTE* on iOS, always open `Runner.xcworkspace` and NOT the `Runner.xccodeproj`

### Before first compile

- Copy `env.sh.example` and set it up for your machine
- Ensure you have run `gomobile init`
- In Android Studio, make sure you have the current ndk installed by going to Tools -> SDK Manager, go to the SDK Tools tab, check the `Show package details` box, expand the NDK section and select `26.1.10909125` version.
- Ensure you have downloaded an ndk via android studio, this is likely not the default one and you need to check the
  `Show package details` box to select the correct version. The correct version comes from the error when you try and compile
- Make sure you have `gem` installed with `sudo gem install`
- If on MacOS arm, `sudo gem install ffi -- --enable-libffi-alloc`

If you are having issues with iOS pods, try blowing it all away! `cd ios && rm -rf Pods/ Podfile.lock && pod install --repo-update`

# Formatting

`dart format` can be used to format the code in `lib` and `test`.  We use a line-length of 120 characters.

Use:
```sh
dart format lib/ test/ -l 120
```

In Android Studio, set the line length using Preferences -> Editor -> Code Style -> Dart -> Line length, set it to 120.  Enable auto-format with Preferences -> Languages & Frameworks -> Flutter -> Format code on save.


# Release

Update `version` in `pubspec.yaml` to reflect this release, then

## Android

`flutter build appbundle`

This will create an android app bundle at `build/app/outputs/bundle/release/`

Upload the android bundle to the google play store https://play.google.com/apps/publish

## iOS

In xcode, Release -> Archive then follow the directions to upload to the app store. If you have issues, https://flutter.dev/docs/deployment/ios#create-a-build-archive