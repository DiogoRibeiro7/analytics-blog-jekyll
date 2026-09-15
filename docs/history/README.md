# Development History

These documents record how the theme was built: summaries of its development phases, a plan to reorganise its configuration, and a point-in-time security audit. They are kept for context and are **not maintained**. Much of what they describe has changed since, and several of the includes and settings they document were never wired into a layout, so do not follow them as instructions. The [documentation index](../README.md) lists the current guides.

Most of the includes and layouts the phase 2 to 4 summaries describe, and the phase 3 to 5 stylesheets, were removed after v0.7.0 because no layout used them. Git history still has them.

| Document | What it records |
| --- | --- |
| [PHASE1-QUICK-REFERENCE.md](PHASE1-QUICK-REFERENCE.md), [phase1-developer-guide.md](phase1-developer-guide.md), [phase1-example-post.md](phase1-example-post.md) | The first post components: sharing buttons, breadcrumbs, the author card, the table of contents and the difficulty badge. [components.md](../components.md) is the current guide to them; the `phase1_features` settings described here were never read by the theme. |
| [PHASE2-SUMMARY.md](PHASE2-SUMMARY.md) | The sidebar post layout and the series navigation, search facet, code sharing and newsletter includes. |
| [PHASE3-SUMMARY.md](PHASE3-SUMMARY.md) | The archive layout and the reading progress, reading time, recommendation and comment includes. |
| [PHASE4-SUMMARY.md](PHASE4-SUMMARY.md) | The preferences panel and the popular posts, keyboard navigation, social proof and metadata includes. |
| [config-refactoring-plan.md](config-refactoring-plan.md), [config-reorganization-guide.md](config-reorganization-guide.md) | A November 2025 plan to split `_config.yml` into data files, presets and a setup wizard, and a guide to the reorganised file it proposed. The data files, presets and scripts were not created; [configuration-guide.md](../configuration-guide.md) describes where settings live. |
| [security-audit-2025-11-21.md](security-audit-2025-11-21.md) | The npm and Ruby dependency audit of v0.2.0. Its recommendations have since been carried out. |
