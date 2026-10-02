// Preserve text selection when a drag ends inside a linked rule block.
document.addEventListener('click', (event) => {
  const link = event.target.closest('.linked-yaml__rule');
  if (!link || event.detail === 0) return;

  const selection = window.getSelection();
  if (!selection || selection.isCollapsed) return;

  for (let index = 0; index < selection.rangeCount; index++) {
    if (selection.getRangeAt(index).intersectsNode(link)) {
      event.preventDefault();
      return;
    }
  }
});
