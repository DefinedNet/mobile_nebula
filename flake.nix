{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      revSuffix = lib.optionalString (self ? shortRev || self ? dirtyShortRev)
        "-${self.shortRev or self.dirtyShortRev}";

      makePackages = (pkgs:
        let
          androidComposition = pkgs.androidenv.composeAndroidPackages {
            includeNDK = true;
            # sdk version, from android/app/build.gradle
            platformVersions = [ "33" "34" ];
            platformToolsVersion = "34.0.5";
            # needs to match version in android/app/build.gradle
            buildToolsVersions = [ "34.0.0" ];
            toolsVersion = "26.1.1";
            # needs to match version in android/app/build.gradle
            ndkVersion = "26.1.10909125";
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
          };
          buildToolsVersion = (lib.lists.last androidComposition.build-tools).version;
          androidStudio = pkgs.android-studio.withSdk androidComposition.androidsdk;

          androidSdk = androidComposition.androidsdk;
          platformTools = androidComposition.platform-tools;
          jdk = pkgs.jdk;

          flutter = pkgs.flutter;
          gradle = pkgs.gradle;

          gomobile = (pkgs.gomobile.override {
            androidPkgs = androidComposition;
          }).overrideAttrs (prev: {
            src = (pkgs.applyPatches {
              src = pkgs.fetchFromGitHub {
                owner = "golang";
                repo = "mobile";
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
        in
        rec {
          inherit self gomobile androidComposition platformTools androidStudio jdk gradle flutter;

          sign = pkgs.writeShellApplication {
            name = "sign";
            text = ''
              apk="$1"
              keystore="$2"
              ${lib.getExe pkgs.apksigner} \
                sign \
                --ks "$keystore" \
                --ks-pass stdin \
                --in "$apk" \
                --out app-release.apk
            '';
          };

          nebula-go = pkgs.buildGoModule {
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

          default = pkgs.flutter.buildFlutterApplication rec {
            pname = "mobile_nebula";
            version = "0.1.0" + revSuffix;

            src = ./.;

            postPatch = ''
              substituteInPlace gen-artifacts.sh \
                --replace-fail \
                'git rev-parse --short HEAD' \
                'echo ${self.shortRev or self.dirtyShortRev}'

              ${lib.getExe pkgs.sd} \
                'version: .+\+(.+)' \
                'version: ${version}+$1' \
                pubspec.yaml
              ${lib.getExe pkgs.ripgrep} \
                'version: ${version}\+.+\d+$' \
                pubspec.yaml \
              || exit 1
            '';

            autoPubspecLock = ./pubspec.lock;

            ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
            ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
            ANDROID_NDK_ROOT = "${ANDROID_HOME}/ndk-bundle";
            GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_HOME}/build-tools/${buildToolsVersion}/aapt2";
            JAVA_HOME = jdk.home;

            gradleFlags = [
              "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_HOME}/build-tools/${buildToolsVersion}/aapt2"
            ];

            nativeBuildInputs = with pkgs; [
              # add flutter, or else we build with a minimalFlutter, without bin/cache/artifacts/engine/android-arm64-release/linux-x64/gen_snapshot
              flutter

              clang
              dart
              gcc
              go
              gomobile
              gradle
              jdk
              platformTools
              sdkmanager

              androidSdk
              androidStudio
            ];

            dontUseCmakeConfigure = true;
            dontUseNinjaBuild = true;
            dontUseNinjaInstall = true;
            dontUseNinjaCheck = true;

            preGradleUpdate = "cd android";
            postGradleUpdate = "cd ..";

            gradleUpdateTask = ":app:minifyReleaseWithR8 :app:lintVitalReportRelease";

            mitmCache = gradle.fetchDeps {
              # to update, run in non-develop shell:
              # nix build --print-build-logs .#app.mitmCache.updateScript && ./result
              data = ./deps.json;
              pkg = default;
            };

            GOPROXY = "file://${nebula-go.goModules}/";
            GOSUMDB = "off";

            preBuild =
              let
                gradleAllZip = pkgs.fetchurl {
                  url = "https://services.gradle.org/distributions/gradle-8.7-all.zip";
                  hash = "sha256-GUcXRCV1pvluHBvvosMOmk/JD3Adeu4z64ebeef/BcA=";
                };
              in
              ''
                set -x

                # set dep on ${nebula-go} so that it builds and checks before this

                export HOME=$TMPDIR

                export GOCACHE=$TMPDIR/go-cache
                export GOPATH="$TMPDIR/go"

                touch env.sh

                patchShebangs gen-artifacts.sh

                cat <<EOF > android/local.properties
                sdk.dir=$ANDROID_SDK_ROOT
                ndk.dir=$ANDROID_NDK_ROOT
                flutter.sdk=${pkgs.flutter.sdk}
                EOF

                # Substitute the gradle-all zip URL by a local file to prevent downloads from happening while building an Android app
                sed -i -e "s|distributionUrl=|#distributionUrl=|" android/gradle/wrapper/gradle-wrapper.properties
                cp -v ${gradleAllZip} android/gradle/wrapper/gradle-8.7-all.zip
                echo "distributionUrl=gradle-8.7-all.zip" >> android/gradle/wrapper/gradle-wrapper.properties

                flutter build apk -v --config-only

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

            shellHook = ''
              set -ex

              flutter --version

              if ! test -d android; then
                echo "Run this in the root of the project"
                exit 1
              fi

              export GOCACHE=$TMPDIR/go-cache
              export GOPATH="$TMPDIR/go"

              cat <<EOF > android/local.properties
              sdk.dir=$ANDROID_SDK_ROOT
              ndk.dir=$ANDROID_NDK_ROOT
              flutter.sdk=${pkgs.flutter.sdk}
              EOF
              cat android/local.properties

              rm -rf .idea/libraries

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

          packages = makePackages pkgs;
        in
        {
          devShells.${system} = packages;
          packages.${system} = packages;
        })
      lib.systems.flakeExposed);
}
