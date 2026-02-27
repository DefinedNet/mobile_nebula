#!/bin/sh

set -ex

. ./env.sh

# Generate gomobile nebula bindings
cd nebula

if [ "$1" = "ios" ]; then
  # Build for nebula for iOS
  make MobileNebula.xcframework
  rm -rf ../ios/MobileNebula.xcframework
  cp -r MobileNebula.xcframework ../ios/

elif [ "$1" = "android" ]; then
  # Build nebula for android
  make mobileNebula.aar
  mkdir -p ../android/mobileNebula
  rm -rf ../android/mobileNebula/mobileNebula.aar
  cp mobileNebula.aar ../android/mobileNebula/mobileNebula.aar

elif [ "$1" != "skip" ]; then
  echo "Error: unsupported target os $1"
  exit 1
fi

cd ..

# Generate version info to display in about
{
  # Get the flutter and dart versions
  printf "const flutterVersion = <String, String>"
  flutter --version --machine
  echo ";"

  # Get our current git sha
  git rev-parse --short HEAD | sed -e "s/\(.*\)/const gitSha = '\1';/"

  # Get the git tag version
  # If on an exact tag, gitIsTaggedRelease=true and gitTag is the tag name
  # Otherwise, gitTag is just the closest tag (without commit count/sha suffix)
  if git describe --tags --exact-match HEAD >/dev/null 2>&1; then
    GIT_TAG="$(git describe --tags --exact-match HEAD)"
    echo "const gitIsTaggedRelease = true;"
  else
    GIT_TAG="$(git describe --tags --always 2>/dev/null || echo 'unknown')"
    echo "const gitIsTaggedRelease = false;"
  fi
  echo "const gitTag = '$GIT_TAG';"

  # Get the nebula version
  cd nebula
  NEBULA_VERSION="$(go list -m -f "{{.Replace.Version}}" github.com/slackhq/nebula | cut -c2-)"
  echo "const nebulaVersion = '$NEBULA_VERSION';"
	cd ..

  # Get our golang version
	echo "const goVersion = '$(go version | awk '{print $3}')';"
} > lib/.gen.versions.dart

# Try and avoid issues with building by moving into place after we are complete
#TODO: this might be a parallel build of deps issue in kotlin, might need to solve there
mv lib/.gen.versions.dart lib/gen.versions.dart

# Generate licenses library
dart run dart_pubspec_licenses:generate
