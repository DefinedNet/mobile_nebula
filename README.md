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



# Android

## Terminology
APK: Android Package
ADB: Android Debug Bridge - A tool for interacting with running emulators
AVD: Android Virtual Device Manager - A tool for launching, configuring and managing emulators

# `ADB` (Android Debug Bridge)
Android Debug Bridge is an executible that can be found under `~/Android/Sdk/platform-tools/adb` for ease of use add `~/Android/Sdk/platform-tools/` to your `$PATH`. `adb` surfaces a few useful commands.

You can sideload a downloaded APK into a running emulator
```
$ adb install ~/Downloads/Ping_v1.7.03_apkpure.com.apk
Performing Streamed Install
Success
```

You can also use shell to access network utilities like ping
```
$ adb shell ping 127.0.0.1
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.206 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.056 ms
...
```

## Release
Update `version` in `pubspec.yaml` to reflect this release, then

`flutter build appbundle --no-shrink`

This will create an android app bundle at `build/app/outputs/bundle/release/`

Upload the android bundle to the google play store https://play.google.com/apps/publish

# iOS

In xcode, Release -> Archive then follow the directions to upload to the app store. If you have issues, https://flutter.dev/docs/deployment/ios#create-a-build-archive

## Release
Update `version` in `pubspec.yaml` to reflect this release, then
