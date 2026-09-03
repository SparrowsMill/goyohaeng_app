# 고요행 App — Global Design System

Apply this system consistently to every 고요행 screen.

Use a 390px-wide mobile frame only.
Do not create tablet, desktop, or dark-mode layouts.

Building routing/navigation or a new screen? See `docs/user_flow.md` for the
page list, per-screen content, and navigation triggers (user-side flow only).

## 1. Color

Core colors:

- Primary: #7E8442
- Primary pressed: #626730
- Primary hover: #72793B
- Secondary accent: #E89A45
- Secondary accent pressed: #CF8136

Surfaces:

- App background: #FAE7C0 — always set this as the screen's base `Container`/
  `Scaffold` background color, on every screen, regardless of whether a scene
  image is present yet. Scene images (see `assets/illustrations/scenes/` in
  §9) are supplied as opaque, non-transparent PNGs already painted with this
  same color, not cutouts — so #FAE7C0 underneath is a safety net (covers any
  edge gap, a missing/not-yet-provided image, or slow load), not the visible
  background in the normal case.
- Primary surface / card background: #FFFDF8
- Secondary surface / selected light background: #EEF0DE
- Disabled surface: #E9E3D9

Text:

- Primary text: #4C3927
- Secondary text: #8A7A66
- Disabled / placeholder text: #B7AA9A
- Text on primary button: #FFFFFF

Border and divider:

- Border: #E5DAC8
- Light divider: #EEE6DA
- Focus border: #7E8442

Status colors:

- Success: #66743C
- Success background: #EAF0D8
- Error: #B75E4D
- Error background: #F8E6E1
- Warning: #C88432
- Warning background: #FBECD8
- Info: #6E7A8E
- Info background: #E8EDF3

Do not support dark mode in version 1.

## 2. Typography

Use Korean traditional serif or calligraphic typography for all Korean and English UI text.

Font family:

- Korean: "Gowun Batang"
- English and numerals: "Noto Serif"
- Fallback: serif

Use regular weight by default. Use medium or semibold only for headings, important numbers, button labels, and selected navigation labels.

Type scale:

- Display: 32px, 600, line-height 42px, letter-spacing -0.5px
- H1: 28px, 600, line-height 38px, letter-spacing -0.4px
- H2: 24px, 600, line-height 34px, letter-spacing -0.3px
- H3: 20px, 600, line-height 30px, letter-spacing -0.2px
- Title: 18px, 600, line-height 28px, letter-spacing -0.1px
- Body Large: 16px, 400, line-height 25px, letter-spacing 0
- Body Medium: 14px, 400, line-height 22px, letter-spacing 0
- Body Small: 13px, 400, line-height 20px, letter-spacing 0
- Caption: 12px, 400, line-height 18px, letter-spacing 0
- Button Large: 16px, 600, line-height 24px, letter-spacing 0
- Button Medium: 14px, 600, line-height 20px, letter-spacing 0
- Numeric Score: 24px, 600, line-height 30px, letter-spacing 0.5px
- Verification Code: 40px, 600, line-height 52px, letter-spacing 5px

## 3. Spacing and Layout

Use a 4px-based spacing system.

Spacing scale:

- 4px
- 8px
- 12px
- 16px
- 20px
- 24px
- 32px
- 40px
- 48px

Layout rules:

- Mobile screen width: 390px
- Standard horizontal page padding: 20px
- Compact horizontal padding: 16px
- Standard vertical section gap: 24px
- Gap between related elements: 8px or 12px
- Gap between card groups: 16px
- Major section gap: 32px
- Use a single-column mobile layout.
- Keep all primary cards, CTA buttons, lists, and map content aligned to the same content width.
- Do not allow content to touch the screen edge.
- Use vertically scrollable page content when needed.

## 4. Border Radius

Use soft rounded corners consistently.

- Primary large CTA button: 16px
- Secondary button: 14px
- Small outlined button: 12px
- Pill / filter / keyword tag / status chip: 999px
- Standard card: 20px
- Large feature card: 24px
- List row: 16px
- Input field: 14px
- Bottom sheet: 28px top-left and top-right, 0px bottom corners
- Modal: 24px
- Icon container: 12px

## 5. Shadow and Elevation

Use warm, subtle, low-opacity shadows only.

Card shadow:

- 0px 4px 12px rgba(76, 57, 39, 0.08)

Elevated card shadow:

- 0px 8px 20px rgba(76, 57, 39, 0.10)

Primary button shadow:

- 0px 4px 10px rgba(98, 103, 48, 0.20)

Modal or bottom-sheet shadow:

- 0px -8px 24px rgba(76, 57, 39, 0.12)

Pressed state:

- Remove or reduce the shadow to 0px 2px 6px rgba(76, 57, 39, 0.08)

Do not use harsh black shadows, strong elevation, or sharp drop shadows.

## 6. Icons

Use Material Symbols Rounded as the standard icon set.

In code, use the `material_symbols_icons` package — `Symbols.<name>_rounded`
from `package:material_symbols_icons/symbols.dart`. Do not use Flutter's
built-in `Icons` class (Material Icons Filled), which does not match this
icon style.

Use custom watercolor illustrations only for:

- Sparrow character
- Mill ingredient rewards
- Travel reward scenes
- Decorative map storytelling elements

Use simple line icons for all functional UI actions.

Icon size scale:

- Small: 16px
- Default: 20px
- Navigation: 24px
- Prominent action: 28px
- Illustration-support icon: 32px

Use icon stroke weight equivalent to Material Symbols Rounded, approximately 1.5px to 2px.

Functional icons must use:

- Primary icon color: #4C3927
- Active icon color: #7E8442
- Inactive icon color: #8A7A66
- Disabled icon color: #B7AA9A
- Icon on primary button: #FFFFFF

## 7. Component Styles

**Primary Button:**

- Height: 56px
- Background: #7E8442
- Text: #FFFFFF
- Radius: 16px
- Shadow: 0px 4px 10px rgba(98, 103, 48, 0.20)
- Pressed background: #626730
- Pressed shadow: 0px 2px 6px rgba(76, 57, 39, 0.08)
- Disabled background: #E9E3D9
- Disabled text: #B7AA9A
- Horizontal padding: 20px
- Icon-to-label gap: 8px

**Secondary Outlined Button:**

- Height: 48px
- Background: #FFFDF8
- Text: #626730
- Border: 1px solid #E5DAC8
- Radius: 14px
- Pressed background: #EEF0DE
- Disabled background: #F3EFE7
- Disabled text: #B7AA9A

**Small Button:**

- Height: 36px
- Horizontal padding: 12px
- Radius: 12px
- Use outlined style unless specifically designated as a primary action.

**Filter / Keyword Tag:**

- Height: 36px
- Horizontal padding: 14px
- Radius: 999px
- Default background: #FFFDF8
- Default text: #626730
- Default border: 1px solid #E5DAC8
- Selected background: #7E8442
- Selected text: #FFFFFF
- Pressed background: #626730

**Status Chip:**

- Height: 28px
- Horizontal padding: 10px
- Radius: 999px
- Font: Caption, 12px, 600

**Input Field:**

- Height: 52px
- Background: #FFFDF8
- Border: 1px solid #E5DAC8
- Radius: 14px
- Text: #4C3927
- Placeholder: #B7AA9A
- Focus border: 2px solid #7E8442
- Error border: 2px solid #B75E4D
- Horizontal padding: 16px

**App Bar:**

- Height: 56px
- Horizontal padding: 20px
- Background: #FAE7C0
- Title: Title style, 18px, 600, centered
- Back icon: 24px
- No thick bottom divider
- If separation is necessary, use only a 1px #EEE6DA divider

**Bottom Navigation:**

- Height: 72px, excluding device safe area
- Background: #FFFDF8
- Top divider: 1px solid #EEE6DA
- Four tabs only:
  - 방앗간
  - 지도
  - 랭킹
  - 기록
- Do not include a "마이" tab.
- Icon size: 24px
- Label: Caption, 12px, 600
- Active icon and label: #7E8442
- Inactive icon and label: #8A7A66
- Active tab uses no heavy filled background; use only color emphasis or a subtle #EEF0DE indicator.

**Card:**

- Background: #FFFDF8
- Border: 1px solid #E5DAC8
- Radius: 20px
- Standard padding: 16px
- Large card padding: 20px or 24px
- Standard shadow: 0px 4px 12px rgba(76, 57, 39, 0.08)

**Bottom Sheet / Modal:**

- Background: #FFFDF8
- Radius: 28px 28px 0px 0px for bottom sheet
- Radius: 24px for modal
- Padding: 24px
- Shadow: 0px -8px 24px rgba(76, 57, 39, 0.12)

## 8. Motion

Use calm and subtle motion.

- Standard transition duration: 200ms
- Page transition duration: 250ms
- Modal and bottom-sheet transition duration: 300ms
- Press feedback duration: 120ms
- Easing: ease-out
- Recommended curve: cubic-bezier(0.2, 0, 0, 1)

Avoid bouncy, fast arcade-game motion.

Use a soft fade, slight vertical slide, or gentle scale transition only.

## 9. Asset and Platform Scope

- Supported platform: mobile app only
- Target design width: 390px
- Tablet support: not included
- Desktop/web support: not included
- Dark mode: not included

### Asset naming convention

All illustration/branding assets live under `assets/` and are declared as whole
directories in `pubspec.yaml`, so a new file matching the convention below is
picked up automatically — no pubspec edit needed per file.

Format: `{subject}[_{variant}].png` in snake_case, PNG with transparent
background, exported at 3x the largest on-screen display size (Flutter
downsamples cleanly; no `2.0x`/`3.0x` variant folders needed).

- `assets/branding/`
  - `app_icon.png` — app icon source (1024x1024)
  - `app_logo.png` — in-app logo lockup (wordmark + decorative flourish + tagline,
    baked in as a single image)
  - `splash.png` — splash screen image
  - `leaf_ornament.png` — small decorative leaf/branch flourish used beside section
    headings (e.g. "로그인" / "회원가입" card titles); mirror horizontally in code
    for the opposite side instead of exporting a second file
  - `paper_texture.png` — seamless/tileable paper-grain texture, applied app-wide
    at very low opacity by `PaperTextureOverlay` (`lib/widgets/paper_texture_overlay.dart`),
    wired in once via `MaterialApp.builder` in `main.dart`. No per-screen code
    needed — every screen, dialog, and bottom sheet picks it up automatically.
    Must tile with no visible seam; export with a transparent (not white) base
    so only the grain shows
- `assets/illustrations/sparrow/`
  - `sparrow_default.png`, `sparrow_{state}.png` — sparrow character per pose/emotion (e.g. `sparrow_happy.png`)
- `assets/illustrations/rewards/`
  - `ingredient_{name}.png` — mill ingredient reward images (e.g. `ingredient_rice.png`)
  - `travel_{name}.png` — travel reward scene images (e.g. `travel_beach.png`)
- `assets/illustrations/map/`
  - `map_{name}.png` — decorative map storytelling elements (e.g. `map_windmill.png`)
  - Screen-specific map art may instead follow a `main_{name}.png` / `{name}_icon.png`
    pattern where a screen's whole map card is delivered as one or two flattened
    images rather than many small pieces (e.g. mill-home's `main_map.png` — the
    Korea watercolor map with its static badge pins baked in — plus a separate
    `cur_position_icon.png` overlaid in code at the current/selected location,
    and `main_mill_list.png`, the entire region-list card baked as one static image)
- `assets/illustrations/icon/`
  - `main_{name}_icon.png` — small cutout (RGBA) decorative icons standing in for
    what would otherwise be a functional Material Symbol, used where the design
    calls for a more illustrated look than a line icon (e.g. mill-home's stat
    row: `main_calendar_icon.png`, `main_collected_icon.png`, `main_verified_icon.png`;
    and its CTA button icon `main_meal_icon.png`). Default to Material Symbols
    (§6) unless an asset in this folder covers that specific icon.
- `assets/illustrations/scenes/`
  - `{name}.png` — watercolor scene for one screen or a group of related
    screens, painted as a top-anchored header band (full screen width, its
    own aspect ratio sets the height) sitting over the `#FAE7C0` base fill
    that shows through everything below it — not a full-bleed image (e.g.
    `auth_bg.png` behind signup only — the
    login screen intentionally omits it in favor of a flat `#FAE7C0` fill so
    its larger logo reads as the hero element there; conversely signup shows
    the scene but no logo; `account_bg.png` behind the account center;
    `mill_bg.png` behind the mill-home screen, with the standalone
    `sparrow/sparrow_default.png` character composited on top in code rather
    than baked into the scene, so it can be reused/repositioned per screen).
    Every screen in the app gets
    one of these behind its content; screens that share a clear visual
    grouping (e.g. auth flow) may share one file. Supplied as an opaque PNG
    (no transparency/cutout) already painted with the #FAE7C0 app background
    color, so it drops in directly over the base `#FAE7C0` `Scaffold`.

Reference assets in code via `Image.asset('assets/<category>/<file>.png')`.
Do not invent placeholder art for a missing file — if a screen needs an asset
that isn't in these folders yet, ask for it instead of generating a stand-in.
The user supplies each scene image; when building a new screen and no matching
`scenes/{name}.png` exists yet, ask for it rather than shipping a flat-color
background as a substitute.

## Important

Every screen must use these exact design-system values.

Keep the Korean watercolor storybook mood, soft cream surfaces, olive-green actions, warm brown typography, subtle warm shadows, and traditional Korean serif/calligraphic typography consistent across map, ranking, place, trend, visit-verification, reward, unavailable, and error-state pages.
