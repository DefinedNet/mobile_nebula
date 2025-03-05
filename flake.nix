{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      revSuffix = lib.optionalString (self ? shortRev || self ? dirtyShortRev)
        "-${self.shortRev or self.dirtyShortRev}";

      makePackages = (pkgs: devShell:
        let
          makeAndroidSdkArgs = (emulator: {
            # needs to match compileSdkVersion AND targetSdkVersion in android/app/build.gradle
            platformVersions = [ "34" ];
            includeNDK = true;
            # needs to match ndkVersion in android/app/build.gradle
            ndkVersion = "27.0.12077973";
            # needs to match buildToolsVersion in android/app/build.gradle
            # latest https://developer.android.com/tools/releases/build-tools
            buildToolsVersions = [ "35.0.0" ];
            # latest https://developer.android.com/tools/releases/platform-tools
            platformToolsVersion = "35.0.2";
            # latest https://developer.android.com/tools/releases/sdk-tools
            toolsVersion = "26.1.1";
            extraLicenses = [
              "android-googletv-license"
              "android-sdk-arm-dbt-license"
              "android-sdk-license"
              "android-sdk-preview-license"
              "google-gdk-license"
              "intel-android-extra-license"
              "intel-android-sysimage-license"
              "mips-android-sysimage-license"
            ];

            includeEmulator = emulator;
            includeSystemImages = emulator;
            systemImageTypes = lib.lists.optionals emulator
              [ "google_apis" ];
            abiVersions = lib.lists.optionals emulator
              [ "x86_64" "arm64-v8a" ];
          });
          androidSdkArgs = makeAndroidSdkArgs devShell;
          platformVersion = lib.lists.last androidSdkArgs.platformVersions;
          buildToolsVersion = lib.lists.last androidSdkArgs.buildToolsVersions;

          androidComposition = pkgs.androidenv.composeAndroidPackages androidSdkArgs;
          androidStudio = pkgs.android-studio.withSdk androidComposition.androidsdk;
          androidSdk = androidComposition.androidsdk;
          platformTools = androidComposition.platform-tools;

          emulator = (pkgs.androidenv.emulateApp rec {
            name = "emulator";
            sdkExtraArgs = makeAndroidSdkArgs true;
            inherit platformVersion;
            systemImageType = lib.lists.last sdkExtraArgs.systemImageTypes;
            abiVersion = "x86_64";
          }).overrideAttrs (prev: {
            meta = (prev.meta or { }) // {
              mainProgram = "run-test-emulator";
            };
          });

          jdk = lib.trivial.throwIfNot (lib.versions.major pkgs.jdk.version == "21")
            "jdk updated to ${lib.versions.major pkgs.jdk.version}, sync android/app/build.gradle versions"
            pkgs.jdk;

          flutter = pkgs.flutter;

          # fix starting vpn sometimes failing
          # "bulkBarrierPreWrite: unaligned arguments"
          go = pkgs.go.overrideAttrs (old: {
            patches = old.patches ++ [
              (pkgs.fetchpatch2 {
                url = "https://github.com/golang/go/pull/53064.patch";
                hash = "sha256-MB/8sSssGNJALHk7Xp+5IfQdsjqB3gz/Crj+MxbzVz0=";
              })
            ];
          });
          buildGoModule = pkgs.buildGoModule.override {
            inherit go;
          };
          gomobile = (pkgs.gomobile.override {
            androidPkgs = androidComposition;
            inherit buildGoModule;
          }).overrideAttrs (prev: {
            src = (pkgs.applyPatches {
              src = pkgs.fetchFromGitHub {
                owner = "golang";
                repo = "mobile";
                # needs to match golang.org/x/mobile version in nebula/go.mod
                rev = "c31d5b91ecc32c0d598b8fe8457d244ca0b4e815";
                hash = "sha256-SD+/QGJejtqAkAdbd8kg7MON9Yg/0qQEKO8RfxI+1bg=";
              };
              patches = [
                ./gomobile.patch
              ];
            });

            postPatch = (prev.postPatch or "") + ''
              substituteInPlace cmd/gobind/gen.go \
                --replace-fail @out@ $out
              substituteInPlace cmd/gomobile/bind.go \
                --replace-fail @out@ $out
            '';

            vendorHash = "sha256-HXkhKjHpBgRFykIcyAgcTO7o7bQU0ZeNjwAfprSBHcY=";
            proxyVendor = true;
          });

          gradleZip = pkgs.fetchurl {
            url = builtins.readFile (
              pkgs.runCommandLocal "distributionUrl"
                {
                  nativeBuildInputs = with pkgs; [ coreutils ripgrep sd ];
                }
                ''
                  rg -o --replace '$1' 'distributionUrl=(.+)' ${./android/gradle/wrapper/gradle-wrapper.properties} \
                    | sd --fixed-strings '\:' ':' \
                    | tr -d '\n' \
                    > $out
                  cat $out
                ''
            );
            hash = "sha256-KriNbeLCPmra5zY65uKcvdKnCemSkptItlMP0McTO9Y=";
          };

          setup = ''
            export GOCACHE="$TMPDIR/go-cache"
            export GOPATH="$TMPDIR/go"

            # flutter sdk's .gradle/ dir needs to be writable,
            # or else gradle exit 1's silently
            rm -rf "$TMPDIR/flutter-sdk"
            cp -r ${pkgs.flutter.sdk} "$TMPDIR/flutter-sdk"
            chmod -c u+w "$TMPDIR/flutter-sdk/packages/flutter_tools/gradle/.gradle"
            # update FLUTTER_ROOT or else nix store flutter rewrites its own sdk path in local.properties
            export FLUTTER_ROOT="$TMPDIR/flutter-sdk"

            cat <<EOF > android/local.properties
            sdk.dir=$ANDROID_SDK_ROOT
            ndk.dir=$ANDROID_NDK_ROOT
            flutter.sdk=$TMPDIR/flutter-sdk
            EOF
            cat android/local.properties
          '';
        in
        rec {
          inherit self gomobile androidComposition platformTools androidStudio jdk flutter emulator;

          sign = pkgs.writeShellApplication {
            name = "sign";
            runtimeInputs = with pkgs; [ apksigner ];
            text = ''
              apk="$1"
              keystore="$2"

              apksigner \
                sign \
                --ks "$keystore" \
                --ks-pass env:GOOGLE_PLAY_KEYSTORE_PASSWORD \
                --in "$apk" \
                --out app-release.apk
            '';
          };

          nebula-go = buildGoModule {
            pname = "nebula-go";
            version = "0.1.0" + revSuffix;

            src = ./nebula;

            vendorHash = "sha256-x1pK1JGAc2URXVUI2ApuP6KaX0t8qHtpqzaYsCKTDCY=";

            proxyVendor = true;
            overrideModAttrs = (final: prev: {
              postBuild = ''
                go mod tidy -v -x
              '';
            });
          };

          oss_licenses = (pkgs.flutter.buildFlutterApplication {
            pname = "oss_licenses";
            version = "0.1.0" + revSuffix;

            src = ./.;

            autoPubspecLock = ./pubspec.lock;

            buildPhase = ''
              chmod -c u+w .dart_tool/package_config.json
              flutter pub run flutter_oss_licenses:generate.dart --output $out
              cat $out
            '';

            targetFlutterPlatform = "universal";

            dontDartBuild = true;
            dontDartInstall = true;
            dontDartInstallCache = true;

            outputHash = "sha256-B+gLch0yRv1q7eILr8vGBwoTsM2Gqvmlzgb4m6XPSdg=";
            outputHashAlgo = "sha256";
            outputHashMode = "flat";
          }).overrideAttrs (prev: {
            outputs = [ "out" ];
          });

          updateDeps = default.mitmCache.updateScript;

          default = pkgs.flutter.buildFlutterApplication rec {
            pname = "mobile_nebula";
            version = "0.1.0" + revSuffix;

            src = ./.;

            autoPubspecLock = ./pubspec.lock;

            postPatch = ''
              substituteInPlace gen-artifacts.sh \
                --replace-fail \
                  'git rev-parse --short HEAD' \
                  'echo ${self.shortRev or self.dirtyShortRev}' \
                --replace-fail \
                  'flutter pub run flutter_oss_licenses:generate.dart' \
                  'cat ${oss_licenses} > lib/oss_licenses.dart'

              ${lib.getExe pkgs.sd} \
                'version: .+\+(.+)' \
                'version: ${version}+$1' \
                pubspec.yaml
              ${lib.getExe pkgs.ripgrep} \
                'version: ${version}\+.+\d+$' \
                pubspec.yaml \
              || exit 1
            '';

            targetFlutterPlatform = "universal";

            ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
            ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
            ANDROID_NDK_ROOT = "${ANDROID_HOME}/ndk-bundle";
            JAVA_HOME = jdk.home;
            GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_HOME}/build-tools/${buildToolsVersion}/aapt2";
            gradleFlags = [ GRADLE_OPTS ];

            nativeBuildInputs = with pkgs; [
              # add flutter, or else we build with a minimalFlutter, 
              # which doesn't have needed bin/cache/artifacts/engine/android-arm64-release/linux-x64/gen_snapshot
              flutter

              # add gradle for gradleConfigureHook (gradleFlags gradleFlagsArray below),
              # and mitmCache gradleUpdateScript,
              # even though we don't use this version of gradle to build (we use the wrapper)
              gradle

              clang
              dart
              gcc
              go
              gomobile
              jdk
              platformTools
              sdkmanager

              androidSdk
              androidStudio
            ];

            dontDartBuild = true;
            dontDartInstall = true;
            dontUseCmakeConfigure = true;
            dontUseNinjaBuild = true;
            dontUseNinjaCheck = true;
            dontUseNinjaInstall = true;

            preGradleUpdate = "cd android";
            postGradleUpdate = "cd ..";

            gradleUpdateTask = ":app:minifyReleaseWithR8 :app:lintVitalReportRelease";

            mitmCache = pkgs.gradle.fetchDeps {
              # to update, run in non-develop shell:
              # nix build --print-build-logs .#default.mitmCache.updateScript && bash -x ./result
              data = ./deps.json;
              pkg = default;
            };

            GOPROXY = "file://${nebula-go.goModules}/";
            GOSUMDB = "off";

            preBuild = ''
              set -x

              # set dep on ${nebula-go} so that it builds and checks before this

              export HOME=$TMPDIR

              touch env.sh

              patchShebangs gen-artifacts.sh

              ${setup}

              # Substitute the gradle-all zip URL by a local file to prevent downloads from happening while building an Android app
              ${lib.getExe pkgs.sd} 'distributionUrl=.+' 'distributionUrl=file\://${gradleZip}' android/gradle/wrapper/gradle-wrapper.properties
              cat android/gradle/wrapper/gradle-wrapper.properties

              # sets up gradlew wrapper
              flutter build apk -v --config-only

              # add nix flags to gradlew
              local flagsArray=()
              concatTo flagsArray gradleFlags gradleFlagsArray

              local wrapperFlagsArray=()
              for flag in "''${flagsArray[@]}"; do
                wrapperFlagsArray+=("--add-flags" "$flag")
              done

              gradlewPath="$PWD/android/gradlew"
              wrapProgram "$gradlewPath" \
                --run 'set -x' \
                --add-flags '--info' \
                --add-flags '--debug' \
                "''${wrapperFlagsArray[@]}"

              gradle() {
                command "$gradlewPath" "$@"
              }
            '';

            buildPhase = ''
              runHook preBuild

              mkdir -p build/flutter_assets/fonts

              flutter build apk -v --split-debug-info="$debug" $flutterBuildFlags

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              cp -v ./build/app/outputs/flutter-apk/app-release.apk $out

              runHook postInstall
            '';

            shellHook = lib.optionalString devShell ''
              set -ex

              flutter --version

              if ! test -d android; then
                echo "Run this in the root of the project"
                exit 1
              fi

              ${setup}

              rm -vrf .idea
              rm -vf android/.gradle/config.properties
              rm -vf android/gradlew android/gradlew.bat android/gradle/wrapper/gradle-wrapper.jar

              # sets up gradlew wrapper
              flutter build apk -v --config-only
            '';
          };
        }
      );
    in
    builtins.foldl' lib.recursiveUpdate { } (builtins.map
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              android_sdk.accept_license = true;
              allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
                "android-sdk-cmdline-tools"
                "android-sdk-tools"
                "android-studio-stable"
              ];
            };
          };
        in
        {
          devShells.${system} = makePackages pkgs true;
          packages.${system} = makePackages pkgs false;
        })
      lib.systems.flakeExposed);
}
