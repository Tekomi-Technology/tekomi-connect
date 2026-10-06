import '../dashboard/assets/scss/super_admin/index.scss';

const initializeAccountSuspensionForm = () => {
  const form = document.querySelector('[data-account-suspension-form]');
  if (!form) return;

  const status = form.querySelector('[data-account-status-select]');
  const fields = form.querySelector('[data-account-suspension-fields]');
  if (!status || !fields) return;

  const category = fields.querySelector('[data-suspension-category]');
  const reason = fields.querySelector('[data-suspension-reason]');
  const controls = [category, reason];
  const originalStatus = form.dataset.originalStatus;
  const hasHistory = form.dataset.hasSuspensionHistory === 'true';

  const updateFields = () => {
    const isSuspended = status.value === 'suspended';
    const hasEnteredDetails = controls.some(
      control => control.value.trim().length > 0
    );
    const detailsRequired =
      isSuspended &&
      (originalStatus === 'active' || hasHistory || hasEnteredDetails);

    fields.classList.toggle('hidden', !isSuspended);
    controls.forEach(control => {
      control.disabled = !isSuspended;
      control.required = detailsRequired;
    });
  };

  status.addEventListener('change', updateFields);
  controls.forEach(control => control.addEventListener('input', updateFields));
  updateFields();
};

document.addEventListener('DOMContentLoaded', initializeAccountSuspensionForm);

const HEX_COLOR = /^#[0-9A-F]{6}$/i;

const relativeLuminance = hex =>
  hex
    .slice(1)
    .match(/../g)
    .map(channel => {
      const value = parseInt(channel, 16) / 255;
      return value <= 0.03928
        ? value / 12.92
        : ((value + 0.055) / 1.055) ** 2.4;
    })
    .reduce(
      (sum, value, index) => sum + value * [0.2126, 0.7152, 0.0722][index],
      0
    );

const contrastRatio = (first, second) => {
  const [light, dark] = [
    relativeLuminance(first),
    relativeLuminance(second),
  ].sort((a, b) => b - a);
  return (light + 0.05) / (dark + 0.05);
};

// The color a ColorField resolves to: its own value, or the default the dashboard uses when blank.
const effectiveColor = input => {
  const value = input.value.trim().toUpperCase();
  return HEX_COLOR.test(value)
    ? value
    : input.closest('[data-color-field]').dataset.defaultColor;
};

const initializeColorFields = () => {
  const fields = [...document.querySelectorAll('[data-color-field]')];
  if (!fields.length) return;

  const setValue = (input, value) => {
    input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
  };

  const syncField = field => {
    const input = field.querySelector('[data-color-input]');
    const color = effectiveColor(input);
    field.querySelectorAll('[data-color-swatch]').forEach(swatch => {
      swatch.setAttribute(
        'aria-pressed',
        String(swatch.dataset.colorSwatch === input.value.trim().toUpperCase())
      );
    });
    if (color)
      field.querySelector('[data-color-picker]').value = color.toLowerCase();

    if (!field.dataset.contrastWith) return;
    const background = effectiveColor(
      document.getElementById(field.dataset.contrastWith)
    );
    const ratio = contrastRatio(color, background);
    const verdict = ratio >= 4.5 ? 'ok' : 'low';
    field.querySelectorAll('[data-color-contrast]').forEach(message => {
      message.classList.toggle(
        'hidden',
        message.dataset.colorContrast !== verdict
      );
      message.textContent = message.dataset.message.replace(
        '%{ratio}',
        ratio.toFixed(1)
      );
    });
  };

  const syncPreview = () => {
    const preview = document.querySelector('[data-sidebar-preview]');
    if (!preview) return;
    const value = key => document.getElementById(preview.dataset[key]);
    preview.style.setProperty(
      '--preview-primary',
      effectiveColor(value('primaryInput'))
    );
    preview.style.setProperty('--preview-bg', effectiveColor(value('bgInput')));
    preview.style.setProperty(
      '--preview-text',
      effectiveColor(value('textInput'))
    );
    preview.querySelector('[data-preview-name]').textContent =
      value('nameInput').value;
    preview.querySelector('[data-preview-tagline]').textContent =
      value('taglineInput').value;
  };

  const syncAll = () => {
    fields.forEach(syncField);
    syncPreview();
  };

  fields.forEach(field => {
    const input = field.querySelector('[data-color-input]');
    field.querySelectorAll('[data-color-swatch]').forEach(swatch => {
      swatch.addEventListener('click', () =>
        setValue(input, swatch.dataset.colorSwatch)
      );
    });
    field
      .querySelector('[data-color-picker]')
      .addEventListener('input', event => {
        setValue(input, event.target.value.toUpperCase());
      });
    field
      .querySelector('[data-color-reset]')
      ?.addEventListener('click', () => setValue(input, ''));
    field.querySelector('[data-color-auto]')?.addEventListener('click', () => {
      const background = effectiveColor(
        document.getElementById(field.dataset.contrastWith)
      );
      setValue(
        input,
        relativeLuminance(background) > 0.4 ? '#0F172A' : '#FFFFFF'
      );
    });
  });

  document.addEventListener('input', syncAll);
  syncAll();
};

document.addEventListener('DOMContentLoaded', initializeColorFields);
