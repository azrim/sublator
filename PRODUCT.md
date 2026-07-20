# Product

## Register

product

## Platform

Windows desktop

## Users

Content consumers who download subtitle files in the wrong language and want a quick, accurate translation. They open the app, load a subtitle file, pick a target language, and get a translated file. They are not translators — they want the tool to handle the work. Context: personal media consumption, sharing with friends/family, archiving.

## Product Purpose

Sublator translates subtitle files (SRT, ASS, VTT, MicroDVD) from any language to any language using AI streaming translation. It exists because subtitle files are abundant but rarely in the language you need, and machine translation of subtitles requires special handling (line length limits, speaker labels, timing preservation) that generic tools don't provide.

Success: the user loads a file, clicks translate, gets a well-formatted subtitle file in their language — with correct line lengths, preserved timing, and no broken formatting.

## Positioning

The only subtitle translator that handles the actual constraints of subtitle files: line length, timing, speaker labels, and format conversion — not just raw text translation.

## Brand Personality

Clean and premium. Functional, modern, polished — feels like a tool built by someone who cares about craft. Not flashy, not plain. Quiet confidence. The interface should feel like a well-made instrument: everything where you expect it, no surprises, no friction.

## Anti-references

- **Generic SaaS** (Notion templates, mid-tier web apps): bland gray palette, identical card grids, no visual hierarchy. Sublator has rich content (subtitle text) that deserves visual structure.
- **Gimmicky UI** (early Electron apps, glassmorphism showcases): gradient text, decorative blur, gratuitous animation. Sublator does real work; decoration is noise.
- **Cramped dashboard** (Grafana, admin panels): over-loaded with data panels, no breathing room. Sublator has focused screens — a file picker, a preview, settings — each with clear purpose.

## Design Principles

1. **Task-first**: Every screen serves one job. The user should never wonder "what am I supposed to do here?"
2. **Earned familiarity**: Standard affordances, consistent component vocabulary. Users who know any desktop app should feel at home instantly.
3. **Content is king**: Subtitle text is the primary content. The UI exists to frame it, not compete with it. Typography and spacing serve readability of translations.
4. **Quiet confidence**: No flashy effects needed. Precision in spacing, alignment, and timing conveys quality. The tool should feel fast and reliable, not decorated.
5. **Progressive disclosure**: Complexity (glossary, system prompts, model selection) lives in settings. The main flow is simple: load → translate → export.

## Accessibility & Inclusion

Desktop app: standard keyboard navigation. Sufficient contrast on ForUI theme. Reduced motion handled by Flutter framework defaults. No specific WCAG target beyond what ForUI provides out of the box.
