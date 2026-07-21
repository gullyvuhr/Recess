# Recess Release Asset Manifest: v1.7.0-beta.1

## Status and provenance

This manifest covers the original release assets created in the Recess
repository for the approved `1.7.0-beta.1+2` Beta on July 21, 2026. No
third-party artwork, recording, sample, stock asset, icon library, or external
runtime service is used. No attribution is required for these project-created
assets.

## Visual identity

| Asset | Canonical source and construction | Platform locations | Status |
| --- | --- | --- | --- |
| Recess bell mark | `assets/branding/recess_bell_master.svg`; original cubic path silhouette, rounded rim, and circular clapper in a square `1024` viewBox. Green `#315C4B` on cream `#F7F3E8`. No raster embedding, font, link, gradient, or shadow. | Canonical SVG and `assets/branding/recess_bell_master_1024.png` | **Cleared: original project asset** |
| Android launcher | Generated from the canonical geometry. Legacy and round PNGs use an opaque cream surface. Adaptive foreground is transparent, scaled to 83%, and remains inside the central 264 x 264 px safe region of its 432 px xxxhdpi canvas. Android 13 uses a path-only monochrome mask. | `android/app/src/main/res/mipmap-*`; `mipmap-anydpi-v26`; `mipmap-anydpi-v33`; `drawable/ic_launcher_monochrome.xml` | **Cleared: original project asset** |
| iOS AppIcon | Opaque cream icons generated at every size declared by `Contents.json`, including the 1024 px marketing icon. | `ios/Runner/Assets.xcassets/AppIcon.appiconset` | **Cleared: original project asset** |
| Native splash mark | Same bell geometry, centered over cream. Android uses the path vector before and after Android 12. iOS uses transparent 1x/2x/3x images above the native Recess wordmark. | `drawable/recess_splash_mark.xml`; Android launch XML/styles; `ios/Runner/Assets.xcassets/RecessBell.imageset`; `LaunchScreen.storyboard` | **Cleared: original project asset** |

Generation tool: `tool/generate_brand_assets.py`. It uses deterministic path
sampling and supersampled rasterization through the repository tooling
environment. The app has no new runtime dependency.

Canonical hashes after generation:

- Brand generator: `1DFBC40615776273D5D836F6E3A180F0250978E8B9361782B37F9B200A5959EB`
- Audio generator: `1E528FBB2C329862B494F6CD68F47A360D1E3E2543095A7EA10ACB74A8569C9F`
- SVG: `A799E5151768D396F0308FCB7A00B7FD0673E124B84AB8BEF06C0A6C4FADD9E9`
- 1024 PNG: `05D36BCB5EA1611516888887FD065FF48B25AF2EF5ECC6CB4F24153D2FAFDDBA`

## Original Bell audio

All sounds are deterministic PCM synthesis created for Recess by
`tool/generate_bell_sounds.py`. The generator uses only mathematical waveforms,
seeded noise, envelopes, and normalization. It does not read or transform any
audio input. Outputs are 44.1 kHz, 16-bit, mono PCM WAV files with no clipping
and minimal leading silence.

| Product asset | Original synthesis | Duration / level | SHA-256 | Status |
| --- | --- | --- | --- | --- |
| School Bell | Four inharmonic sinusoidal partials with independent exponential decays, a deterministic short noise transient, fast attack, and one natural tail. | 1.500 s; peak -1.31 dBFS; RMS -19.11 dBFS; 0.00 ms leading silence | `26E9FB58465481272F0422BBFB523EC2BB045D6024EF5C964C8554E0ED818C7F` | **Cleared: original project asset** |
| Coach Whistle | One steady 3150 Hz sports-whistle body, controlled second partial, slight high-rate modulation, deterministic bright noise, and quick attack/release. No two-note contour. | 0.750 s; peak -9.16 dBFS; RMS -15.39 dBFS; 0.68 ms leading silence | `205B6CCAD733D9DB3EBE3F50D4D2F74FF4663E7E836D1A2616C38C0B253F6AFE` | **Cleared: original project asset** |
| Gentle Chime | Four restrained harmonic partials with smooth attack and progressively shorter exponential decays; normalized below the School Bell peak. | 1.800 s; peak -7.30 dBFS; RMS -21.41 dBFS; 1.09 ms leading silence | `E05318BF4638C5379D9D5C3996EDAD6A848AE00D0CD6C2F693784E98FD91F9CD` | **Cleared: original project asset** |

Each canonical file is stored in `assets/sounds/` and copied byte-identically to
`android/app/src/main/res/raw/` and `ios/Runner/Sounds/`. Existing filenames and
`BellSoundDefinition` mappings are preserved. The superseded audio bytes were
overwritten and are no longer active or packaged.

## Reproduction

From the repository root, using the project tooling Python with Pillow:

```powershell
python tool/generate_brand_assets.py
python tool/generate_bell_sounds.py
```

The scripts overwrite only the declared canonical/platform outputs. Re-running
them produces identical SVG, PNG, and WAV content with the same tool version.
Generated assets were not manually retouched after generation.

## Approval summary

- Original bell identity: **cleared for Beta packaging; Android device approved**.
- Android legacy/adaptive/round/monochrome identity: **configured and device approved**.
- iOS complete AppIcon set: **configured; native build validation requires macOS/Xcode**.
- Android/iOS native splash mark: **configured; Android device approved**.
- School Bell, Coach Whistle, Gentle Chime: **original, cleared, and Android
  listening approved**.
- Attribution obligation: **none**.
- Third-party redistribution dependency: **none**.
