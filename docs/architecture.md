# Architecture Overview

## High-Level Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                        App Shell (main.dart)                     │
│  ┌─────────┐     ┌──────────────────────────────────────────┐   │
│  │ Sidebar │     │         FResizable (draggable)            │   │
│  │ ▾ Home  │ ──→ │  ┌──────────────┐  ┌─────────────────┐   │   │
│  │   Editor│     │  │  HomePage     │  │   PreviewPage   │   │   │
│  │ Settings│     │  │  File picker  │  │   Side-by-side  │   │   │
│  └─────────┘     │  │  Drag-drop    │  │   Streaming     │   │   │
│                  │  │  OpenSubtitles│  │   Inline edit   │   │   │
│                  │  └──────────────┘  │   Export         │   │   │
│                  │                     └─────────────────┘   │   │
│                  │  ┌──────────────┐                          │   │
│                  │  │ SettingsPage │                          │   │
│                  │  │ Languages    │     ┌──────────────────┐ │   │
│                  │  │ Models       │     │ Services Layer   │ │   │
│                  │  │ Prompt       │     │ ┌────────┐ ┌───┐ │ │   │
│                  │  │ Glossary     │     │ │Settings│ │GP │ │ │   │
│                  │  │ Credentials  │     │ │Service │ │Sv │ │ │   │
│                  │  └──────────────┘     │ └───┬────┘ └─┬─┘ │ │   │
│                  │                       │     │        │   │ │   │
│                  │                       │ ┌───┴────────┴─┐ │ │   │
│                  │                       │ │Drift (SQLite)│ │ │   │
│                  │                       │ └──────────────┘ │ │   │
│                  │                       └──────────────────┘ │   │
│                  └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

## Provider Hierarchy

```
ProviderScope
└── appDatabaseProvider (keepAlive: true)
    ├── settingsServiceProvider
    ├── glossaryServiceProvider
    ├── systemPromptServiceProvider
    └── credentialServiceProvider (direct instance, not FutureProvider)
```

- `appDatabaseProvider` is `keepAlive: true` — single database instance for app lifetime
- All other services are `FutureProvider` — await database readiness
- `CredentialService` is instantiated directly (no Drift dependency)

## Navigation

```
AppShell (FScaffold + FSidebar + FResizable)
├── FSidebar
│   ├── Home (parent)
│   │   └── Editor (child, shown when file loaded, × close button)
│   └── Settings (top-level)
└── Content area (FResizable, user-draggable resize)
    ├── HomePage (file picker / drag-drop / OpenSubtitles)
    ├── PreviewPage (streaming translation + export)
    └── SettingsPage (all configuration)
```

- FSidebar with nested items: Home is parent, Editor is child (conditionally shown when file loaded)
- Close button (×) on Editor child dismisses editor and returns to Home
- FResizable allows user to drag-resize sidebar/content split
- IndexedStack preserves state across sidebar switches
- All pages use FHeader at top for consistent page titles
- Content fills available space — no hardcoded maxWidth constraints

## Window Lifecycle

```
main() → WindowManager.ensureInitialized()
       → WindowOptions(1200x800, min 800x600, hidden title bar)
       → waitUntilReadyToShow → show + focus

AppShell.initState → restore position/size from Drift (SettingsService)
AppShell.dispose → save position/size back to Drift
                   → windowManager.destroy()
```
