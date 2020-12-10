# Dependencies

- [`flutter`](https://flutter.dev/docs/get-started/install)
- [`gomobile`](https://godoc.org/golang.org/x/mobile/cmd/gomobile)
- [`android-studio`](https://developer.android.com/studio)
- [Enable NDK](https://developer.android.com/studio/projects/install-ndk) Check local.properties for current NDK version

Copy env.sh.example to env.sh and update your PATH variable to expose both flutter and go bin directories

  ```export PATH="$PATH:/path/to/go/bin:/path/to/flutter/bin```


# Formatting

`flutter format` can be used to format the code in `lib` and `test` but it's default is 80 char line limit, it's 2020

Use:
```sh
flutter format lib/ test/ -l 120
```


# Release

Update `version` in `pubspec.yaml` to reflect this release, then

## Android

`flutter build appbundle --no-shrink`

This will create an android app bundle at `build/app/outputs/bundle/release/`

Upload the android bundle to the google play store https://play.google.com/apps/publish

## iOS

In xcode, Release -> Archive then follow the directions to upload to the app store. If you have issues, https://flutter.dev/docs/deployment/ios#create-a-build-archive
