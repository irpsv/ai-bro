const copyButtons = document.querySelectorAll("[data-copy]");

copyButtons.forEach((button) => {
  button.addEventListener("click", async () => {
    const label = button.querySelector(".copy-label");
    const originalLabel = label.textContent;

    try {
      await navigator.clipboard.writeText(button.dataset.copy);
      label.textContent = "Скопировано";
      button.classList.add("copied");
    } catch {
      label.textContent = "Выделите текст";
    }

    window.setTimeout(() => {
      label.textContent = originalLabel;
      button.classList.remove("copied");
    }, 1800);
  });
});
