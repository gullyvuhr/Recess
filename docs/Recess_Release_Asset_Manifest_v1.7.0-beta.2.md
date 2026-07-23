# Recess Release Asset Manifest: v1.7.0-beta.2

## Provenance

All active identity and Bell audio assets are original Recess project assets.
No third-party artwork, recording, sample, stock asset, external runtime
service, or attribution obligation is introduced by this beta.

## Refined identity

The canonical source is `assets/branding/recess_bell_master.svg`. Beta.2
preserves the established green `#315C4B`, cream `#F7F3E8`, and bell metaphor
while refining the geometry with a rounded cap, smoother shoulder and flare,
slimmer rim, and smaller clapper. `tool/generate_brand_assets.py` generates the
canonical PNG plus Android legacy, round, adaptive, monochrome, splash, and
shared iOS icon/launch copies.

- Brand generator SHA-256: `8F87AA84E289308ACD8E1E8B562763F39EAD5C99E70F7F25CE5F1ECCC01DAAF4`
- Canonical SVG SHA-256: `47F109FB6265D2915196C2BC3D8518D8826C058BF66B3881D650404E5D90C3F9`
- Canonical 1024 PNG SHA-256: `9D6E2953985A5BC4FD46318C504E0F0B4D48A03D6E3F175FC9BB3D6C34012794`
- Adaptive xxxhdpi foreground: 432 x 432 px; alpha bounds `(119, 87, 313, 343)`.
- Mask review: circular, rounded-square, squircle, and square passed without
  clipping, crowding, or undersizing.

## Platform locations

- Android launcher/adaptive/round: `android/app/src/main/res/mipmap-*` and
  `mipmap-anydpi-v26` / `mipmap-anydpi-v33`.
- Android monochrome and splash: `drawable/ic_launcher_monochrome.xml` and
  `drawable/recess_splash_mark.xml`.
- iOS AppIcon and splash: `ios/Runner/Assets.xcassets/AppIcon.appiconset` and
  `RecessBell.imageset`.
- Original Bell audio remains byte-identical to the approved beta.1 files in
  `assets/sounds`, Android raw resources, and `ios/Runner/Sounds`.

## Approval

The refined Android launcher identity and common-mask presentation passed local
visual inspection. Physical-device approval remains the release-owner gate for
this new beta.2 icon revision. Audio provenance and device approval carry
forward unchanged from v1.7.0-beta.1.
