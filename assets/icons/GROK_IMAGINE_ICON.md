# Grok Imagine: lumenEh application icon

Generate a single application icon for **lumenEh**, a lightweight native GTK markdown viewer.

## Save path (required)

Save the finished image **exactly** here in the repository tree:

```
assets/icons/lumeneh.png
```

Absolute path when the repo root is known:

```
<repo-root>/assets/icons/lumeneh.png
```

`make install` copies this file to the FreeDesktop hicolor theme as:

```
$(datadir)/icons/hicolor/256x256/apps/lumeneh.png
```

The desktop entry uses `Icon=lumeneh`, so the basename without extension must remain `lumeneh`.

## Image requirements

| Property | Value |
|----------|--------|
| Format | PNG (RGBA preferred) |
| Size | **256×256** pixels (square) |
| Filename | `lumeneh.png` |
| Background | Transparent or solid that reads well on light and dark panels |
| Style | Flat or soft-material app icon; readable at 32×32 and 48×48 |

## Subject / composition

- One clear symbol for a **markdown document viewer** (not a full-screen screenshot of the app).
- Suggest: an open document or page with subtle markdown cues (e.g. `#` heading mark, soft glow / “lumen” light), compact and centered.
- Prefer a dark navy / teal palette that feels calm and technical; avoid noisy gradients, photoreal clutter, or tiny unreadable text.
- No OS chrome, window borders, or multi-icon sheets — one centered glyph for a launcher icon.
- Do not include the words “lumenEh” as large body text unless it remains legible when the icon is scaled down to 32px.

## Prompt starter (paste into Grok Imagine)

```
App icon, 256x256 PNG, transparent background, flat soft-material style.
Centered symbol: a simple open markdown document page with a subtle glowing
hash "#" mark and a soft lumen light ray. Dark navy and teal palette.
Clean, minimal, readable at small sizes, no text labels, no window chrome,
no photorealism, single square application icon.
```

## After generating

1. Export or save as PNG, 256×256.
2. Overwrite `assets/icons/lumeneh.png` (replace the placeholder).
3. Confirm install still finds it:

   ```bash
   make install DESTDIR=/tmp/lumeneh-check PREFIX=/usr
   ls DESTDIR is illustrative; use a real empty directory.
   ls /tmp/lumeneh-check/usr/share/icons/hicolor/256x256/apps/lumeneh.png
   ```

Until the final art is dropped in, the repository ships a valid placeholder PNG at the same path so install/uninstall remain testable.
