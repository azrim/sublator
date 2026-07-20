---
name: Sublator
description: AI-powered subtitle translator for Windows desktop
colors:
  primary: "#171717"
  foreground: "#0A0A0A"
  background: "#ffffff"
  card: "#ffffff"
  secondary: "#F5F5F5"
  muted: "#F5F5F5"
  muted-foreground: "#737373"
  border: "#E5E5E5"
  destructive: "#E7000B"
  destructive-foreground: "#FAFAFA"
typography:
  display-lg:
    fontFamily: "Geist, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.4
  display-sm:
    fontFamily: "Geist, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.4
  body-lg:
    fontFamily: "Geist, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  body-sm:
    fontFamily: "Geist, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.5
  body-xs:
    fontFamily: "Geist, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Geist, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.3
rounded:
  sm: "6px"
  md: "8px"
  lg: "12px"
  xl: "16px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#FAFAFA"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.muted-foreground}"
    rounded: "{rounded.sm}"
    padding: "4px 8px"
  sidebar:
    backgroundColor: "{colors.background}"
    borderRight: "1px solid {colors.border}"
    itemActiveColor: "{colors.primary}"
    itemInactiveColor: "{colors.muted-foreground}"
  header:
    typography: "{typography.display-lg}"
    fontWeight: 600
    padding: "0 0 8px 0"
  card:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.lg}"
    border: "1px solid {colors.border}"
    padding: "24px"
  alert:
    rounded: "{rounded.md}"
    destructiveColor: "{colors.destructive}"
    destructiveBackground: "rgba(231, 0, 11, 0.08)"
  badge-secondary:
    backgroundColor: "{colors.muted}"
    textColor: "{colors.muted-foreground}"
    rounded: "{rounded.sm}"
  badge-destructive:
    backgroundColor: "rgba(231, 0, 11, 0.12)"
    textColor: "{colors.destructive}"
    rounded: "{rounded.sm}"
  progress:
    trackColor: "{colors.muted}"
    indicatorColor: "{colors.primary}"
  tabs:
    activeIndicatorColor: "{colors.primary}"
    inactiveColor: "{colors.muted-foreground}"
  text-field:
    backgroundColor: "{colors.background}"
    textColor: "{colors.primary}"
    rounded: "{rounded.sm}"
    border: "1px solid {colors.border}"
    focusBorderColor: "{colors.primary}"
  switch:
    activeColor: "{colors.primary}"
    inactiveColor: "{colors.muted}"
  dialog:
    backgroundColor: "{colors.background}"
    rounded: "{rounded.lg}"
    padding: "20px"
    maxWidth: "400px"
  tooltip:
    backgroundColor: "{colors.primary}"
    textColor: "#FAFAFA"
    rounded: "{rounded.sm}"
  divider:
    color: "{colors.border}"
    width: "1px"
---

# Design System: Sublator

## 1. Overview

**Creative North Star: "The Quiet Instrument"**

Sublator is a tool that disappears into the task. Like a well-made precision instrument, every surface serves function. No decoration, no noise. The user loads a file, translates it, and exports — and never thinks about the interface.

The system is built on ForUI's neutral desktop theme: near-zero chroma, macOS-style rounded corners, information-dense layouts. Typography carries hierarchy through weight and size, never through color. The UI is monochrome by default; color enters only as semantic signal (error, destructive) or as a primary action accent.

This system rejects: generic SaaS blandness (identical card grids, gray-on-gray), gimmicky UI (gradient text, glassmorphism, decorative blur), and cramped dashboard layouts (too many panels, no breathing room).

**Key Characteristics:**
- Monochrome-first with semantic color sparingly
- Information density appropriate for a desktop tool
- ForUI component vocabulary throughout (consistent affordances)
- Clean separation: sidebar navigation, focused content panels
- Subtitle text is the primary content; UI frames it, never competes
- No Material widgets — pure ForUI + Flutter layout primitives
- Content fills available space (no maxWidth constraints on pages)
- Consistent 16px outer padding across all pages

## 2. Colors

The palette is ForUI neutral — near-zero chroma, functional color only where semantics demand it.

### Primary
- **Ink Black** (#171717): Text, sidebar active state, primary buttons. The dominant "color" in the system — everything else is gray.

### Neutral
- **Paper White** (#ffffff): Main content background, card surfaces.
- **Cloud** (#F5F5F5): Secondary surface, muted backgrounds, disabled states.
- **Muted Foreground** (#737373): Secondary text, labels, timestamps.
- **Border** (#E5E5E5): Separators, input borders, card edges.

### Semantic
- **Error Red** (#E7000B): Failed translations, validation errors, destructive alerts.
- **Destructive Foreground** (#FAFAFA): Text on error backgrounds.

### Named Rules

**The Sparingly Rule.** Color enters the interface only for semantic meaning. Error and destructive are the only non-neutral colors used. Status indicators use mutedForeground (neutral) for done/pending states, and error for failed states. A status indicator turning muted after translation is purposeful; a colored header banner is not.

### AppColors
- **Success Green** (#16A34A light / #4ADE80 dark): Completed translation. Used for per-entry status badges and translation-complete indicators.
- **Warning Amber** (#EAB308 light / #FDE047 dark): Partial translation or retry pending. Used when a chunk needs re-translation or has degraded output.
- **Info Blue** (#2563EB light / #60A5FA dark): In-progress or connecting state. Used for active translation streaming and connection status indicators.

## 3. Typography

**Font Family:** Geist (system-ui fallback)

**Character:** Single sans-serif at multiple weights. No display/body pairing — Geist carries headings through size and weight alone. Product UI doesn't need typographic contrast; it needs typographic hierarchy.

### Hierarchy
- **Display LG** (600 weight, 22px, 1.4 line-height): Page titles ("Preview", "Settings"). Top-level page identifier.
- **Display SM** (600 weight, 16px, 1.4 line-height): Section titles, sidebar app name. Secondary headings.
- **Body LG** (400 weight, 14px, 1.5 line-height): Subtitle text in preview, primary content. Max 65–75ch for readable text blocks.
- **Body SM** (400 weight, 13px, 1.5 line-height): Entry rows, translated text, form labels, descriptions. The workhorse size.
- **Body XS** (400 weight, 11px, 1.4 line-height): Timestamps, status labels, metadata, column headers. Small but readable.
- **Label** (500 weight, 12px, 1.3 line-height): Button text, input placeholders, navigation items.

### Named Rules

**The One Family Rule.** Geist is the only font. No secondary font, no display font, no monospace. Weight and size carry all hierarchy. If something doesn't work at 600/22px Geist, the problem is layout, not typography.

## 4. Elevation

Flat by default. ForUI's desktop theme uses subtle shadows only on elevated surfaces (dialogs, dropdowns, tooltips). The primary depth cue is **tonal layering** — different background colors for sidebar, content area, and cards — not shadows.

### Shadow Vocabulary
- **Dialog/Dropdown**: Subtle ambient shadow on elevated surfaces (ForUI default). Not decorative; purely functional for depth separation.
- **Cards**: No shadow. Border (#E5E5E5) defines card edges. Flat surfaces at rest.

### Named Rules

**The Flat-By-Default Rule.** Surfaces are flat at rest. Shadows appear only on elevated UI elements (dialogs, dropdowns, popovers) — never on cards, list items, or content panels. Depth comes from tonal layering (background color shifts), not from shadows.

### App Style Tokens
- **sidebarWidth**: 200px — Default sidebar width. User-resizable via FResizable, min 150px.
- **sidebarMinWidth**: 150px — Minimum sidebar extent before FResizable clips.
- **titleBarHeight**: 32px — Fixed custom title bar height (DesktopTitleBar).
- **transitionDuration**: 200ms — Default animation duration for AnimatedSwitcher, AnimatedContainer, AnimatedSize. Respects `MediaQuery.disableAnimationsOf`.

## 5. Components

### Buttons (FButton)
- **Shape:** Rounded (8px radius). macOS Tahoe-inspired softness.
- **Primary (default):** Ink black background, white text. Used for primary actions: "Translate", "Open File", "Search".
- **Outline (FButtonVariant.outline):** Transparent background, ink black border and text. Used for secondary actions: "Cancel", "Import", "Export", "Retry failed".
- **Ghost (FButtonVariant.ghost):** No background, no border. Used for icon-only actions: retry single entry, delete glossary row, sidebar close button.
- **Sizes:** `sm` (8px 16px) for dialogs and compact areas; `xs` for icon-only ghost buttons. Default size for main actions.
- **States:** ForUI handles hover/focus/disabled states. Disabled = reduced opacity, onPress: null.
- **Affixes:** `suffix` param for trailing icons (folderOpen, search, download, refreshCw, plus, upload).

### Sidebar Navigation (FSidebar)
- **Style:** ForUI FSidebar with nested FSidebarItem. Three items: "Home" (parent with expandable "Editor" child), "Settings" with FLucideIcons.
- **Nested items:** Home is the parent. Editor appears as a child when a file is loaded. Close button (×) via GestureDetector+FTooltip dismisses the editor and returns to Home.
- **Typography:** Display SM (600 weight) for app name. Body SM for items.
- **Active state:** Primary color indicator. Muted foreground for inactive.
- **Width:** Draggable via FResizable — sidebar/content split is user-resizable. Default 200px, min 150px.

### Resizable Split (FResizable)
- **Layout:** Horizontal axis, sidebar (.fixed extent:200, minExtent:150) + content (.flex).
- **Divider:** FResizable.divider for draggable resize handle.
- **Used for:** Sidebar/content split in AppShell. Replaces fixed-width Row layouts.

### Page Header (FHeader)
- **Usage:** All three pages (Home, Preview, Settings) use FHeader for consistent page titles.
- **Typography:** Display LG (600 weight, 22px).
- **Placement:** Top of each page, within 16px outer padding.

### Cards (FCard)
- **Corner Style:** Rounded (12px radius). macOS Tahoe panel softness.
- **Background:** Paper White (#ffffff).
- **Border:** 1px solid Border (#E5E5E5). No shadow.
- **Internal Padding:** 24px.
- **Used for:** OpenSubtitles search results, home page content container.

### Alert Banners (FAlert)
- **Error banners:** `FAlert(variant: .destructive)` on HomePage and PreviewPage for error states.
- **Icon:** `FLucideIcons.alertCircle` for destructive alerts.
- **Placement:** Positioned at top of content area, animated in/out with AnimatedSize.
- **Replaces:** Raw Container+BoxDecoration error bars with consistent ForUI component.

### Badge (FBadge)
- **Secondary (.secondary):** Muted background, muted foreground text. Used for "done" status indicator.
- **Destructive (.destructive):** Red-tinted background, error color text. Used for "failed" status indicator.
- **Used for:** Per-entry translation status in preview page status column.

### Progress Indicators
- **FCircularProgress(size: .sm):** Loading spinner, per-entry translating status, sidebar/content loading states. 18px default, 16px inline.
- **FDeterminateProgress:** Translation progress bar during active translation. Shows completed/total ratio. Theme-aware track and indicator colors.

### Text Inputs (FTextField)
- **Variants:** Standard (default) and `.sm` size for compact areas (timing editors, inline entry fields).
- **Features:** `label`, `hint`, `obscureText` (credentials), `minLines`/`maxLines`, `keyboardType`, `onSubmit`.
- **Control:** `FTextFieldControl.managed(controller:)` for reactive state.
- **Focus:** ForUI default focus ring (primary color).
- **Used for:** Search queries, API keys, system prompt editing, translated text editing, timing editors.

### Select (FSelect)
- **Variants:** Standard and `.lifted` control style.
- **Features:** `items` map, `hint`, `label`, `control` with `onChange` callback.
- **Used for:** Language selection, model selection, export format picker (SRT/ASS/VTT/SUB).
- **Lifted variant:** Used in settings and preview page for elevated dropdown appearance.

### Select Tile Group (FSelectTileGroup)
- **Usage:** Language selection in OpenSubtitles search dialog.
- **Control:** `FMultiValueControl.managedRadio` for radio-style selection.
- **Children:** FSelectTile per language with title and value.

### Switch (FSwitch)
- **Label:** Inline text label ("Thinking mode").
- **Semantics:** Built-in `semanticsLabel` for accessibility.
- **Used for:** Boolean toggles in settings (thinking mode).

### Tabs (FTabs)
- **Usage:** Settings page — 6 tabs: API Keys, Languages, Models, Prompt, Glossary, Storage.
- **Config:** `expands: true` for full-height tab content.
- **Entries:** `FTabEntry(label:, child:)` per tab.

### Dialogs (FDialog)
- **Trigger:** `showFDialog()` function.
- **Structure:** `FDialog(style:, animation:, constraints:, builder:)`.
- **Constraints:** maxWidth 400px for confirmations, 360–640px for forms.
- **Internal Padding:** 20px.
- **Typography:** `style.titleTextStyle` for title, `style.bodyTextStyle` for body.
- **Actions:** Row of FButton (outline sm + default sm) at bottom-right, 8px spacing.
- **Used for:** Unsaved changes confirmation, close editor confirmation, cancel translation, add glossary entry, reset glossary, delete glossary entry, OpenSubtitles search.

### Toast Notifications (FToast)
- **Trigger:** `showFToast(context:, title:, alignment:)`.
- **Position:** `FToastAlignment.bottomCenter`.
- **Usage:** Success/error/info feedback on file load, export, save, search, translation completion.

### Tooltip (FTooltip)
- **Trigger:** `FTooltip(tipBuilder:, child:)`.
- **Usage:** Help text on buttons (retry, export, close file), status indicators, glossary actions.
- **Styling:** ForUI default (dark background, light text, small radius).

### Divider (FDivider)
- **Usage:** Section separators in settings (between credential sections, glossary header/body), toolbar/body separator in preview page.
- **Styling:** ForUI themed (matches theme.colors.border).

### Title Bar (DesktopTitleBar)
- **Height:** 32px fixed.
- **Background:** `theme.colors.background`.
- **Border:** Bottom `BorderSide(color: theme.colors.border, width: theme.style.borderWidth)`.
- **Controls:** `WindowCaptionButton.minimize/maximize/unmaximize/close` with system brightness.
- **Drag:** `DragToMoveArea` wraps entire bar for window drag + double-click maximize.
- **Left children:** Optional slot for breadcrumbs/logo.

### Animation
- **motionDuration(context):** Helper returns 200ms default, zero if `MediaQuery.disableAnimationsOf` is true.
- **Used in:** AnimatedSwitcher (page transitions, status icon swaps), AnimatedContainer (entry row tint), AnimatedSize (error bar expand/collapse), AnimatedOpacity (translation complete indicator).
- **Page transitions:** FadeTransition via AnimatedSwitcher in AppShell.

### Accessibility
- **Semantics:** Used throughout for screen reader labels on buttons, text fields, status indicators.
- **Labels:** Descriptive labels like "Open subtitle file from disk", "Translation complete", "Translation failed, click to retry".
- **Roles:** `button: true` for interactive elements, `textField: true` for inputs.
- **Reduced motion:** motionDuration respects platform accessibility setting.

### Home Page
- **Landing state:** Centered `FCard` with ConstrainedBox(maxWidth: 400) inside a Column.
- **Tagline:** "AI-powered subtitle translation with smart line-length control."
- **Feature chips:** 3 chips rendered in a `Wrap` (alignment: center, spacing: 12, runSpacing: 6): "SRT, ASS, VTT, SUB" (subtitles icon), "Auto CPL overflow" (wrapText icon), "60+ languages" (languages icon). Each chip is a Row with icon + label in mutedForeground.
- **Actions:** "Open File" primary FButton (Ctrl+O tooltip) + "Search Subtitles" outline FButton.
- **Drag-drop:** AnimatedSwitcher overlay ("Drop subtitle file to load") on desktop_drop events.
- **Errors:** FAlert(.destructive) positioned at top, animated in/out with AnimatedSize.

### Preview Page
- **Primary toolbar:** Action bar with file info (format • N cues), settings summary (source → target · model), progress counter during translation, Translate (primary) and Cancel (outline) buttons, Retry failed button when applicable.
- **Secondary toolbar:** Format picker + export row below the primary toolbar. `FSelect<SubtitleFormat>` dropdown (maxWidth: 130, lifted control) for export format (SRT/ASS/VTT/SUB) + Export outline button (download icon). Spacer fills remaining width.
- **Progress:** FDeterminateProgress bar between toolbars and entry list during active translation.
- **Body:** Header row (Original | Translated | Timing) + ListView.builder with per-entry rows. Each row: original text, editable translated text (FTextField when done/failed), timing editors (S/E in raw ms), status icon column.

### History Page
- **Select/Done toggle:** FButton ghost toggles between "Select" and "Done" labels, switching multi-select mode.
- **Per-row checkboxes:** When selecting, each FTile shows a prefix checkbox icon (checkSquare filled / square empty) toggling selection state.
- **Bulk Delete:** "Delete (N)" button appears when entries are selected. Shows FDialog confirmation ("Delete N entries?") with Cancel/Delete buttons before removing.
- **Additional:** Search bar (filters by filename), Clear All button with confirmation, side-by-side preview panel (original | translated) on entry select, per-entry delete (trash icon), status indicator (check/error icon).

## 6. Do's and Don'ts

### Do:
- **Do** use ForUI components as-is. Don't restyle FButton, FCard, FTextField, or FSidebar. The theme IS the design system.
- **Do** use `theme.typography.display.lg` for page titles, `theme.typography.body.sm` for content. Don't invent font sizes outside the scale.
- **Do** use `theme.colors.mutedForeground` for secondary text and labels. It's the correct gray for subdued content.
- **Do** keep subtitle text at body-lg (14px) for readability. The user reads hundreds of subtitle lines — legibility is paramount.
- **Do** use semantic color only for status: mutedForeground for done/pending, error for failed.
- **Do** let the sidebar be the navigation anchor. Content panels should be self-contained and focused.
- **Do** use FResizable for sidebar/content split — user-draggable resize handle replaces fixed-width layouts.
- **Do** use FBadge for status indicators — secondary for done, destructive for failed.
- **Do** use FAlert(destructive) for error banners — consistent with ForUI styling.
- **Do** wrap interactive elements with Semantics for screen reader accessibility.
- **Do** use motionDuration(context) for all animations to respect reduced-motion settings.
- **Do** use FDivider for section separators — not raw Divider() which uses Material defaults.
- **Do** use FTooltip on icon-only buttons for discoverability.
- **Do** use FToast(bottomCenter) for transient feedback — success, error, info messages.

### Don't:
- **Don't** use Material widgets. The codebase is pure ForUI + Flutter layout primitives.
- **Don't** use gradient text (`background-clip: text`). This is Sublator's explicit anti-reference: "gimmicky UI like early Electron apps."
- **Don't** add decorative blur, glassmorphism, or backdrop-filter effects. The system is flat and functional.
- **Don't** create identical card grids with icon + heading + text patterns. This is the "generic SaaS" anti-reference.
- **Don't** use display fonts or decorative typefaces. Geist is the only font. The "one family" rule applies universally.
- **Don't** add side-stripe borders (`border-left` > 1px as colored accent). Use full borders, background tints, or nothing.
- **Don't** use arbitrary z-index values (999, 9999). Follow the semantic elevation model: content → sidebar → modal → toast.
- **Don't** add animation for decoration. Product motion conveys state change only: loading, success, error. No page-load choreography, no entrance animations on content.
- **Don't** overload a single screen with too many panels or data density. The "cramped dashboard" anti-reference applies — let content breathe.
- **Don't** use maxWidth constraints on pages. Content fills the available space within the resizable split.
- **Don't** use raw Divider() — always FDivider for theme-consistent styling.
- **Don't** hardcode border widths — always use `theme.style.borderWidth`.
