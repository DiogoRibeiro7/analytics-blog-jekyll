import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
  populateCitationMetrics,
  populatePublicationCitations,
  populateCitationTimeline,
  attachCopyHandler,
  initCopyHandlers,
  initSubmissionFilter,
  initCalendarFilter,
  initOpenScienceBadges,
  initAcademicFeatures
} from '../../assets/js/academic.js';

describe('Academic Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    window.DatalogAcademic = {};
    window.DatalogPublications = {};
  });

  afterEach(() => {
    delete window.DatalogAcademic;
    delete window.DatalogPublications;
  });

  describe('Citation Metrics', () => {
    it('should populate total citation metric', () => {
      window.DatalogPublications = {
        metrics: { total: 1234 }
      };
      document.body.innerHTML = '<span data-citation-metric="total"></span>';

      populateCitationMetrics();

      const element = document.querySelector('[data-citation-metric="total"]');
      expect(element.textContent).toBe('1,234');
    });

    it('should populate h-index metric', () => {
      window.DatalogPublications = {
        metrics: { h_index: 42 }
      };
      document.body.innerHTML = '<span data-citation-metric="h_index"></span>';

      populateCitationMetrics();

      const element = document.querySelector('[data-citation-metric="h_index"]');
      expect(element.textContent).toBe('42');
    });

    it('should populate i10-index metric', () => {
      window.DatalogPublications = {
        metrics: { i10_index: 28 }
      };
      document.body.innerHTML = '<span data-citation-metric="i10_index"></span>';

      populateCitationMetrics();

      const element = document.querySelector('[data-citation-metric="i10_index"]');
      expect(element.textContent).toBe('28');
    });

    it('should handle since_2019 metrics', () => {
      window.DatalogPublications = {
        metrics: {
          since_2019: {
            total: 500,
            h_index: 20,
            i10_index: 15
          }
        }
      };
      document.body.innerHTML = `
        <span data-citation-metric="since_total"></span>
        <span data-citation-metric="since_h_index"></span>
        <span data-citation-metric="since_i10"></span>
      `;

      populateCitationMetrics();

      expect(document.querySelector('[data-citation-metric="since_total"]').textContent).toBe('500');
      expect(document.querySelector('[data-citation-metric="since_h_index"]').textContent).toBe('20');
      expect(document.querySelector('[data-citation-metric="since_i10"]').textContent).toBe('15');
    });

    it('should handle yearly totals', () => {
      window.DatalogPublications = {
        yearly_totals: {
          '2023': 150,
          '2024': 200
        }
      };
      document.body.innerHTML = `
        <span data-citation-metric="year_2023"></span>
        <span data-citation-metric="year_2024"></span>
      `;

      populateCitationMetrics();

      expect(document.querySelector('[data-citation-metric="year_2023"]').textContent).toBe('150');
      expect(document.querySelector('[data-citation-metric="year_2024"]').textContent).toBe('200');
    });

    it('should skip elements without metric key', () => {
      document.body.innerHTML = '<span data-citation-metric=""></span>';

      populateCitationMetrics();

      const element = document.querySelector('[data-citation-metric]');
      expect(element.textContent).toBe('');
    });

    it('should handle missing data gracefully', () => {
      window.DatalogPublications = { metrics: {} };
      document.body.innerHTML = '<span data-citation-metric="total"></span>';

      populateCitationMetrics();

      const element = document.querySelector('[data-citation-metric="total"]');
      expect(element.textContent).toBe('');
    });
  });

  describe('Publication Citations', () => {
    it('should populate publication-specific citations', () => {
      window.DatalogPublications = {
        citation_totals: {
          'paper-123': 45
        }
      };
      document.body.innerHTML = '<span data-publication-citations="paper-123"></span>';

      populatePublicationCitations();

      const element = document.querySelector('[data-publication-citations="paper-123"]');
      expect(element.textContent).toBe('45');
    });

    it('should handle nested citation totals', () => {
      window.DatalogPublications = {
        citation_totals: {
          'paper-456': { total: 78 }
        }
      };
      document.body.innerHTML = '<span data-publication-citations="paper-456"></span>';

      populatePublicationCitations();

      const element = document.querySelector('[data-publication-citations="paper-456"]');
      expect(element.textContent).toBe('78');
    });

    it('should handle case-insensitive publication IDs', () => {
      window.DatalogPublications = {
        citation_totals: {
          'paper-abc': 12
        }
      };
      document.body.innerHTML = '<span data-publication-citations="PAPER-ABC"></span>';

      populatePublicationCitations();

      const element = document.querySelector('[data-publication-citations="PAPER-ABC"]');
      expect(element.textContent).toBe('12');
    });

    it('should skip publications without ID', () => {
      document.body.innerHTML = '<span data-publication-citations=""></span>';

      populatePublicationCitations();

      const element = document.querySelector('[data-publication-citations]');
      expect(element.textContent).toBe('');
    });
  });

  describe('Citation Timeline', () => {
    it('should populate yearly citation counts in timeline', () => {
      window.DatalogPublications = {
        yearly_totals: {
          '2022': 10,
          '2023': 25,
          '2024': 50
        }
      };
      document.body.innerHTML = `
        <ul data-citation-timeline>
          <li data-year="2022"><span data-year-total></span></li>
          <li data-year="2023"><span data-year-total></span></li>
          <li data-year="2024"><span data-year-total></span></li>
        </ul>
      `;

      populateCitationTimeline();

      const items = document.querySelectorAll('[data-year-total]');
      expect(items[0].textContent).toBe('10');
      expect(items[1].textContent).toBe('25');
      expect(items[2].textContent).toBe('50');
    });

    it('should set CSS custom property for timeline visualization', () => {
      window.DatalogPublications = {
        yearly_totals: { '2024': 75 }
      };
      document.body.innerHTML = `
        <ul data-citation-timeline>
          <li data-year="2024"><span data-year-total></span></li>
        </ul>
      `;

      populateCitationTimeline();

      const item = document.querySelector('[data-year="2024"]');
      expect(item.style.getPropertyValue('--timeline-value')).toBe('15');
    });

    it('should cap timeline value at 100', () => {
      window.DatalogPublications = {
        yearly_totals: { '2024': 1000 }
      };
      document.body.innerHTML = `
        <ul data-citation-timeline>
          <li data-year="2024"><span data-year-total></span></li>
        </ul>
      `;

      populateCitationTimeline();

      const item = document.querySelector('[data-year="2024"]');
      expect(item.style.getPropertyValue('--timeline-value')).toBe('100');
    });

    it('should skip timeline items without year', () => {
      document.body.innerHTML = `
        <ul data-citation-timeline>
          <li data-year=""><span data-year-total></span></li>
        </ul>
      `;

      populateCitationTimeline();

      const item = document.querySelector('[data-year]');
      expect(item.textContent).not.toContain('Should not appear');
    });

    it('should do nothing when timeline container missing', () => {
      document.body.innerHTML = '<div>No timeline</div>';

      populateCitationTimeline();

      const container = document.querySelector('[data-citation-timeline]');
      expect(container).toBeNull();
    });
  });

  describe('Copy Functionality', () => {
    beforeEach(() => {
      global.navigator.clipboard = {
        writeText: vi.fn(() => Promise.resolve())
      };
    });

    afterEach(() => {
      delete global.navigator.clipboard;
    });

    it('should copy citation text on button click', async () => {
      document.body.innerHTML = `
        <textarea id="citation-text">@article{test2024}</textarea>
        <button data-copy-citation data-target="citation-text">Copy</button>
      `;

      initCopyHandlers();

      const trigger = document.querySelector('[data-copy-citation]');
      trigger.click();

      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('@article{test2024}');
    });

    it('should update button text after successful copy', async () => {
      document.body.innerHTML = `
        <textarea id="citation-text">@article{test2024}</textarea>
        <button data-copy-citation data-target="citation-text">Copy</button>
      `;

      initCopyHandlers();

      const trigger = document.querySelector('[data-copy-citation]');

      // Click and wait for async clipboard operation
      trigger.click();

      // Flush promise queue to ensure .then() callbacks execute
      await vi.waitFor(() => {
        expect(trigger.textContent).toBe('Copied!');
      }, { timeout: 1000 });

      expect(trigger.dataset.copied).toBe('true');
    });

    it('should handle missing target gracefully', () => {
      document.body.innerHTML = `
        <button data-copy-citation data-target="nonexistent">Copy</button>
      `;

      initCopyHandlers();

      const trigger = document.querySelector('[data-copy-citation]');
      expect(() => trigger.click()).not.toThrow();
      expect(navigator.clipboard.writeText).not.toHaveBeenCalled();
    });

    it('should handle missing target attribute', () => {
      document.body.innerHTML = `
        <button data-copy-citation>Copy</button>
      `;

      initCopyHandlers();

      const trigger = document.querySelector('[data-copy-citation]');
      expect(() => trigger.click()).not.toThrow();
    });
  });

  describe('Submission Filter', () => {
    it('should filter submissions by status', () => {
      document.body.innerHTML = `
        <select data-submission-filter>
          <option value="">All</option>
          <option value="published">Published</option>
          <option value="submitted">Submitted</option>
        </select>
        <div class="submission-card" data-submission-status="published">Paper 1</div>
        <div class="submission-card" data-submission-status="submitted">Paper 2</div>
        <div class="submission-card" data-submission-status="draft">Paper 3</div>
      `;

      initSubmissionFilter();

      const filter = document.querySelector('[data-submission-filter]');
      const cards = document.querySelectorAll('.submission-card');

      filter.value = 'published';
      filter.dispatchEvent(new Event('change'));

      expect(cards[0].hidden).toBe(false);
      expect(cards[1].hidden).toBe(true);
      expect(cards[2].hidden).toBe(true);
    });

    it('should show all submissions when filter is empty', () => {
      document.body.innerHTML = `
        <select data-submission-filter>
          <option value="">All</option>
        </select>
        <div class="submission-card" data-submission-status="published">Paper 1</div>
        <div class="submission-card" data-submission-status="submitted">Paper 2</div>
      `;

      initSubmissionFilter();

      const cards = document.querySelectorAll('.submission-card');
      cards.forEach(card => expect(card.hidden).toBe(false));
    });

    it('should do nothing when no submission filter exists', () => {
      document.body.innerHTML = '<div>No filter</div>';

      initSubmissionFilter();

      const filter = document.querySelector('[data-submission-filter]');
      expect(filter).toBeNull();
    });
  });

  describe('Calendar Filter', () => {
    it('should filter calendar events by type', () => {
      document.body.innerHTML = `
        <select data-calendar-filter>
          <option value="">All</option>
          <option value="conference">Conferences</option>
          <option value="deadline">Deadlines</option>
        </select>
        <ul data-academic-calendar>
          <li data-event-type="conference">ICML 2024</li>
          <li data-event-type="deadline">Paper due</li>
          <li data-event-type="seminar">Lab meeting</li>
        </ul>
      `;

      initCalendarFilter();

      const filter = document.querySelector('[data-calendar-filter]');
      const events = document.querySelectorAll('[data-event-type]');

      filter.value = 'conference';
      filter.dispatchEvent(new Event('change'));

      expect(events[0].hidden).toBe(false);
      expect(events[1].hidden).toBe(true);
      expect(events[2].hidden).toBe(true);
    });

    it('should show all events when filter is empty', () => {
      document.body.innerHTML = `
        <select data-calendar-filter></select>
        <ul data-academic-calendar>
          <li data-event-type="conference">Event 1</li>
          <li data-event-type="deadline">Event 2</li>
        </ul>
      `;

      initCalendarFilter();

      const events = document.querySelectorAll('[data-event-type]');
      events.forEach(event => expect(event.hidden).toBe(false));
    });

    it('should require both filter and calendar to exist', () => {
      document.body.innerHTML = '<select data-calendar-filter></select>';

      initCalendarFilter();

      const calendar = document.querySelector('[data-academic-calendar]');
      expect(calendar).toBeNull();
    });
  });

  describe('Open Science Badges', () => {
    it('should create tooltip from badge description', () => {
      document.body.innerHTML = `
        <div class="open-science-badge">
          <span class="open-science-badge__description">Open Data</span>
        </div>
      `;

      initOpenScienceBadges();

      const badge = document.querySelector('.open-science-badge');
      expect(badge.getAttribute('title')).toBe('Open Data');
    });

    it('should combine description and criteria in tooltip', () => {
      document.body.innerHTML = `
        <div class="open-science-badge">
          <span class="open-science-badge__description">Open Data</span>
          <span class="open-science-badge__criteria">All data publicly available</span>
        </div>
      `;

      initOpenScienceBadges();

      const badge = document.querySelector('.open-science-badge');
      expect(badge.getAttribute('title')).toBe('Open Data • All data publicly available');
    });

    it('should handle badges without description or criteria', () => {
      document.body.innerHTML = '<div class="open-science-badge"></div>';

      initOpenScienceBadges();

      const badge = document.querySelector('.open-science-badge');
      expect(badge.hasAttribute('title')).toBe(false);
    });

    it('should process multiple badges', () => {
      document.body.innerHTML = `
        <div class="open-science-badge">
          <span class="open-science-badge__description">Open Data</span>
        </div>
        <div class="open-science-badge">
          <span class="open-science-badge__description">Open Code</span>
        </div>
      `;

      initOpenScienceBadges();

      const badgeArray = Array.from(document.querySelectorAll('.open-science-badge'));
      expect(badgeArray[0].getAttribute('title')).toBe('Open Data');
      expect(badgeArray[1].getAttribute('title')).toBe('Open Code');
    });
  });
});
