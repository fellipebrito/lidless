#!/usr/bin/env bash
# Renders the app icon from one SVG. Drawn rather than bundled as bitmaps so the
# 1024 and the 16 come from the same geometry and stay sharp on every display.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../app/Resources/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

cat > "$TMP/icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FF7A1A"/>
      <stop offset="60%" stop-color="#E8420E"/>
      <stop offset="100%" stop-color="#8C1D05"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" rx="228" fill="#0B0B0C"/>
  <!-- the eye: two arcs meeting at the corners, deliberately lidless -->
  <path d="M 152 512 Q 512 232 872 512 Q 512 792 152 512 Z" fill="url(#glow)"/>
  <path d="M 152 512 Q 512 232 872 512 Q 512 792 152 512 Z"
        fill="none" stroke="#FFD9A8" stroke-width="26" stroke-linejoin="round"/>
  <!-- vertical slit pupil -->
  <ellipse cx="512" cy="512" rx="52" ry="188" fill="#140703"/>
  <ellipse cx="512" cy="512" rx="20" ry="150" fill="#000"/>
</svg>
SVG

render() { # size, filename
  "$CHROME" --headless --disable-gpu --hide-scrollbars --default-background-color=00000000 \
    --force-device-scale-factor=1 --window-size="$1,$1" \
    --screenshot="$OUT/$2" "file://$TMP/icon.svg" >/dev/null 2>&1
}
mkdir -p "$OUT"
for s in 16 32 64 128 256 512 1024; do render "$s" "icon_${s}.png"; done

cat > "$OUT/Contents.json" <<'J'
{
  "images" : [
    { "idiom":"mac", "scale":"1x", "size":"16x16",   "filename":"icon_16.png" },
    { "idiom":"mac", "scale":"2x", "size":"16x16",   "filename":"icon_32.png" },
    { "idiom":"mac", "scale":"1x", "size":"32x32",   "filename":"icon_32.png" },
    { "idiom":"mac", "scale":"2x", "size":"32x32",   "filename":"icon_64.png" },
    { "idiom":"mac", "scale":"1x", "size":"128x128", "filename":"icon_128.png" },
    { "idiom":"mac", "scale":"2x", "size":"128x128", "filename":"icon_256.png" },
    { "idiom":"mac", "scale":"1x", "size":"256x256", "filename":"icon_256.png" },
    { "idiom":"mac", "scale":"2x", "size":"256x256", "filename":"icon_512.png" },
    { "idiom":"mac", "scale":"1x", "size":"512x512", "filename":"icon_512.png" },
    { "idiom":"mac", "scale":"2x", "size":"512x512", "filename":"icon_1024.png" }
  ],
  "info" : { "author":"xcode", "version":1 }
}
J
echo "  icon set rendered to $OUT"
