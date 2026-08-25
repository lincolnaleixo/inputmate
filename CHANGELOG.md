# Changelog

## [0.2.2](https://github.com/lincolnaleixo/inputmate/compare/v0.2.1...v0.2.2) (2026-08-25)


### Bug Fixes

* **release:** restore explicit asset publication ([38ac4bb](https://github.com/lincolnaleixo/inputmate/commit/38ac4bbc2fdb5aa5a07bd2d1715c5519e7182256))

## [0.2.1](https://github.com/lincolnaleixo/inputmate/compare/v0.2.0...v0.2.1) (2026-08-25)


### Bug Fixes

* **cask:** describe notarized release accurately ([c0da4b9](https://github.com/lincolnaleixo/inputmate/commit/c0da4b9a0d87975e5cc470092875bbf65183fe1d))
* **cask:** preserve distribution requirements ([67ef7aa](https://github.com/lincolnaleixo/inputmate/commit/67ef7aab369d49c30f37a58781992ebae6d6ff1e))
* **release:** let Release Please create tags ([769b437](https://github.com/lincolnaleixo/inputmate/commit/769b437e86e1475e6c9ed12b4d3b8b834a84dc68))
* **release:** sign DMG before notarization ([9f567d4](https://github.com/lincolnaleixo/inputmate/commit/9f567d4dfe7f7ff148949af1e3cca37406618704))
* **security:** harden notarized release pipeline ([d683547](https://github.com/lincolnaleixo/inputmate/commit/d6835471602359182bd086f34edcbe89cc1e788b))

## [0.2.0](https://github.com/matrix-hq/inputmate/compare/v0.1.1...v0.2.0) (2026-08-24)


### Features

* add upstream Homebrew cask ([46f2ffc](https://github.com/matrix-hq/inputmate/commit/46f2ffc356d0c5f1ac66f6e315412c93fb681b90))


### Bug Fixes

* publish signed Sparkle feed for v0.1.1 ([cd27dcc](https://github.com/matrix-hq/inputmate/commit/cd27dcc7adc1a4504adf7d6fe61add863635b82b))
* **release:** bypass keychain for public dependencies ([c006a3b](https://github.com/matrix-hq/inputmate/commit/c006a3b1221a242e4c263b7606c8fee27a15525a))
* **release:** compile designated requirement ([cd8461e](https://github.com/matrix-hq/inputmate/commit/cd8461efa05b45d23a526b2078c4d2c5a66d3fe2))
* **release:** designate bundle signing requirement ([a043c74](https://github.com/matrix-hq/inputmate/commit/a043c74fb0c0a39d63da5a8855cee449aa3c24c8))
* **release:** expose Homebrew on runner PATH ([935166f](https://github.com/matrix-hq/inputmate/commit/935166fb18dc421660b18f2398ad7d196e5789d9))
* **release:** pass literal signing requirement ([74083b6](https://github.com/matrix-hq/inputmate/commit/74083b6b8cca49d1b1e77bf8aad4157a8c0053c0))
* **release:** publish after Release Please ([54aae18](https://github.com/matrix-hq/inputmate/commit/54aae188c05c559974b6c3d72e0980776836606d))
* **release:** verify Sparkle signatures cryptographically ([c9b59fd](https://github.com/matrix-hq/inputmate/commit/c9b59fd8372a1faf693739aeb530cdecfedb2a9b))

## [0.1.1](https://github.com/matrix-hq/inputmate/compare/v0.1.0...v0.1.1) (2026-08-22)

### Bug Fixes

* restore Sparkle update ordering ([ad8a41d](https://github.com/matrix-hq/inputmate/commit/ad8a41d5fa6fc367d021b7bd96ead2bbe4a9c8f6))
* use a monotonic internal bundle version so pre-public installs can detect public releases correctly

## 0.1.0 (2026-08-22)

### Features

* add automatic signed updates and semantic releases ([9af45d2](https://github.com/matrix-hq/inputmate/commit/9af45d2c5fda40eb0fe973e4072fad588e8d96c1))
* publish InputMate source ([52018c9](https://github.com/matrix-hq/inputmate/commit/52018c964669ec14c77be3a1350111b1bcd67444))
