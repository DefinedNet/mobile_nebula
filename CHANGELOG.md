# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added an option to wrap logs in the hamburger menu. (#10)

- IPv6 and better roaming support. (#24)

- Certificates can now be replaced. (#33)

### Changed

- Upgraded to Flutter 2. (#26)

- Upgraded core Nebula to 1.4.1. (#41)

### Fixed

- iOS: Reworked vpn process IPC for more reliable communication. (#28)

- Android: Detecting the active vpn site on app boot is now more reliable. (#29)

- Android: Quickly toggling site connection status no longer presents an error. (#16)

- Android: Better vpn shutdown support. (#34)

- Android: System DNS will continue to work when moving between IPv4 only and IPv6 networks. (#40)

## [0.0.38] - 2020-09-25

### Added

- Initial public release.

[0.0.38]: https://github.com/DefinedNet/mobile_nebula/releases/tag/v0.0.38