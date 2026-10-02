document.querySelectorAll('[data-tenant-example]').forEach((example) => {
  if (example.dataset.ready) return;
  example.dataset.ready = 'true';

  const copy = example.querySelector('[data-copy-tenant]');
  const status = example.querySelector('[data-copy-status]');
  if (navigator.clipboard) {
    copy.hidden = false;
    copy.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(example.querySelector('[data-tenant-source]').textContent);
        copy.textContent = 'Copied';
        status.textContent = 'Complete Tenant YAML copied.';
      } catch {
        status.textContent = 'Copy failed. Use Download YAML to save the complete Tenant.';
      }
    });
  }

  // The card is a separate element. Its title is the native, keyboard-accessible
  // link; clicks elsewhere on the surface follow the same destination.
  const openRule = (event) => {
    if (event.defaultPrevented || event.button > 1 || event.target.closest('a, button, summary')) return;
    const rule = event.target.closest('[data-tenant-rule]');
    if (!rule) return;

    const selection = window.getSelection();
    if (selection && !selection.isCollapsed) {
      for (let index = 0; index < selection.rangeCount; index++) {
        if (selection.getRangeAt(index).intersectsNode(rule)) return;
      }
    }

    const link = rule.querySelector('.tenant-rule__link');
    if (event.button === 1 || event.ctrlKey || event.metaKey || event.shiftKey) {
      event.preventDefault();
      window.open(link.href, '_blank', 'noopener');
    } else {
      link.click();
    }
  };
  example.addEventListener('click', openRule);
  example.addEventListener('auxclick', openRule);
});
