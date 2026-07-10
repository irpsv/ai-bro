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

const revealItems = document.querySelectorAll(".reveal");

if ("IntersectionObserver" in window) {
  const revealObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12 },
  );

  revealItems.forEach((item) => revealObserver.observe(item));
} else {
  revealItems.forEach((item) => item.classList.add("visible"));
}
