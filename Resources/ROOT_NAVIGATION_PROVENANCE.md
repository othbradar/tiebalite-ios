# Root navigation icon provenance

Source repository: zzc10086/TiebaLite, locked UI commit
`c5f1125f42498e49db4e4a9cb66313b8c8a285c7`.

The following generic navigation symbols are derived from `app/src/main/res/drawable/`:

| iOS asset prefix | Android source |
|---|---|
| root-home | ic_animated_rounded_inventory_2.xml |
| root-dynamic | ic_animated_toy_fans.xml |
| root-messages | ic_animated_rounded_notifications.xml |
| root-personal | ic_animated_rounded_person.xml |

Each unselected SVG retains the vector pathData, viewport, and fill rule.
Each `-selected` SVG uses the path animator's valueTo, with no animation.
The dynamic icon's final 180-degree rotation is visually identical by its rotational symmetry.
Only generic monochrome shapes are included, with template rendering and vector preservation.
No app logos, avatars, user data, gradients, or shadows are copied.

These derived resources retain the Android project's GPL-3.0 provenance;
see THIRD_PARTY_NOTICES.md and References/TiebaLite-Android/LICENSE.
Generated deterministically from `git show` without modifying the submodule.
