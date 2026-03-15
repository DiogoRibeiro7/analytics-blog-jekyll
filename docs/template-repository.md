# Publishing the Datalog Starter Template

This guide walks you through creating a reusable GitHub template repository so new projects can bootstrap a Datalog-powered analytics site in minutes.

## 1. Create the repository

1. Sign in to GitHub with the account that will own the template (for example, `DiogoRibeiro7`).
2. Navigate to <https://github.com/new> and create a repository named **datalog-starter**.
3. Mark the repository as **Public** so other users can clone it.
4. Check **Template repository** to enable the "Use this template" button.

## 2. Populate the starter files

The `/template` directory in this project contains a fully working starter site. You can copy it into the new repository by running:

```bash
# From the analytics-blog-jekyll project root
git archive HEAD template | tar -x -C /tmp/datalog-starter
```

Then initialize the GitHub repository with the exported files:

```bash
cd /tmp/datalog-starter
git init
git add .
git commit -m "Bootstrap Datalog starter"
git remote add origin git@github.com:DiogoRibeiro7/datalog-starter.git
git push -u origin main
```

> 💡 Update the remote to match your GitHub username if different.

## 3. Review configuration

- `_config.yml` ships with sensible defaults for navigation, pagination, and analytics placeholders.
- `_posts`, `_pages`, `_portfolio`, `_datasets`, and `_notebooks` each include sample content that exercises the theme's layouts.
- `_sass/theme.scss` contains a minimal brand palette you can adjust or remove.
- `.github/workflows/deploy.yml` configures automated GitHub Pages deployments.

## 4. Enable GitHub Pages

1. Open **Settings → Pages** in the template repository.
2. Set **Source** to "GitHub Actions".
3. Save the settings. The next successful workflow run will publish the site.

## 5. Test the deployment workflow

After pushing the template files, GitHub Actions will trigger the **Deploy site** workflow. Once it finishes:

1. Visit the workflow run details to confirm the `deploy` job published to GitHub Pages.
2. Verify the live site at `https://<username>.github.io/datalog-starter/`.

## 6. Share the template

- Update `README.md` in the template repository with onboarding instructions for your team.
- Consider tagging releases so consumers can pin to a specific starter version.
- Link to the template from your documentation, onboarding materials, or organization README.

Following these steps ensures the template repository is ready for others to use via the "Use this template" button, delivering a turn-key analytics storytelling experience.
