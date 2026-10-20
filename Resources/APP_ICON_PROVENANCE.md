# AppIcon provenance

## P04 — Android TiebaLite shape with light-blue palette (2026-10-20)

The user explicitly requested the Android TiebaLite icon instead of the three
generated candidates, then requested light blue. This asset is an adaptation of
Android artwork, not original AI-generated artwork and not the official Baidu
Tieba IPA icon.

- Source project: TiebaLite Android contributors,
  <https://github.com/zzc10086/TiebaLite>.
- Read-only reference revision: `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`,
  pinned branch `4.0-dev`.
- Foreground: `app/src/main/res/drawable/ic_launcher_new_foreground.xml`.
  Source SHA-256:
  `a34b05d5389feeee8e33100f5d74d560a78d4498149a2dc984853e10f2ac3cd9`.
- Composition references: `app/src/main/res/mipmap-anydpi-v26/ic_launcher_new.xml`,
  `app/src/main/res/values/colors.xml`, and
  `app/src/main/ic_launcher_new-playstore.png`. `AndroidManifest.xml` names
  `@mipmap/ic_launcher_new` as the default application icon.
- Editable adaptation: `Resources/AppIconSource.svg`. All four foreground paths
  are unchanged. The `18 18 64 64` viewport reproduces the Play Store artwork's
  crop, with a full square background and no baked outer rounded mask.
- Changed colors: background `#9BCBF2`, rear card `#CCE5FA`, white front card,
  and text bars `#87B8E8`. No gradients or shadows are added.
- Rasterization: macOS Quick Look, then lossless opaque RGB PNG conversion:

```bash
qlmanage -t -s 1024 -o Artifacts/VisualReview/P04 Resources/AppIconSource.svg
python3 - <<'PY'
from PIL import Image
image = Image.open("Artifacts/VisualReview/P04/AppIconSource.svg.png")
assert image.size == (1024, 1024)
assert image.getchannel("A").getextrema() == (255, 255)
image.convert("RGB").save(
    "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    optimize=True,
)
PY
```

- Final PNG: 1024×1024, opaque RGB, 10,465 bytes.
- Final SHA-256:
  `634b23299b3b5f0fab1540fcc8fff824eee07afdd97da0d6aa2a7872f94daa0c`.
- Existing universal iOS AppIcon catalog and Xcode-generated device sizes are
  retained. Only the catalog's raster is bundled; the editable SVG is source.
- Attribution/license: Android reference carries GNU GPL version 3 in its
  `LICENSE`; this derivative retains that provenance. Its README also carries
  the non-commercial statement already documented in `THIRD_PARTY_NOTICES.md`.
  Existing rights/distribution limitations remain; this change grants no rights
  to the Tieba name, service or trademarks.

## Superseded asset

The previous navy/teal layered-card asset was generated with OpenAI's built-in
image tool, without an external reference. Its SHA-256 was
`7c7731e2a2367d4b69600b30e13ef40e3a96f89d6dac051c23782f3bec204be4`.
P04's three unused generated candidates remain in ignored review artifacts.
