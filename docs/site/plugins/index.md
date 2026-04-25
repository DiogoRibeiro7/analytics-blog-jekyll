---
title: Plugin marketplace
description: Discover official and community DataLog plugins, understand the hook system, and jump into building your own extensions.
permalink: /plugins/
---

## Explore available plugins

<div class="card-grid">
{% for plugin in site.data.plugins %}
  <article class="card">
    <h3 id="{{ plugin.id }}"><a href="#{{ plugin.id }}">{{ plugin.name }}</a></h3>
    <p>{{ plugin.summary }}</p>
    <dl>
      <dt>Hooks</dt>
      <dd>{{ plugin.hooks | join: ', ' }}</dd>
      {% if plugin.configuration %}
        <dt>Configuration highlights</dt>
        <dd>
          <ul>
          {% for key, value in plugin.configuration %}
            <li><strong>{{ key }}:</strong> {{ value }}</li>
          {% endfor %}
          </ul>
        </dd>
      {% endif %}
      {% if plugin.includes %}
        <dt>Template helpers</dt>
        <dd>
          <ul>
          {% for helper in plugin.includes %}
            <li><code>{{ helper | escape }}</code></li>
          {% endfor %}
          </ul>
        </dd>
      {% endif %}
      <dt>Status</dt>
      <dd>{{ plugin.status | capitalize }}</dd>
    </dl>
  </article>
{% endfor %}
</div>

## Build your own extension

Follow the [plugin development guide](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/blob/main/docs/plugin-development.md) to learn how hooks work, how to register custom Liquid tags, and how to publish your work to the community directory.

Have an extension to share? [Open an issue](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues/new?template=plugin-proposal.md) with details and we will review it for inclusion.
