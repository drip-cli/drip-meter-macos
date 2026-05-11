# DripMeter branding source assets

Drop your custom logo files here and `Scripts/package_app.sh` picks them up
automatically. Three slots, all optional — anything missing falls back to the
built-in defaults.

## 1. macOS app icon (Finder, Cmd-Tab, About panel)

**File:** `Branding/AppIcon.png`
**Size:** 1024 × 1024 pixels, PNG with transparency
**Notes:** square, no rounded corners — macOS adds the squircle mask itself.

`Scripts/make_icons.sh` runs `sips` over this single source to generate every
size the app bundle needs (16/32/128/256/512 @1x and @2x) and stamps them into
`Sources/DripMeter/Resources/Assets.xcassets/AppIcon.appiconset/`. You only
maintain the 1024 master.

## 2. Menu bar icon (the tiny one in the status bar)

**File:** `Branding/MenuBarIcon.pdf` *(or `.png` 36×36 @2x)*
**Notes:** template image, monochrome, transparent background — macOS tints
it for light/dark mode. If the file is absent, DripMeter draws its built-in
droplet meter instead (the icon that fills proportionally to your % saved).

If you provide a custom menu bar icon, the dynamic % fill goes away — the
icon stays static. Use `Branding/MenuBarIcon.pdf` only if you prefer brand
recognition over the live indicator.

## 3. In-app brand logo (Settings → About header)

**File:** `Branding/BrandingLogo.png` *(or `.pdf`)*
**Size:** ≥ 256 × 256 (rendered at 96 pt in the About pane)
**Notes:** colour preserved, displayed as-is.

## Re-running

After dropping any of these, rebuild:

```bash
./Scripts/package_app.sh
```

The packaging script regenerates icons and code-signs the bundle.
