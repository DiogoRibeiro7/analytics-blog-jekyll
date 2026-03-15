(function () {
  const DEFAULTS = {
    primary: '#2563eb',
    secondary: '#7c3aed',
    accent: '#f97316',
    background: '#ffffff',
    surface: '#f8fafc',
    text: '#0f172a',
    bodyFont: "'Inter', 'Helvetica Neue', Helvetica, Arial, sans-serif",
    headingFont: "'Merriweather', Georgia, 'Times New Roman', serif",
    monoFont: "'Fira Code', 'Source Code Pro', Menlo, Monaco, 'Courier New', monospace",
    baseFontSize: 16,
    spacing: 12,
    radius: 10,
    maxWidth: 980
  };

  const form = document.getElementById('customizer-form');
  const exportButton = document.getElementById('export-scss');
  const darkButton = document.getElementById('generate-dark');
  const savePresetButton = document.getElementById('save-preset');
  const loadPresetButton = document.getElementById('load-preset');
  const deletePresetButton = document.getElementById('delete-preset');
  const presetList = document.getElementById('preset-list');
  const presetNameInput = document.getElementById('preset-name');
  const exportPresetButton = document.getElementById('export-preset');
  const importPresetInput = document.getElementById('import-preset');
  const lightPreview = document.getElementById('light-preview');
  const darkPreview = document.getElementById('dark-preview');
  const template = document.getElementById('scss-template');

  let state = { ...DEFAULTS };
  let darkState = createDarkPalette(state);

  const PRESET_KEY = 'datalog-customizer-presets';

  initForm();
  attachEvents();
  hydratePresetList();
  updatePreview();

  function initForm() {
    Object.entries(DEFAULTS).forEach(([key, value]) => {
      const input = form.elements.namedItem(key);
      if (input) {
        input.value = value;
      }
    });
  }

  function attachEvents() {
    form.addEventListener('input', (event) => {
      const target = event.target;
      if (!target.name) return;
      const value = parseValue(target);
      state = { ...state, [target.name]: value };
      if (['primary', 'secondary', 'accent', 'background', 'surface', 'text'].includes(target.name)) {
        darkState = createDarkPalette(state);
      }
      updatePreview();
    });

    exportButton.addEventListener('click', () => {
      const scss = renderTemplate(template.innerHTML, {
        ...state,
        ...darkState,
        bodyFont: wrapFont(state.bodyFont),
        headingFont: wrapFont(state.headingFont),
        monoFont: wrapFont(state.monoFont)
      });
      downloadText('_custom-variables.scss', scss.trim() + '\n');
    });

    darkButton.addEventListener('click', () => {
      darkState = createDarkPalette(state, { forceRegenerate: true });
      updatePreview();
    });

    savePresetButton.addEventListener('click', () => {
      const name = presetNameInput.value.trim();
      if (!name) {
        alert('Provide a preset name before saving.');
        return;
      }
      const presets = getPresets();
      presets[name] = { ...state };
      setPresets(presets);
      hydratePresetList(name);
    });

    loadPresetButton.addEventListener('click', () => {
      const name = presetList.value;
      if (!name) {
        alert('Select a preset to load.');
        return;
      }
      const presets = getPresets();
      const preset = presets[name];
      if (!preset) return;
      state = { ...preset };
      darkState = createDarkPalette(state);
      syncForm();
      updatePreview();
    });

    deletePresetButton.addEventListener('click', () => {
      const name = presetList.value;
      if (!name) {
        alert('Select a preset to delete.');
        return;
      }
      const presets = getPresets();
      if (presets[name]) {
        delete presets[name];
        setPresets(presets);
        hydratePresetList();
      }
    });

    exportPresetButton.addEventListener('click', () => {
      const name = presetList.value;
      if (!name) {
        alert('Select a preset to export.');
        return;
      }
      const presets = getPresets();
      const preset = presets[name];
      if (!preset) return;
      downloadText(`${slugify(name)}.json`, JSON.stringify({ name, values: preset }, null, 2));
    });

    importPresetInput.addEventListener('change', (event) => {
      const [file] = event.target.files;
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        try {
          const data = JSON.parse(reader.result);
          if (!data || typeof data !== 'object') throw new Error('Invalid preset');
          const name = data.name || file.name.replace(/\.json$/i, '');
          if (!data.values) throw new Error('Missing preset values');
          const presets = getPresets();
          presets[name] = { ...state, ...data.values };
          setPresets(presets);
          hydratePresetList(name);
        } catch (error) {
          console.error(error);
          alert('Unable to import preset. Ensure the JSON schema matches the exported format.');
        } finally {
          importPresetInput.value = '';
        }
      };
      reader.readAsText(file);
    });
  }

  function syncForm() {
    Object.entries(state).forEach(([key, value]) => {
      const input = form.elements.namedItem(key);
      if (!input) return;
      if (input.type === 'range' || input.type === 'number') {
        input.value = Number(value);
      } else {
        input.value = value;
      }
    });
  }

  function parseValue(input) {
    if (input.type === 'number' || input.type === 'range') {
      return Number(input.value);
    }
    return input.value;
  }

  function updatePreview() {
    const spacingPx = `${state.spacing}px`;
    const radiusPx = `${state.radius}px`;
    const maxWidthPx = `${state.maxWidth}px`;

    applyTheme(lightPreview, {
      '--brand-primary': state.primary,
      '--brand-secondary': state.secondary,
      '--brand-accent': state.accent,
      '--surface-color': state.surface,
      '--background-color': state.background,
      '--text-color': state.text,
      '--body-font': state.bodyFont,
      '--heading-font': state.headingFont,
      '--mono-font': state.monoFont,
      '--spacing-unit': spacingPx,
      '--radius-base': radiusPx,
      '--content-width': maxWidthPx,
      '--base-font-size': `${state.baseFontSize}px`
    });

    applyTheme(darkPreview, {
      '--brand-primary': darkState.primary,
      '--brand-secondary': darkState.secondary,
      '--brand-accent': darkState.accent,
      '--surface-color': darkState.surface,
      '--background-color': darkState.background,
      '--text-color': darkState.text,
      '--body-font': state.bodyFont,
      '--heading-font': state.headingFont,
      '--mono-font': state.monoFont,
      '--spacing-unit': spacingPx,
      '--radius-base': radiusPx,
      '--content-width': maxWidthPx,
      '--base-font-size': `${state.baseFontSize}px`
    });
  }

  function applyTheme(element, variables) {
    element.style.setProperty('font-family', "var(--body-font)");
    const style = element.style;
    Object.entries(variables).forEach(([key, value]) => {
      style.setProperty(key, value);
    });

    element.querySelector('header').style.background = `linear-gradient(135deg, var(--brand-primary), var(--brand-secondary))`;
    element.querySelector('header').style.color = 'var(--surface-color)';

    element.style.background = 'var(--background-color)';
    element.style.color = 'var(--text-color)';
    element.style.fontFamily = 'var(--body-font)';
    element.style.fontSize = 'var(--base-font-size)';

    element.querySelectorAll('h3, h4').forEach((heading) => {
      heading.style.fontFamily = 'var(--heading-font)';
    });

    element.querySelectorAll('code, pre').forEach((block) => {
      block.style.background = adjustAlpha(variables['--brand-primary'] || '#000000', 0.12);
      block.style.fontFamily = 'var(--mono-font)';
      block.style.color = 'var(--text-color)';
    });

    element.querySelectorAll('.cta').forEach((cta) => {
      cta.style.background = 'var(--brand-accent)';
      cta.style.color = isLight(variables['--brand-accent']) ? '#0f172a' : '#f8fafc';
      cta.style.borderRadius = '999px';
    });

    element.querySelectorAll('.metric').forEach((card) => {
      card.style.background = adjustAlpha(variables['--brand-primary'] || '#000000', 0.08);
      card.style.borderRadius = 'var(--radius-base)';
      card.style.color = 'var(--text-color)';
    });

    element.querySelector('main').style.gap = 'var(--spacing-unit)';
    element.style.gap = 'calc(var(--spacing-unit) * 1.2)';
    element.style.borderRadius = 'var(--radius-base)';
    element.style.maxWidth = 'var(--content-width)';
  }

  function createDarkPalette(base, options = {}) {
    const background = mix('#000000', base.primary, 0.12);
    const surface = mix('#111827', base.secondary, 0.18);
    const text = getReadableText(background);
    const accent = adjustLightness(base.accent, -0.25);

    if (!options.forceRegenerate && darkState) {
      return {
        ...darkState,
        background,
        surface,
        text,
        accent,
        primary: adjustLightness(base.primary, -0.15),
        secondary: adjustLightness(base.secondary, -0.15)
      };
    }

    return {
      primary: adjustLightness(base.primary, -0.15),
      secondary: adjustLightness(base.secondary, -0.2),
      accent,
      background,
      surface,
      text
    };
  }

  function renderTemplate(raw, replacements) {
    return raw.replace(/{{(\w+)}}/g, (_, key) => {
      return replacements[key] !== undefined ? replacements[key] : '';
    });
  }

  function downloadText(filename, text) {
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  function wrapFont(font) {
    return font.includes(',') ? font : `'${font}'`;
  }

  function hydratePresetList(selected) {
    const presets = getPresets();
    presetList.innerHTML = '';
    Object.keys(presets)
      .sort((a, b) => a.localeCompare(b))
      .forEach((name) => {
        const option = document.createElement('option');
        option.value = name;
        option.textContent = name;
        if (selected && selected === name) {
          option.selected = true;
        }
        presetList.appendChild(option);
      });
  }

  function getPresets() {
    try {
      const stored = localStorage.getItem(PRESET_KEY);
      if (!stored) return {};
      const parsed = JSON.parse(stored);
      if (parsed && typeof parsed === 'object') {
        return parsed;
      }
    } catch (error) {
      console.error('Unable to parse presets', error);
    }
    return {};
  }

  function setPresets(presets) {
    localStorage.setItem(PRESET_KEY, JSON.stringify(presets));
  }

  function slugify(value) {
    return value
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }

  function hexToRgb(hex) {
    const match = hex.replace('#', '').match(/.{1,2}/g);
    if (!match) return { r: 0, g: 0, b: 0 };
    const [r, g, b] = match.map((part) => parseInt(part.length === 1 ? part + part : part, 16));
    return { r, g, b };
  }

  function rgbToHex({ r, g, b }) {
    return `#${[r, g, b]
      .map((value) => {
        const clamped = Math.max(0, Math.min(255, Math.round(value)));
        return clamped.toString(16).padStart(2, '0');
      })
      .join('')}`;
  }

  function mix(colorA, colorB, weight) {
    const a = hexToRgb(colorA);
    const b = hexToRgb(colorB);
    const mixChannel = (channelA, channelB) => channelA * (1 - weight) + channelB * weight;
    return rgbToHex({
      r: mixChannel(a.r, b.r),
      g: mixChannel(a.g, b.g),
      b: mixChannel(a.b, b.b)
    });
  }

  function adjustLightness(hex, factor) {
    const { r, g, b } = hexToRgb(hex);
    const adjust = (channel) => channel + (255 - channel) * factor;
    const adjusted = {
      r: factor >= 0 ? adjust(r) : r * (1 + factor),
      g: factor >= 0 ? adjust(g) : g * (1 + factor),
      b: factor >= 0 ? adjust(b) : b * (1 + factor)
    };
    return rgbToHex(adjusted);
  }

  function adjustAlpha(hex, alpha) {
    const { r, g, b } = hexToRgb(hex || '#000000');
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  function luminance(hex) {
    const { r, g, b } = hexToRgb(hex);
    const transform = (value) => {
      const channel = value / 255;
      return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
    };
    return 0.2126 * transform(r) + 0.7152 * transform(g) + 0.0722 * transform(b);
  }

  function contrast(colorA, colorB) {
    const lumA = luminance(colorA) + 0.05;
    const lumB = luminance(colorB) + 0.05;
    return lumA > lumB ? lumA / lumB : lumB / lumA;
  }

  function getReadableText(background) {
    const whiteContrast = contrast('#ffffff', background);
    const darkContrast = contrast('#0f172a', background);
    return whiteContrast >= darkContrast ? '#ffffff' : '#0f172a';
  }

  function isLight(hex) {
    return luminance(hex) > 0.6;
  }
})();
