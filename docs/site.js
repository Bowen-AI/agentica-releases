/* Agentica landing page — OS detection, copy buttons, live download counter, screenshot lightbox. */
(function () {
  "use strict";
  var REPO = "Bowen-AI/agentica-releases";

  /* ---------- OS detection + platform tabs ---------- */
  function detectOS() {
    var d = (navigator.userAgentData && navigator.userAgentData.platform) || "";
    var s = (d + " " + (navigator.platform || "") + " " + (navigator.userAgent || ""));
    if (/Mac|iPhone|iPad|iPod/i.test(s)) return "mac";
    if (/Win/i.test(s)) return "win";
    return "linux"; // Linux, Android, ChromeOS, unknown
  }

  function selectOS(os) {
    var tabs = document.querySelectorAll(".os-tab");
    var panels = document.querySelectorAll(".os-panel");
    for (var i = 0; i < tabs.length; i++) {
      var on = tabs[i].getAttribute("data-os") === os;
      tabs[i].classList.toggle("active", on);
      tabs[i].setAttribute("aria-selected", on ? "true" : "false");
    }
    for (var j = 0; j < panels.length; j++) {
      panels[j].hidden = panels[j].getAttribute("data-os") !== os;
    }
  }

  var tabEls = document.querySelectorAll(".os-tab");
  for (var t = 0; t < tabEls.length; t++) {
    (function (el) {
      el.addEventListener("click", function () { selectOS(el.getAttribute("data-os")); });
    })(tabEls[t]);
  }
  if (tabEls.length) selectOS(detectOS());

  /* ---------- copy buttons ---------- */
  function copyText(text, btn) {
    var done = function () {
      var old = btn.textContent;
      btn.textContent = "Copied!";
      btn.classList.add("done");
      setTimeout(function () { btn.textContent = old; btn.classList.remove("done"); }, 1500);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () { fallback(text); done(); });
    } else { fallback(text); done(); }
  }
  function fallback(text) {
    var ta = document.createElement("textarea");
    ta.value = text; ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta); ta.focus(); ta.select();
    try { document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(ta);
  }
  var copyEls = document.querySelectorAll(".copy");
  for (var c = 0; c < copyEls.length; c++) {
    (function (btn) {
      btn.addEventListener("click", function () {
        var code = btn.parentElement.querySelector("code");
        if (code) copyText(code.textContent, btn);
      });
    })(copyEls[c]);
  }

  /* ---------- live download counter + version ----------
     Download counter: real-time from Vercel KV (incremented by /api/dl redirects).
     Version: from GitHub's public API (cached to avoid rate limits).
     Stale-while-revalidate: show cached values instantly, refetch in background. */
  var numEl = document.getElementById("dlnum");
  var boxEl = document.getElementById("dlcount");
  var verEls = document.querySelectorAll(".app-version");
  var fallbackVersion = verEls.length ? verEls[0].textContent.trim() : "";
  var shown = 0;

  function versionParts(tag) {
    var m = String(tag || "").trim().match(/^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/);
    return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
  }
  function isAtLeast(tag, floor) {
    var a = versionParts(tag), b = versionParts(floor);
    if (!a || !b) return true;
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return true;
  }

  function animate(from, to) {
    if (!numEl) return;
    var dur = 800, start = null;
    function tick(ts) {
      if (start === null) start = ts;
      var k = Math.min(1, (ts - start) / dur);
      var v = Math.round(from + (to - from) * (1 - Math.pow(1 - k, 3)));
      numEl.textContent = v.toLocaleString();
      if (k < 1) requestAnimationFrame(tick); else numEl.textContent = to.toLocaleString();
    }
    requestAnimationFrame(tick);
  }
  function setCount(n) {
    if (!boxEl || !numEl || !n || n === shown) return;
    boxEl.hidden = false;
    animate(shown, n);
    shown = n;
  }
  function setVersion(tag) {
    if (!tag) return;
    for (var i = 0; i < verEls.length; i++) { verEls[i].textContent = tag; verEls[i].hidden = false; }
  }

  // Disable any download button whose file isn't in the latest release (e.g. the Intel
  // mac .dmg before a CI build exists), so a click never 404s. Self-heals once it ships.
  function gateDownloads(rel) {
    if (!rel || !rel.assets) return;
    var have = {};
    for (var i = 0; i < rel.assets.length; i++) have[rel.assets[i].name] = true;
    var links = document.querySelectorAll('.dlrow a[data-asset]');
    for (var j = 0; j < links.length; j++) {
      var a = links[j];
      var name = a.getAttribute("data-asset");
      if (have[name]) continue;
      a.classList.add("dl-soon");
      a.setAttribute("aria-disabled", "true");
      a.setAttribute("title", "Coming with the next build");
      a.removeAttribute("href");
      if (!a.querySelector(".soontag")) {
        var s = document.createElement("span"); s.className = "soontag"; s.textContent = " · soon"; a.appendChild(s);
      }
      a.addEventListener("click", function (e) { e.preventDefault(); });
    }
  }

  function loadReleases() {
    try {
      var c = JSON.parse(localStorage.getItem("agx_dl") || "null");
      if (c) { if (c.n) setCount(c.n); if (c.v && isAtLeast(c.v, fallbackVersion)) setVersion(c.v); }
    } catch (e) {}
    // Real-time count from Vercel KV (instant, no rate limits)
    if (location.hostname !== "bowen-ai.github.io") fetch("/api/downloads", { cache: "no-store" })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) { if (d && d.count) setCount(d.count); })
      .catch(function () { /* offline: keep cached value */ });
    // Version from GitHub (cached to avoid rate limits)
    fetch("https://api.github.com/repos/" + REPO + "/releases?per_page=100", {
      headers: { Accept: "application/vnd.github+json" }, cache: "no-store"
    }).then(function (r) { return r.ok ? r.json() : null; }).then(function (rels) {
      if (!rels || !rels.length) return;
      var latest = null, latestRel = null;
      for (var i = 0; i < rels.length; i++) { if (!rels[i].draft && !rels[i].prerelease) { latest = rels[i].tag_name; latestRel = rels[i]; break; } }
      try { localStorage.setItem("agx_dl", JSON.stringify({ v: latest, t: Date.now() })); } catch (e) {}
      if (isAtLeast(latest, fallbackVersion)) setVersion(latest);
      gateDownloads(latestRel);
    }).catch(function () { /* offline: keep cached value */ });
  }
  loadReleases();

  /* ---------- screenshot lightbox (full-size, scrollable) ---------- */
  var lb = document.getElementById("lightbox");
  var lbImg = document.getElementById("lbImg");
  var lbClose = document.getElementById("lbClose");
  var prevOverflow = "";
  function openLb(src, alt) {
    if (!lb || !lbImg) return;
    lbImg.src = src; lbImg.alt = alt || "";
    lb.hidden = false;
    prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
  }
  function closeLb() {
    if (!lb) return;
    lb.hidden = true; lbImg.src = "";
    document.body.style.overflow = prevOverflow;
  }
  var zoomEls = document.querySelectorAll("img.zoomable");
  for (var z = 0; z < zoomEls.length; z++) {
    (function (img) {
      img.addEventListener("click", function () { openLb(img.currentSrc || img.src, img.alt); });
    })(zoomEls[z]);
  }
  if (lbClose) lbClose.addEventListener("click", closeLb);
  if (lb) lb.addEventListener("click", function (e) { if (e.target === lb || e.target.classList.contains("lb-scroll")) closeLb(); });
  document.addEventListener("keydown", function (e) { if (e.key === "Escape" && lb && !lb.hidden) closeLb(); });
})();
