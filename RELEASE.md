# Release

Releasing an update requires that we submit apps to the internal testing tracks for each store first and promote them to production later.

## Pre-release AKA internal testing

**NOTE** Tagging a release from the non `main` branch is fine, as long as that release does not get deployed to production.

1. Select a version and a build number, eg. `v0.6.2-0`. 
    - The version number uses [semver](https://semver.org/). Generally we will just bump the `MINOR` version from the previous release. It is unusual to change the version during multiple pre-release iterations. 
    - The build number is typically a number that starts at 0 for a given version and increments until
      the final release-able build has been created. This number doesn't matter for much but it needs to be unique for each build within a given version.

1. Ideally, if this is expected to be the final build for this version, update the `CHANGELOG.md` to reflect any interesting changes, make sure it is committed. and merged to `main`.

1. Ensure your working directly is at the correct branch and sha for the release. This should almost always be the `main` branch, certainly if the goal is to publish to production.

   ```sh
   git checkout main
   git pull
   ```

1. Tag the release locally, replace `!VERSION` with the version for this release, eg. `0.6.2-0`.

   ```sh
   git tag -a v!VERSION -m "!VERSION Release"
   ```

   The tag has a `v` prepended while the message does not, this is on purpose.

1. Push the tag to Github, again replacing `!VERSION`.

   ```sh
    git push origin v!VERSION
   ```

1. This will eventually lead to a draft release in Github with links to download the apps. It will also submit the app to the app stores internal testing tracks.

1. Test and repeat if further changes are required. Move to [Release](#release-1) when ready.

## Release

**NOTE** Production releases should be tagged from `main`.

If the release was tagged from a branch, get the branch merged to `main` and repeat the [Pre-release](#pre-release-aka-internal-testing) steps from `main`.

1. Follow the steps in [Google](https://play.google.com/console) and [Apple](https://appstoreconnect.apple.com/) stores to submit a new version to production.
   - Apple is the little blue + sign next to the heading `iOS App` while in the app details page.
   - Google is the `Create a new release` button under `Test and release` > `Production` in the app details page.
   - Make sure the version number matches, only the digits are used, eg. `0.6.2`.
   - Copy the interesting bits out of the changelog for this release and paste them into the "What's new in this update" section for each store.

1. Make sure you have actually submitted the draft releases for review, this is typically many button clicks.

1. Wait for both stores to approve the release.

1. Convert the draft release in Github to a published release.
    - Edit the tag to drop the build number, the final tag should be similar to `v0.6.2`
    - Change the release title to be `Release v!VERSION`, eg. `Release v0.6.2`
    - Copy the changelog bits for this release from `CHANGELOG.md` to the release notes. If we didn't
      craft a changelog use the `Generate release notes` as a fallback.
    - Make sure `Set as the latest release` is checked.
    - Publish

1. Publish the release in the app stores

1. Go over to `api` and update the latest version for mobile.