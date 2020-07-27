#!/bin/sh

set -e

. env.sh

# Generate gomobile nebula bindings
cd nebula

if [ "$1" = "ios" ]; then
  # Build for nebula for iOS
  make MobileNebula.framework
  rm -rf ../ios/NebulaNetworkExtension/MobileNebula.framework
  cp -r MobileNebula.framework ../ios/NebulaNetworkExtension/

elif [ "$1" = "android" ]; then
  # Build nebula for android
  make mobileNebula.aar
  rm -rf ../android/app/src/main/libs/mobileNebula.aar
  cp mobileNebula.aar ../android/app/src/main/libs/mobileNebula.aar

else
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

  # Get the nebula version
  cd nebula
  NEBULA_VERSION="$(go list -m -f "{{.Version}}" github.com/slackhq/nebula | cut -f1 -d'-' | cut -c2-)"
  echo "const nebulaVersion = '$NEBULA_VERSION';"
	cd ..

  # Get our golang version
	echo "const goVersion = '$(go version | awk '{print $3}')';"
} > lib/.gen.versions.dart

# Try and avoid issues with building by moving into place after we are complete
#TODO: this might be a parallel build of deps issue in kotlin, might need to solve there
mv lib/.gen.versions.dart lib/gen.versions.dart