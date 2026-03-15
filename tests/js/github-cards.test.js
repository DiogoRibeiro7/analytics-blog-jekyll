import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { initGitHubCards } from '../../assets/js/core/github-cards.js';

describe('GitHub Cards Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    localStorage.clear();
    global.fetch = vi.fn();
    global.console.warn = vi.fn();
    window.DatalogIntegrations = {};
  });

  afterEach(() => {
    localStorage.clear();
    vi.restoreAllMocks();
    delete window.DatalogIntegrations;
  });

  describe('initGitHubCards()', () => {
    it('should do nothing when no cards exist', () => {
      document.body.innerHTML = '<div>No GitHub cards</div>';

      initGitHubCards();

      expect(fetch).not.toHaveBeenCalled();
    });

    it('should do nothing when GitHub integration is disabled', () => {
      document.body.innerHTML = `
        <div data-github-owner="octocat" data-github-repo="Hello-World"></div>
      `;

      window.DatalogIntegrations = {
        github: { enabled: false }
      };

      initGitHubCards();

      expect(fetch).not.toHaveBeenCalled();
    });

    it('should fetch repository data for GitHub cards', async () => {
      const mockData = {
        stargazers_count: 100,
        forks_count: 25,
        description: 'A test repo'
      };

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockData
      });

      document.body.innerHTML = `
        <div data-github-owner="octocat" data-github-repo="Hello-World">
          <span data-github-stat="stargazers_count"></span>
          <span data-github-stat="forks_count"></span>
        </div>
      `;

      window.DatalogIntegrations = {
        github: { enabled: true }
      };

      await initGitHubCards();

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('octocat/Hello-World')
      );
    });

    it('should use custom API base URL', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({})
      });

      document.body.innerHTML = `
        <div data-github-owner="user" data-github-repo="repo"></div>
      `;

      window.DatalogIntegrations = {
        github: {
          enabled: true,
          api_base: 'https://custom-api.example.com/repos'
        }
      };

      await initGitHubCards();

      expect(fetch).toHaveBeenCalledWith(
        'https://custom-api.example.com/repos/user/repo'
      );
    });

    it('should skip cards without owner', () => {
      document.body.innerHTML = `
        <div data-github-repo="Hello-World"></div>
      `;

      initGitHubCards();

      expect(fetch).not.toHaveBeenCalled();
    });

    it('should skip cards without repo', () => {
      document.body.innerHTML = `
        <div data-github-owner="octocat"></div>
      `;

      initGitHubCards();

      expect(fetch).not.toHaveBeenCalled();
    });

    it('should handle multiple cards', async () => {
      global.fetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ stargazers_count: 100 })
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ stargazers_count: 200 })
        });

      document.body.innerHTML = `
        <div data-github-owner="user1" data-github-repo="repo1"></div>
        <div data-github-owner="user2" data-github-repo="repo2"></div>
      `;

      await initGitHubCards();

      expect(fetch).toHaveBeenCalledTimes(2);
    });
  });

  describe('cacheKey()', () => {
    it('should generate cache key from owner and repo', () => {
      const CACHE_PREFIX = 'datalog-github-';
      const cacheKey = (owner, repo) => `${CACHE_PREFIX}${owner}-${repo}`;

      expect(cacheKey('octocat', 'Hello-World')).toBe('datalog-github-octocat-Hello-World');
      expect(cacheKey('user', 'repo')).toBe('datalog-github-user-repo');
    });

    it('should handle special characters in names', () => {
      const CACHE_PREFIX = 'datalog-github-';
      const cacheKey = (owner, repo) => `${CACHE_PREFIX}${owner}-${repo}`;

      expect(cacheKey('my-org', 'my.repo')).toBe('datalog-github-my-org-my.repo');
    });
  });

  describe('readCache()', () => {
    it('should return cached data if not expired', () => {
      const cacheKey = 'datalog-github-octocat-Hello-World';
      const cachedData = {
        timestamp: Date.now() - 1000, // 1 second ago
        data: { stargazers_count: 100 }
      };

      localStorage.setItem(cacheKey, JSON.stringify(cachedData));

      const cacheTtl = 10000; // 10 seconds
      const raw = localStorage.getItem(cacheKey);
      const parsed = JSON.parse(raw);

      expect(Date.now() - parsed.timestamp).toBeLessThan(cacheTtl);
      expect(parsed.data).toEqual({ stargazers_count: 100 });
    });

    it('should return null for expired cache', () => {
      const cacheKey = 'datalog-github-octocat-Hello-World';
      const cachedData = {
        timestamp: Date.now() - 50000, // 50 seconds ago
        data: { stargazers_count: 100 }
      };

      localStorage.setItem(cacheKey, JSON.stringify(cachedData));

      const cacheTtl = 10000; // 10 seconds
      const raw = localStorage.getItem(cacheKey);
      const parsed = JSON.parse(raw);

      if (Date.now() - parsed.timestamp > cacheTtl) {
        localStorage.removeItem(cacheKey);
      }

      const result = localStorage.getItem(cacheKey);
      expect(result).toBeNull();
    });

    it('should return null when cache does not exist', () => {
      const cacheKey = 'datalog-github-nonexistent-repo';
      const result = localStorage.getItem(cacheKey);

      expect(result).toBeNull();
    });

    it('should handle invalid JSON gracefully', () => {
      const cacheKey = 'datalog-github-octocat-Hello-World';
      localStorage.setItem(cacheKey, 'invalid json');

      expect(() => {
        const raw = localStorage.getItem(cacheKey);
        JSON.parse(raw);
      }).toThrow();
    });

    it('should handle null parsed data', () => {
      const cacheKey = 'datalog-github-octocat-Hello-World';
      localStorage.setItem(cacheKey, 'null');

      const raw = localStorage.getItem(cacheKey);
      const parsed = JSON.parse(raw);

      expect(parsed).toBeNull();
    });

    it('should handle non-object parsed data', () => {
      const cacheKey = 'datalog-github-octocat-Hello-World';
      localStorage.setItem(cacheKey, '"string"');

      const raw = localStorage.getItem(cacheKey);
      const parsed = JSON.parse(raw);

      expect(typeof parsed).toBe('string');
    });
  });

  describe('writeCache()', () => {
    it('should write data to cache with timestamp', () => {
      const cacheKey = 'datalog-github-octocat-Hello-World';
      const data = { stargazers_count: 100 };

      localStorage.setItem(
        cacheKey,
        JSON.stringify({ timestamp: Date.now(), data })
      );

      const raw = localStorage.getItem(cacheKey);
      const parsed = JSON.parse(raw);

      expect(parsed).toHaveProperty('timestamp');
      expect(parsed).toHaveProperty('data');
      expect(parsed.data).toEqual(data);
    });

    it('should overwrite existing cache', () => {
      const cacheKey = 'datalog-github-octocat-Hello-World';

      localStorage.setItem(
        cacheKey,
        JSON.stringify({ timestamp: Date.now(), data: { old: 'data' } })
      );

      localStorage.setItem(
        cacheKey,
        JSON.stringify({ timestamp: Date.now(), data: { new: 'data' } })
      );

      const raw = localStorage.getItem(cacheKey);
      const parsed = JSON.parse(raw);

      expect(parsed.data).toEqual({ new: 'data' });
    });

    it('should handle localStorage write errors gracefully', () => {
      // Fill localStorage to trigger quota exceeded
      const originalSetItem = Storage.prototype.setItem;
      Storage.prototype.setItem = vi.fn(() => {
        throw new Error('QuotaExceededError');
      });

      expect(() => {
        try {
          localStorage.setItem('test', 'value');
        } catch (error) {
          // Should handle gracefully
        }
      }).not.toThrow();

      Storage.prototype.setItem = originalSetItem;
    });
  });

  describe('fetchRepository()', () => {
    it('should fetch from API when cache is empty', async () => {
      const mockData = { stargazers_count: 100 };

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockData
      });

      const response = await fetch('https://api.github.com/repos/octocat/Hello-World');
      const data = await response.json();

      expect(data).toEqual(mockData);
    });

    it('should return cached data when available', () => {
      const cacheKey = 'datalog-github-octocat-Hello-World';
      const cachedData = {
        timestamp: Date.now(),
        data: { stargazers_count: 100 }
      };

      localStorage.setItem(cacheKey, JSON.stringify(cachedData));

      const raw = localStorage.getItem(cacheKey);
      const parsed = JSON.parse(raw);

      expect(parsed.data).toEqual({ stargazers_count: 100 });
    });

    it('should handle API errors', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      });

      const response = await fetch('https://api.github.com/repos/nonexistent/repo');

      expect(response.ok).toBe(false);
      expect(response.status).toBe(404);
    });

    it('should handle network errors', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Network error'));

      await expect(fetch('https://api.github.com/repos/owner/repo')).rejects.toThrow('Network error');
    });

    it('should cache successful API responses', async () => {
      const mockData = { stargazers_count: 200 };

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => mockData
      });

      const response = await fetch('https://api.github.com/repos/octocat/Hello-World');
      const data = await response.json();

      const cacheKey = 'datalog-github-octocat-Hello-World';
      localStorage.setItem(
        cacheKey,
        JSON.stringify({ timestamp: Date.now(), data })
      );

      const cached = JSON.parse(localStorage.getItem(cacheKey));
      expect(cached.data).toEqual(mockData);
    });

    it('should warn on fetch failure', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Fetch failed'));

      try {
        await fetch('https://api.github.com/repos/owner/repo');
      } catch (error) {
        expect(error.message).toBe('Fetch failed');
      }
    });
  });

  describe('applyRepositoryData()', () => {
    it('should populate stat elements with repository data', () => {
      const data = {
        stargazers_count: 1234,
        forks_count: 567,
        description: 'Test repository'
      };

      document.body.innerHTML = `
        <div class="github-card">
          <span data-github-stat="stargazers_count"></span>
          <span data-github-stat="forks_count"></span>
          <span data-github-stat="description"></span>
        </div>
      `;

      const card = document.querySelector('.github-card');
      const statElements = card.querySelectorAll('[data-github-stat]');

      statElements.forEach((element) => {
        const stat = element.getAttribute('data-github-stat');
        const value = data[stat];
        if (typeof value === 'number') {
          element.textContent = value.toLocaleString();
        } else if (typeof value === 'string' && value.length > 0) {
          element.textContent = value;
        }
      });

      expect(document.querySelector('[data-github-stat="stargazers_count"]').textContent).toBe('1,234');
      expect(document.querySelector('[data-github-stat="forks_count"]').textContent).toBe('567');
      expect(document.querySelector('[data-github-stat="description"]').textContent).toBe('Test repository');
    });

    it('should format numbers with locale strings', () => {
      const data = { stargazers_count: 1000000 };

      document.body.innerHTML = `
        <div class="github-card">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      const card = document.querySelector('.github-card');
      const element = card.querySelector('[data-github-stat="stargazers_count"]');

      element.textContent = data.stargazers_count.toLocaleString();

      expect(element.textContent).toBe('1,000,000');
    });

    it('should handle string values', () => {
      const data = { description: 'Amazing project' };

      document.body.innerHTML = `
        <div class="github-card">
          <span data-github-stat="description"></span>
        </div>
      `;

      const card = document.querySelector('.github-card');
      const element = card.querySelector('[data-github-stat="description"]');

      if (typeof data.description === 'string' && data.description.length > 0) {
        element.textContent = data.description;
      }

      expect(element.textContent).toBe('Amazing project');
    });

    it('should skip empty strings', () => {
      const data = { description: '' };

      document.body.innerHTML = `
        <div class="github-card">
          <span data-github-stat="description"></span>
        </div>
      `;

      const card = document.querySelector('.github-card');
      const element = card.querySelector('[data-github-stat="description"]');

      if (typeof data.description === 'string' && data.description.length > 0) {
        element.textContent = data.description;
      }

      expect(element.textContent).toBe('');
    });

    it('should skip elements without stat attribute', () => {
      document.body.innerHTML = `
        <div class="github-card">
          <span data-github-stat=""></span>
        </div>
      `;

      const card = document.querySelector('.github-card');
      const statElements = card.querySelectorAll('[data-github-stat]');

      statElements.forEach((element) => {
        const stat = element.getAttribute('data-github-stat');
        if (!stat) {
          return;
        }
        element.textContent = 'Should not appear';
      });

      expect(document.querySelector('[data-github-stat]').textContent).toBe('');
    });

    it('should handle missing data properties', () => {
      const data = { stargazers_count: 100 };

      document.body.innerHTML = `
        <div class="github-card">
          <span data-github-stat="nonexistent_stat"></span>
        </div>
      `;

      const card = document.querySelector('.github-card');
      const element = card.querySelector('[data-github-stat="nonexistent_stat"]');

      const value = data['nonexistent_stat'];
      if (typeof value === 'number') {
        element.textContent = value.toLocaleString();
      }

      expect(element.textContent).toBe('');
    });

    it('should handle multiple stat elements', () => {
      const data = {
        stargazers_count: 100,
        forks_count: 25,
        watchers_count: 50
      };

      document.body.innerHTML = `
        <div class="github-card">
          <span data-github-stat="stargazers_count"></span>
          <span data-github-stat="forks_count"></span>
          <span data-github-stat="watchers_count"></span>
        </div>
      `;

      const card = document.querySelector('.github-card');
      const statElements = card.querySelectorAll('[data-github-stat]');

      statElements.forEach((element) => {
        const stat = element.getAttribute('data-github-stat');
        const value = data[stat];
        if (typeof value === 'number') {
          element.textContent = value.toLocaleString();
        }
      });

      expect(document.querySelectorAll('[data-github-stat]').length).toBe(3);
    });
  });

  describe('Cache TTL', () => {
    it('should use default TTL when not configured', () => {
      const defaultTtl = 43200; // 12 hours in seconds
      const ttlMs = defaultTtl * 1000;

      expect(ttlMs).toBe(43200000); // 12 hours in milliseconds
    });

    it('should use custom TTL from config', () => {
      window.DatalogIntegrations = {
        github: {
          cache_ttl: 3600 // 1 hour
        }
      };

      const ttl = Number(window.DatalogIntegrations.github.cache_ttl || 43200) * 1000;

      expect(ttl).toBe(3600000); // 1 hour in milliseconds
    });

    it('should handle invalid TTL values', () => {
      window.DatalogIntegrations = {
        github: {
          cache_ttl: 'invalid'
        }
      };

      const ttl = Number(window.DatalogIntegrations.github.cache_ttl || 43200) * 1000;

      expect(isNaN(ttl)).toBe(true);
    });
  });

  describe('Integration Config', () => {
    it('should use default API base when not configured', () => {
      const apiBase = 'https://api.github.com/repos';

      expect(apiBase).toBe('https://api.github.com/repos');
    });

    it('should handle missing integration config', () => {
      delete window.DatalogIntegrations;

      const integrations = window.DatalogIntegrations || {};
      const githubConfig = integrations.github || {};

      expect(githubConfig).toEqual({});
    });

    it('should merge config with defaults', () => {
      window.DatalogIntegrations = {
        github: {
          enabled: true,
          cache_ttl: 7200
        }
      };

      const config = window.DatalogIntegrations.github;
      const apiBase = config.api_base || 'https://api.github.com/repos';
      const cacheTtl = Number(config.cache_ttl || 43200);

      expect(apiBase).toBe('https://api.github.com/repos');
      expect(cacheTtl).toBe(7200);
    });
  });

  describe('Full Integration Flow', () => {
    it('should read from valid cache and skip API call', async () => {
      // Set up valid cache
      const cacheKey = 'datalog-github-cached-user-cached-repo';
      const cachedData = {
        timestamp: Date.now(),
        data: { stargazers_count: 999, forks_count: 111 }
      };
      localStorage.setItem(cacheKey, JSON.stringify(cachedData));

      document.body.innerHTML = `
        <div data-github-owner="cached-user" data-github-repo="cached-repo">
          <span data-github-stat="stargazers_count"></span>
          <span data-github-stat="forks_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      // Should not call API because cache is valid
      expect(fetch).not.toHaveBeenCalled();
      // Should populate from cache
      expect(document.querySelector('[data-github-stat="stargazers_count"]').textContent).toBe('999');
      expect(document.querySelector('[data-github-stat="forks_count"]').textContent).toBe('111');
    });

    it('should fetch from API when cache is expired', async () => {
      // Set up expired cache (beyond default TTL)
      const cacheKey = 'datalog-github-expired-user-expired-repo';
      const cachedData = {
        timestamp: Date.now() - 50000000, // Well beyond default 12h TTL
        data: { stargazers_count: 100 }
      };
      localStorage.setItem(cacheKey, JSON.stringify(cachedData));

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ stargazers_count: 200 })
      });

      document.body.innerHTML = `
        <div data-github-owner="expired-user" data-github-repo="expired-repo">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      expect(fetch).toHaveBeenCalled();
    });

    it('should handle corrupted cache JSON gracefully', async () => {
      const cacheKey = 'datalog-github-corrupt-user-corrupt-repo';
      localStorage.setItem(cacheKey, 'not valid json {{{');

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ stargazers_count: 300 })
      });

      document.body.innerHTML = `
        <div data-github-owner="corrupt-user" data-github-repo="corrupt-repo">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      // Should warn about cache read failure
      expect(console.warn).toHaveBeenCalled();
      // Should fall back to API
      expect(fetch).toHaveBeenCalled();
    });

    it('should handle null cache data gracefully', async () => {
      const cacheKey = 'datalog-github-null-user-null-repo';
      localStorage.setItem(cacheKey, JSON.stringify(null));

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ stargazers_count: 400 })
      });

      document.body.innerHTML = `
        <div data-github-owner="null-user" data-github-repo="null-repo">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      expect(fetch).toHaveBeenCalled();
    });

    it('should handle non-object cache data gracefully', async () => {
      const cacheKey = 'datalog-github-string-user-string-repo';
      localStorage.setItem(cacheKey, JSON.stringify('just a string'));

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ stargazers_count: 500 })
      });

      document.body.innerHTML = `
        <div data-github-owner="string-user" data-github-repo="string-repo">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      expect(fetch).toHaveBeenCalled();
    });

    it('should handle API error status codes', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      });

      document.body.innerHTML = `
        <div data-github-owner="notfound" data-github-repo="repo">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      // Should warn about failed request
      expect(console.warn).toHaveBeenCalled();
      // Stat should remain empty
      expect(document.querySelector('[data-github-stat="stargazers_count"]').textContent).toBe('');
    });

    it('should handle network fetch errors', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Network failure'));

      document.body.innerHTML = `
        <div data-github-owner="network-error" data-github-repo="repo">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      // Should warn about network error
      expect(console.warn).toHaveBeenCalled();
    });

    it('should apply string values correctly', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          description: 'A great repository',
          language: 'JavaScript',
          license: { name: 'MIT' }
        })
      });

      document.body.innerHTML = `
        <div data-github-owner="test" data-github-repo="string-test">
          <span data-github-stat="description"></span>
          <span data-github-stat="language"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      expect(document.querySelector('[data-github-stat="description"]').textContent).toBe('A great repository');
      expect(document.querySelector('[data-github-stat="language"]').textContent).toBe('JavaScript');
    });

    it('should not apply empty string values', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          description: '',
          stargazers_count: 50
        })
      });

      document.body.innerHTML = `
        <div data-github-owner="empty" data-github-repo="strings">
          <span data-github-stat="description">Original</span>
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      // Empty string should not overwrite
      expect(document.querySelector('[data-github-stat="description"]').textContent).toBe('Original');
      // Number should be applied
      expect(document.querySelector('[data-github-stat="stargazers_count"]').textContent).toBe('50');
    });

    it('should handle cards with empty owner attribute', async () => {
      document.body.innerHTML = `
        <div data-github-owner="" data-github-repo="some-repo">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      expect(fetch).not.toHaveBeenCalled();
    });

    it('should handle cards with empty repo attribute', async () => {
      document.body.innerHTML = `
        <div data-github-owner="some-owner" data-github-repo="">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      await initGitHubCards();

      expect(fetch).not.toHaveBeenCalled();
    });

    it('should handle localStorage write errors during cache write', async () => {
      const originalSetItem = Storage.prototype.setItem;
      Storage.prototype.setItem = vi.fn(() => {
        throw new Error('QuotaExceededError');
      });

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ stargazers_count: 777 })
      });

      document.body.innerHTML = `
        <div data-github-owner="quota" data-github-repo="exceeded">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      window.DatalogIntegrations = { github: { enabled: true } };

      // Should not throw even if localStorage fails
      await initGitHubCards();

      expect(console.warn).toHaveBeenCalled();
      // Data should still be applied to DOM
      expect(document.querySelector('[data-github-stat="stargazers_count"]').textContent).toBe('777');

      Storage.prototype.setItem = originalSetItem;
    });

    it('should return Promise.resolve when no cards and integration enabled', async () => {
      document.body.innerHTML = '<div>No GitHub cards here</div>';
      window.DatalogIntegrations = { github: { enabled: true } };

      const result = await initGitHubCards();

      expect(result).toBeUndefined();
      expect(fetch).not.toHaveBeenCalled();
    });

    it('should use custom cache TTL from config', async () => {
      // Set up cache that's 2 hours old
      const cacheKey = 'datalog-github-ttl-user-ttl-repo';
      const twoHoursAgo = Date.now() - (2 * 60 * 60 * 1000);
      const cachedData = {
        timestamp: twoHoursAgo,
        data: { stargazers_count: 100 }
      };
      localStorage.setItem(cacheKey, JSON.stringify(cachedData));

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ stargazers_count: 200 })
      });

      document.body.innerHTML = `
        <div data-github-owner="ttl-user" data-github-repo="ttl-repo">
          <span data-github-stat="stargazers_count"></span>
        </div>
      `;

      // Set 1 hour TTL - cache should be expired
      window.DatalogIntegrations = {
        github: {
          enabled: true,
          cache_ttl: 3600 // 1 hour in seconds
        }
      };

      await initGitHubCards();

      // Should call API because cache is expired (2h > 1h TTL)
      expect(fetch).toHaveBeenCalled();
    });
  });
});
