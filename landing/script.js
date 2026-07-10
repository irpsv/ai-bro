const copyButtons = document.querySelectorAll("[data-copy]");

copyButtons.forEach((button) => {
  const label = button.querySelector(".copy-label");
  const originalLabel = label.textContent;
  let resetTimeout;

  button.addEventListener("click", async () => {
    window.clearTimeout(resetTimeout);

    try {
      await navigator.clipboard.writeText(button.dataset.copy);
      label.textContent = "Скопировано";
      button.classList.add("copied");
    } catch {
      label.textContent = "Выделите текст";
    }

    resetTimeout = window.setTimeout(() => {
      label.textContent = originalLabel;
      button.classList.remove("copied");
    }, 1800);
  });
});
