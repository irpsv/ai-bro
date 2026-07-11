(function () {
  "use strict";

  var HERO_VARIANTS = {
    A: "Меньше хаоса с AI-агентом — больше понятного результата",
    B: "От идеи до рабочего кода — с AI-агентом по понятному сценарию"
  };

  var STORAGE_KEY = "aibro_hero_variant";
  var events = [];

  function track(name, props) {
    var payload = Object.assign(
      {
        event: name,
        ts: Date.now(),
        path: location.pathname
      },
      props || {}
    );

    events.push(payload);
    window.__aibroEvents = events;
    window.dataLayer = window.dataLayer || [];
    window.dataLayer.push(payload);

    try {
      window.dispatchEvent(new CustomEvent("aibro:analytics", { detail: payload }));
    } catch (err) {
      /* ignore */
    }

    if (window.plausible && typeof window.plausible === "function") {
      try {
        window.plausible(name, { props: props || {} });
      } catch (err) {
        /* ignore */
      }
    }
  }

  function preferReducedMotion() {
    return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function initReveal() {
    var nodes = document.querySelectorAll(".reveal");
    if (!nodes.length) return;

    if (!("IntersectionObserver" in window) || preferReducedMotion()) {
      nodes.forEach(function (el) {
        el.classList.add("is-visible");
      });
      return;
    }

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.14, rootMargin: "0px 0px -6% 0px" }
    );

    nodes.forEach(function (el) {
      observer.observe(el);
    });
  }

  function pickHeroVariant() {
    var saved = null;
    try {
      saved = localStorage.getItem(STORAGE_KEY);
    } catch (err) {
      saved = null;
    }

    if (saved !== "A" && saved !== "B") {
      saved = Math.random() < 0.5 ? "A" : "B";
      try {
        localStorage.setItem(STORAGE_KEY, saved);
      } catch (err) {
        /* ignore */
      }
    }

    var title = document.getElementById("hero-title");
    if (title) {
      title.textContent = HERO_VARIANTS[saved];
      title.setAttribute("data-ab-variant", saved);
    }

    document.title =
      saved === "B"
        ? "ai-bro — от идеи до кода по понятному сценарию"
        : "ai-bro — меньше хаоса с AI-агентом, больше результата";

    track("hero_variant", { variant: saved });
    return saved;
  }

  function setCopiedState(button, ok) {
    var original = button.getAttribute("data-label") || button.textContent;
    button.setAttribute("data-label", original);
    button.textContent = ok ? "Скопировано" : "Не удалось";
    button.classList.toggle("is-copied", ok);
    button.classList.toggle("is-error", !ok);
    window.setTimeout(function () {
      button.textContent = button.getAttribute("data-label") || "Скопировать";
      button.classList.remove("is-copied", "is-error");
    }, 1600);
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }

    return new Promise(function (resolve, reject) {
      var area = document.createElement("textarea");
      area.value = text;
      area.setAttribute("readonly", "");
      area.style.position = "fixed";
      area.style.opacity = "0";
      document.body.appendChild(area);
      area.select();
      try {
        var ok = document.execCommand("copy");
        document.body.removeChild(area);
        if (ok) resolve();
        else reject(new Error("copy failed"));
      } catch (err) {
        document.body.removeChild(area);
        reject(err);
      }
    });
  }

  function initCopyButtons() {
    document.querySelectorAll("[data-copy]").forEach(function (button) {
      button.addEventListener("click", function () {
        var text = button.getAttribute("data-copy") || "";
        var trackName = button.getAttribute("data-track") || "copy_install";
        copyText(text)
          .then(function () {
            setCopiedState(button, true);
            track(trackName, { ok: true, length: text.length });
          })
          .catch(function () {
            setCopiedState(button, false);
            track(trackName, { ok: false });
          });
      });
    });
  }

  function initClickTracking() {
    document.querySelectorAll("[data-track]").forEach(function (el) {
      if (el.hasAttribute("data-copy")) return;
      el.addEventListener("click", function () {
        track(el.getAttribute("data-track") || "click", {
          href: el.getAttribute("href") || null
        });
      });
    });
  }

  function initFaqTracking() {
    document.querySelectorAll("details[data-track-details]").forEach(function (el) {
      el.addEventListener("toggle", function () {
        if (!el.open) return;
        track(el.getAttribute("data-track-details") || "faq_open");
      });
    });
  }

  function initViewTracking() {
    var nodes = document.querySelectorAll("[data-track-view]");
    if (!nodes.length || !("IntersectionObserver" in window)) return;

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var name = entry.target.getAttribute("data-track-view");
          if (!name) return;
          track(name);
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.45 }
    );

    nodes.forEach(function (el) {
      observer.observe(el);
    });
  }

  function formatCount(n) {
    if (n >= 1000) {
      return (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, "") + "k";
    }
    return String(n);
  }

  function initStars() {
    var target = document.getElementById("star-count");
    if (!target) return;

    fetch("https://api.github.com/repos/irpsv/ai-bro", {
      headers: { Accept: "application/vnd.github+json" }
    })
      .then(function (res) {
        if (!res.ok) throw new Error("github api " + res.status);
        return res.json();
      })
      .then(function (data) {
        var stars = Number(data.stargazers_count) || 0;
        target.textContent = "★ " + formatCount(stars);
        track("github_stars_loaded", { stars: stars });
      })
      .catch(function () {
        target.textContent = "★ GitHub";
        track("github_stars_failed");
      });
  }

  document.addEventListener("DOMContentLoaded", function () {
    pickHeroVariant();
    initReveal();
    initCopyButtons();
    initClickTracking();
    initFaqTracking();
    initViewTracking();
    initStars();
    track("page_view");
  });
})();
