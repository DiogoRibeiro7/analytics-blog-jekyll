---
layout: page
title: Packages
permalink: /packages/
description: Software packages, libraries, and tools for data science and research
---

<div class="packages-index">
  <div class="packages-index__header">
    <h1>Packages & Libraries</h1>
    <p class="packages-index__intro">
      Open-source software packages, libraries, and tools for data science, machine learning, and statistical analysis.
      Each package includes comprehensive documentation, API references, examples, and installation instructions.
    </p>
  </div>

  <div class="packages-grid">
    {% for package in site.packages %}
      <article class="package-card">
        <div class="package-card__header">
          {% if package.icon %}
            <span class="package-card__icon">{{ package.icon }}</span>
          {% endif %}
          <h3 class="package-card__title">
            <a href="{{ package.url | relative_url }}">{{ package.title }}</a>
          </h3>
        </div>

        {% if package.tagline %}
          <p class="package-card__tagline">{{ package.tagline }}</p>
        {% endif %}

        {% if package.description %}
          <p class="package-card__description">{{ package.description }}</p>
        {% endif %}

        <div class="package-card__meta">
          {% if package.language %}
            <span class="package-card__badge package-card__badge--language">
              {{ package.language }}
            </span>
          {% endif %}

          {% if package.version %}
            <span class="package-card__badge package-card__badge--version">
              v{{ package.version }}
            </span>
          {% endif %}

          {% if package.license %}
            <span class="package-card__badge package-card__badge--license">
              {{ package.license }}
            </span>
          {% endif %}
        </div>

        <div class="package-card__links">
          <a href="{{ package.url | relative_url }}" class="package-card__link">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
              <polyline points="14 2 14 8 20 8"></polyline>
            </svg>
            Documentation
          </a>

          {% if package.github_url %}
            <a href="{{ package.github_url }}" class="package-card__link" target="_blank" rel="noopener">
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
              </svg>
              GitHub
            </a>
          {% endif %}
        </div>
      </article>
    {% endfor %}

    {% if site.packages.size == 0 %}
      <div class="packages-empty">
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
        </svg>
        <h3>No packages yet</h3>
        <p>Package documentation will appear here.</p>
      </div>
    {% endif %}
  </div>
</div>

<style>
.packages-index {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem 1rem;
}

.packages-index__header {
  text-align: center;
  margin-bottom: 3rem;
}

.packages-index__intro {
  max-width: 800px;
  margin: 1rem auto 0;
  font-size: 1.125rem;
  line-height: 1.6;
  color: #6c757d;
}

.packages-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 2rem;
  margin-top: 2rem;
}

.package-card {
  display: flex;
  flex-direction: column;
  padding: 1.5rem;
  background: white;
  border: 1px solid #e1e4e5;
  border-radius: 8px;
  transition: all 0.2s ease;
}

.package-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  border-color: #2980b9;
}

.package-card__header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.package-card__icon {
  font-size: 2rem;
}

.package-card__title {
  margin: 0;
  font-size: 1.5rem;

  a {
    color: #2980b9;
    text-decoration: none;

    &:hover {
      text-decoration: underline;
    }
  }
}

.package-card__tagline {
  margin: 0 0 1rem;
  font-size: 1rem;
  font-weight: 500;
  color: #495057;
}

.package-card__description {
  margin: 0 0 1rem;
  color: #6c757d;
  line-height: 1.6;
  flex: 1;
}

.package-card__meta {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-bottom: 1rem;
}

.package-card__badge {
  display: inline-block;
  padding: 0.25rem 0.625rem;
  border-radius: 4px;
  font-size: 0.8125rem;
  font-weight: 500;

  &--language {
    background: #e7f2fa;
    color: #2980b9;
  }

  &--version {
    background: #dbf5e8;
    color: #27ae60;
  }

  &--license {
    background: #f8f9fa;
    color: #6c757d;
  }
}

.package-card__links {
  display: flex;
  gap: 1rem;
  margin-top: auto;
  padding-top: 1rem;
  border-top: 1px solid #e1e4e5;
}

.package-card__link {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  color: #2980b9;
  text-decoration: none;
  font-weight: 500;
  font-size: 0.9375rem;

  &:hover {
    text-decoration: underline;
  }
}

.packages-empty {
  grid-column: 1 / -1;
  text-align: center;
  padding: 4rem 2rem;
  color: #6c757d;

  svg {
    margin-bottom: 1rem;
    color: #adb5bd;
  }

  h3 {
    margin: 0 0 0.5rem;
    color: #495057;
  }

  p {
    margin: 0;
  }
}

@media (max-width: 768px) {
  .packages-grid {
    grid-template-columns: 1fr;
  }
}
</style>
