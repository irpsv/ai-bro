(function () {
  "use strict";

  function preferReducedMotion() {
    return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
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
        copyText(text)
          .then(function () {
            setCopiedState(button, true);
          })
          .catch(function () {
            setCopiedState(button, false);
          });
      });
    });
  }

  function initRoleTabs() {
    var tabs = Array.prototype.slice.call(document.querySelectorAll(".role-tab"));
    var panels = {
      vibe: document.getElementById("panel-vibe"),
      dev: document.getElementById("panel-dev")
    };

    if (!tabs.length || !panels.vibe || !panels.dev) return;

    function activate(role) {
      tabs.forEach(function (tab) {
        var on = tab.getAttribute("data-role") === role;
        tab.classList.toggle("is-active", on);
        tab.setAttribute("aria-selected", on ? "true" : "false");
      });

      Object.keys(panels).forEach(function (key) {
        var panel = panels[key];
        var on = key === role;
        panel.classList.toggle("is-active", on);
        if (on) panel.removeAttribute("hidden");
        else panel.setAttribute("hidden", "");
      });
    }

    tabs.forEach(function (tab) {
      tab.addEventListener("click", function () {
        activate(tab.getAttribute("data-role") || "vibe");
      });
    });
  }

  function initDemo() {
    var lines = Array.prototype.slice.call(document.querySelectorAll("#demo-thread .demo-line"));
    if (!lines.length) return;

    if (preferReducedMotion()) {
      lines.forEach(function (line) {
        line.classList.add("is-on");
      });
      return;
    }

    var step = 0;
    var total = lines.length;

    function paint() {
      lines.forEach(function (line, index) {
        line.classList.toggle("is-on", index <= step);
        line.classList.toggle("is-current", index === step);
      });
      step = (step + 1) % total;
    }

    paint();
    window.setInterval(paint, 1600);
  }

  function initStickyCta() {
    var sticky = document.getElementById("sticky-cta");
    var hero = document.getElementById("top");
    var install = document.getElementById("install");
    if (!sticky || !hero || !install) return;
    if (!window.matchMedia("(max-width: 719px)").matches) return;
    if (!("IntersectionObserver" in window)) return;

    var heroVisible = true;
    var installVisible = false;

    function sync() {
      var show = !heroVisible && !installVisible;
      sticky.hidden = !show;
      document.body.classList.toggle("has-sticky-cta", show);
    }

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.target === hero) heroVisible = entry.isIntersecting;
          if (entry.target === install) installVisible = entry.isIntersecting;
        });
        sync();
      },
      { threshold: 0.12 }
    );

    observer.observe(hero);
    observer.observe(install);
  }

  document.addEventListener("DOMContentLoaded", function () {
    initCopyButtons();
    initRoleTabs();
    initDemo();
    initStickyCta();
  });
})();
