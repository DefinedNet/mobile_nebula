# Releasing

## Prerelease

Push a git tag `v#.#.#-##`, e.g. `v0.5.1-0`, and `.github/release.yml` will build a draft release and publish it to iOS TestFlight and Android internal track.

`./swift-format.sh` can be used to format Swift code in the repo.

Once `swift-format` supports ignoring directories (<https://github.com/swiftlang/swift-format/issues/870>), we can move to a method of running it more like what <https://calebhearth.com/swift-format-github-action> describes.

## Release

1. Manually promote a prerelease build from TestFlight and Android internal track to the corresponding public app stores. 
2. Mark the associated draft release as published, removing the `-##` from it, ending with a release in the format `v#.#.#`, e.g. `v0.5.1`.
3. Remove the old draft releases that will never be published.
4. Add the notable changes to the app to the release summary, e.g.: <https://github.com/DefinedNet/mobile_nebula/releases/tag/v0.5.1>.