---
title: Academic Operations
layout: page
permalink: /academic/
subtitle: Citations, submissions, collaborations, and upcoming events
---

{% assign academic = site.data.academic %}
{% assign citations = academic.citations %}

{% if citations.metrics %}
## Citation Metrics

<div class="research-metrics">
  <div class="card">
    <span class="stat__value">{{ citations.metrics.total }}</span>
    <span class="stat__label">Total citations</span>
  </div>
  <div class="card">
    <span class="stat__value">{{ citations.metrics.h_index }}</span>
    <span class="stat__label">h-index</span>
  </div>
  <div class="card">
    <span class="stat__value">{{ citations.metrics.i10_index }}</span>
    <span class="stat__label">i10-index</span>
  </div>
</div>

{% if citations.yearly_totals %}
### Citations by Year

<div class="card">
  <div class="year-chart">
    {% for year in citations.yearly_totals %}
    <div class="year-chart__bar">
      <span class="year-chart__value">{{ year[1] }}</span>
      <div class="year-chart__fill" style="--bar-height: {{ year[1] | times: 100 | divided_by: 70 }}%"></div>
      <span class="year-chart__label">{{ year[0] }}</span>
    </div>
    {% endfor %}
  </div>
</div>
{% endif %}
{% endif %}

{% if academic.submissions and academic.submissions.size > 0 %}
## Submission Tracker
{: #submission-tracker}

<div class="card-grid">
{% for sub in academic.submissions %}
  <article class="card">
    <p class="card-meta">
      <span class="post-meta__badge">{{ sub.status }}</span>
      <span>{{ sub.type | capitalize }}</span>
    </p>
    <h3>{{ sub.title }}</h3>
    <p>{{ sub.venue }}</p>
    {% if sub.deadline %}<p class="card-meta">Deadline: {{ sub.deadline }}</p>{% endif %}
    {% if sub.collaborators and sub.collaborators.size > 0 %}
      <p class="card-meta">with {{ sub.collaborators | join: ', ' }}</p>
    {% endif %}
    {% if sub.notes %}<p class="card-meta"><em>{{ sub.notes }}</em></p>{% endif %}
  </article>
{% endfor %}
</div>
{% endif %}

{% if academic.workflow %}
## Workflow

{% if academic.workflow.peer_review and academic.workflow.peer_review.size > 0 %}
### Peer Review

<div class="card-grid">
{% for review in academic.workflow.peer_review %}
  <article class="card">
    <p class="card-meta"><span class="post-meta__badge">{{ review.status }}</span></p>
    <h3>{{ review.title }}</h3>
    <p>{{ review.journal }}</p>
    <p class="card-meta">Due: {{ review.due_date }}</p>
    {% if review.notes %}<p class="card-meta"><em>{{ review.notes }}</em></p>{% endif %}
  </article>
{% endfor %}
</div>
{% endif %}

{% if academic.workflow.collaborations and academic.workflow.collaborations.size > 0 %}
### Collaborations

<div class="card-grid">
{% for collab in academic.workflow.collaborations %}
  <article class="card">
    <p class="card-meta">
      <span class="post-meta__badge">{{ collab.stage }}</span>
      <span>{{ collab.role }}</span>
    </p>
    <h3>{{ collab.name }}</h3>
    {% if collab.notes %}<p>{{ collab.notes }}</p>{% endif %}
    {% if collab.contact %}<p class="card-meta"><a href="mailto:{{ collab.contact }}">{{ collab.contact }}</a></p>{% endif %}
  </article>
{% endfor %}
</div>
{% endif %}
{% endif %}

{% if academic.calendar and academic.calendar.events.size > 0 %}
## Upcoming Events

<div class="card-grid">
{% for event in academic.calendar.events %}
  <article class="card">
    <p class="card-meta">
      <span class="post-meta__badge">{{ event.type | capitalize }}</span>
      <span>{{ event.location }}</span>
    </p>
    <h3>{{ event.name }}</h3>
    <p>{{ event.start_date }}{% if event.end_date != event.start_date %} &ndash; {{ event.end_date }}{% endif %}</p>
    {% if event.submission_deadline %}
      <p class="card-meta">Submission deadline: {{ event.submission_deadline }}</p>
    {% endif %}
  </article>
{% endfor %}
</div>
{% endif %}

{% if academic.funding and academic.funding.size > 0 %}
## Funding

<div class="card-grid">
{% for grant in academic.funding %}
  <article class="card">
    <p class="card-meta">
      <span class="post-meta__badge">{{ grant.status }}</span>
      <span>{{ grant.role }}</span>
    </p>
    <h3>{{ grant.title }}</h3>
    <p>{{ grant.agency }}{% if grant.amount %} &middot; {{ grant.amount }}{% endif %}</p>
    {% if grant.focus %}<p>{{ grant.focus }}</p>{% endif %}
  </article>
{% endfor %}
</div>
{% endif %}

{% if academic.collaboration_opportunities and academic.collaboration_opportunities.size > 0 %}
## Open Collaborations

<div class="card-grid">
{% for opp in academic.collaboration_opportunities %}
  <article class="card">
    {% if opp.tags %}
    <p class="card-meta">
      {% for tag in opp.tags limit: 3 %}
        <span class="post-meta__badge">{{ tag }}</span>
      {% endfor %}
    </p>
    {% endif %}
    <h3>{{ opp.title }}</h3>
    <p>{{ opp.description }}</p>
    {% if opp.contact %}
      <a class="card-link" href="mailto:{{ opp.contact }}">Get in touch</a>
    {% endif %}
  </article>
{% endfor %}
</div>
{% endif %}

{% assign profiles = academic.profiles %}
{% if profiles %}
## Academic Profiles

<div class="research-profiles">
{% if profiles.google_scholar.url and profiles.google_scholar.url != "" %}
  <a href="{{ profiles.google_scholar.url }}" target="_blank" rel="noopener" class="btn btn-secondary">Google Scholar</a>
{% endif %}
{% if profiles.orcid.url %}
  <a href="{{ profiles.orcid.url }}" target="_blank" rel="noopener" class="btn btn-secondary">ORCID</a>
{% endif %}
{% if profiles.researchgate.url %}
  <a href="{{ profiles.researchgate.url }}" target="_blank" rel="noopener" class="btn btn-secondary">ResearchGate</a>
{% endif %}
{% if profiles.academia.url %}
  <a href="{{ profiles.academia.url }}" target="_blank" rel="noopener" class="btn btn-secondary">Academia.edu</a>
{% endif %}
</div>
{% endif %}
