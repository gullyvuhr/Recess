# Recess Release Asset Manifest: v1.0.0-rc.1

## Provenance

All active identity and Bell audio assets are original Recess project assets.
No third-party artwork, recording, sample, stock asset, external runtime
service, or attribution obligation is introduced by this release candidate.

## Identity

The canonical source is `assets/branding/recess_bell_master.svg`, using Recess
green `#315C4B`, cream `#F7F3E8`, and the approved bell geometry.
`tool/generate_brand_assets.py` produces the canonical PNG plus Android legacy,
round, adaptive, monochrome, splash, and shared iOS icon and launch copies.

- Brand generator SHA-256: `8F87AA84E289308ACD8E1E8B562763F39EAD5C99E70F7F25CE5F1ECCC01DAAF4`
- Canonical SVG SHA-256: `47F109FB6265D2915196C2BC3D8518D8826C058BF66B3881D650404E5D90C3F9`
- Canonical 1024 PNG SHA-256: `9D6E2953985A5BC4FD46318C504E0F0B4D48A03D6E3F175FC9BB3D6C34012794`

## Platform locations

- Android launcher, adaptive, and round resources:
  `android/app/src/main/res/mipmap-*`, `mipmap-anydpi-v26`, and
  `mipmap-anydpi-v33`.
- Android monochrome and splash resources:
  `drawable/ic_launcher_monochrome.xml` and
  `drawable/recess_splash_mark.xml`.
- iOS AppIcon and splash resources:
  `ios/Runner/Assets.xcassets/AppIcon.appiconset` and `RecessBell.imageset`.
- Bell audio copies:
  `assets/sounds`, Android raw resources, and `ios/Runner/Sounds`.

## Approval

Identity and audio assets are unchanged from their approved beta versions.
Android launcher presentation, native splash, notification icon, School Bell,
Coach Whistle, and Gentle Chime have passed physical-device validation.

## Release artifacts

- `build/app/outputs/flutter-apk/app-release.apk`
  - SHA-256: `145C53E724B995FA068FE1A2B77C25E426E9F55E860BD358B313D3BFB3A25A06`
- `build/app/outputs/bundle/release/app-release.aab`
  - SHA-256: `4FB49860698BF7BA7094F9770C4401CF7C7718AD138DBD775F529570210D3FC1`

The artifacts contain version name `1.0.0-rc.1` and version code `4`. Release
signing credentials are not stored in the repository or this checkout, so the
generated binaries require signing with the approved external key before
distribution.
