# VPN sizing: upstream Android 17 / LineageOS 24

All references below are vendored at the pinned commit in `reference/manifest.json`.

1. `StatusBarSignalPolicy.currentVpnIconId()` chooses `stat_sys_vpn_ic` for
   validated, non-branded VPNs. iOS exposes VPN visibility, not Android branded /
   validated metadata, so DroidSB uses the ordinary validated icon.
2. `stat_sys_vpn_ic.xml` declares a **17dp × 17dp intrinsic size**, with a
   **24 × 24 viewport**. Its key path occupies x=2..22, y=6.5..18; the empty space
   is intentional and must not be cropped.
3. `StatusBarIconView.updateIconScaleForSystemIcons()` divides the desired system
   icon height by the drawable's intrinsic height. The core dimensions set these
   to **15dp** and **17dp**, respectively. At default font scale the result is
   a 15 × 15dp full viewport, not a 15dp-tall visible key.

Thus, mapping dp to points as elsewhere in this port:

| Build | Full viewport | Visible key height | Visible key width |
| --- | ---: | ---: | ---: |
| 0.1.0 | 12pt | 5.75pt | 10pt |
| 0.1.1 (incorrectly cropped) | cropped to artwork | 12pt | 20.87pt |
| 0.1.2 (Android proportions) | 15pt | **7.1875pt** | **12.5pt** |

The UIImageView now uses the rendered image's height rather than forcing every
icon into a 12pt-tall frame. Wi-Fi/mobile remain at their separate updated 12sp
dimensions. No global icon enlargement or artwork cropping is applied.

This implements the pinned source's defaults, not device/vendor resource overlays
or Android accessibility font scaling. Physical iPhone validation remains needed.
