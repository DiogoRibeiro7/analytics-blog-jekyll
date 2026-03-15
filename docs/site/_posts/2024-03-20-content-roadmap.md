---
title: Documentation content roadmap
summary: Track upcoming guides, visualization recipes, and showcase submissions planned for the next quarter.
tags: [roadmap, planning]
---

Keeping the documentation site fresh mirrors how we maintain the theme itself. Below is the current roadmap for the next
quarter. Each initiative now links to its tracking issue so ownership, scope, and deadlines are visible to the whole team.

## Q2 priorities

- **Migration videos** – Record short screen-casts for each migration guide so teams can follow along visually.
- **Search playbook** – Extend the search section with Algolia and Pagefind integration walkthroughs.
- **Analytics recipes** – Publish notebooks for feature stores, streaming anomaly detection, and LLM evaluation frameworks.

## Execution plan

| Initiative | Tracking issue | Owner(s) & bandwidth | Status | Target milestone | Notes |
| --- | --- | --- | --- | --- | --- |
| Migration videos | [#215](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues/215) | Diogo Ribeiro (6 hrs, scripting) + Media Studio (10 hrs, recording/editing) | In production | Publish beta cuts by end of week 8 | Schedule post-production review in week 9 before publishing alongside migration docs. |
| Search playbook | [#216](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues/216) | Docs team (12 hrs) with platform engineering review (4 hrs) | Drafting | Merge walkthroughs by end of week 9 | Cover Algolia and Pagefind integrations with configuration snippets and troubleshooting. |
| Analytics recipes | [#217](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues/217) | Data science guild (18 hrs staggered weeks 9–11) | Rescoped | Release feature-store + anomaly notebooks in week 10, LLM evaluation in week 11 | Split delivery keeps workload manageable and leaves space for peer review between drops. |

## Contribution workflow

1. Open an issue with the label `docs` in the [`analytics-blog-jekyll`](https://github.com/DiogoRibeiro7/analytics-blog-jekyll)
   repository describing your idea.
2. Submit a PR updating the relevant section (features, guides, or showcase) with screenshots, metadata, and links.
3. The documentation team reviews weekly and deploys via the automated GitHub Actions pipeline.

## Feedback loop

We love hearing how teams are using the DataLog theme. Share your deployments so we can include them in the
[showcase](/showcase/) and inspire others.
