/* ============================================================
 * .reports reports.js
 * 共通ユーティリティ: Mermaid 初期化、Prism 設定、ヘルパー
 * ============================================================ */

(function () {
  "use strict";

  // ------------------------------------------------------------
  // Mermaid setup (loads on-demand via CDN ESM)
  // ------------------------------------------------------------
  async function initMermaid() {
    if (!document.querySelector(".mermaid")) return;
    try {
      const { default: mermaid } = await import(
        "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs"
      );
      mermaid.initialize({
        startOnLoad: true,
        theme: "dark",
        themeVariables: {
          background: "#1a2129",
          primaryColor: "#1f2730",
          primaryTextColor: "#e6edf3",
          primaryBorderColor: "#2d3742",
          lineColor: "#8b949e",
          secondaryColor: "#161b22",
          tertiaryColor: "#0f1419",
        },
        flowchart: { curve: "basis" },
        sequence: { actorMargin: 50 },
      });
      mermaid.run();
    } catch (e) {
      console.warn("[reports.js] Mermaid load failed:", e);
    }
  }

  // ------------------------------------------------------------
  // Prism setup (syntax highlighting)
  // ------------------------------------------------------------
  function injectPrism() {
    if (!document.querySelector('pre code[class*="language-"]')) return;
    const css = document.createElement("link");
    css.rel = "stylesheet";
    css.href = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism-tomorrow.css";
    document.head.appendChild(css);

    const core = document.createElement("script");
    core.src = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/components/prism-core.min.js";
    core.onload = () => {
      const autoloader = document.createElement("script");
      autoloader.src = "https://cdn.jsdelivr.net/npm/prismjs@1.29.0/plugins/autoloader/prism-autoloader.min.js";
      document.head.appendChild(autoloader);
    };
    document.head.appendChild(core);
  }

  // ------------------------------------------------------------
  // Tabs (radio-based, CSS-driven)
  // ------------------------------------------------------------
  function showSelectedTabPanel() {
    document.querySelectorAll(".tabs").forEach((tabs) => {
      const radios = tabs.querySelectorAll('input[type="radio"]');
      const panels = tabs.querySelectorAll(".tab-panel");
      const sync = () => {
        radios.forEach((r) => {
          const panel = tabs.querySelector(`.tab-panel[data-tab="${r.value}"]`);
          if (panel) panel.style.display = r.checked ? "block" : "none";
        });
        tabs.querySelectorAll(".tab-labels label").forEach((l) => {
          const targetId = l.getAttribute("for");
          const radio = document.getElementById(targetId);
          l.classList.toggle("active", radio && radio.checked);
        });
      };
      radios.forEach((r) => r.addEventListener("change", sync));
      sync();
    });
  }

  // ------------------------------------------------------------
  // Anchor smooth scroll for in-page links
  // ------------------------------------------------------------
  function smoothScrollAnchors() {
    document.querySelectorAll('a[href^="#"]').forEach((a) => {
      a.addEventListener("click", (e) => {
        const id = a.getAttribute("href").slice(1);
        if (!id) return;
        const el = document.getElementById(id);
        if (!el) return;
        e.preventDefault();
        el.scrollIntoView({ behavior: "smooth", block: "start" });
      });
    });
  }

  // ------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------
  window.Reports = {
    init() {
      initMermaid();
      injectPrism();
      showSelectedTabPanel();
      smoothScrollAnchors();
    },
  };

  document.addEventListener("DOMContentLoaded", () => window.Reports.init());
})();
