(function () {
  var REPO = "Bowen-AI/agentica-releases";
  var LATEST = "https://github.com/" + REPO + "/releases/latest/download/";
  var API = "https://api.github.com/repos/" + REPO + "/releases/latest";
  var INSTALL =
    "curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh | bash";

  var CATALOG = [
    { key: "mac-arm64-dmg", file: "Agentica-mac-arm64.dmg", label: "macOS Apple Silicon · DMG", os: "mac", arch: "arm64", primaryExt: "dmg" },
    { key: "mac-arm64-zip", file: "Agentica-mac-arm64.zip", label: "macOS Apple Silicon · ZIP", os: "mac", arch: "arm64", primaryExt: "zip" },
    { key: "mac-x64-dmg", file: "Agentica-mac-x64.dmg", label: "macOS Intel · DMG", os: "mac", arch: "x64", primaryExt: "dmg" },
    { key: "mac-x64-zip", file: "Agentica-mac-x64.zip", label: "macOS Intel · ZIP", os: "mac", arch: "x64", primaryExt: "zip" },
    { key: "linux-x64-appimage", file: "Agentica-linux-x64.AppImage", label: "Linux x64 · AppImage", os: "linux", arch: "x64", primaryExt: "AppImage" },
    { key: "linux-x64-tar", file: "Agentica-linux-x64.tar.gz", label: "Linux x64 · tar.gz", os: "linux", arch: "x64", primaryExt: "tar.gz" },
    { key: "linux-arm64-tar", file: "Agentica-linux-arm64.tar.gz", label: "Linux arm64 · tar.gz", os: "linux", arch: "arm64", primaryExt: "tar.gz" },
  ];

  function byFile(file) {
    for (var i = 0; i < CATALOG.length; i++) if (CATALOG[i].file === file) return CATALOG[i];
    return null;
  }

  function detect() {
    var ua = navigator.userAgent || "";
    var platform = navigator.platform || "";
    var uaData = navigator.userAgentData || null;
    var os = "unknown";
    var arch = "unknown";
    var archConfident = false;

    var platformHint = ((uaData && uaData.platform) || platform || "").toLowerCase();
    var uaLower = ua.toLowerCase();

    if (/mac|darwin|iphone|ipad/.test(platformHint) || /mac os x|macintosh/.test(uaLower)) os = "mac";
    else if (/linux|cros/.test(platformHint) || /linux|cros/.test(uaLower) || /microsoft|wsl/i.test(ua)) os = "linux";
    else if (/win/.test(platformHint) || /windows/.test(uaLower)) os = "win";

    function applyArch(value, confident) {
      if (!value) return;
      var v = String(value).toLowerCase();
      if (v === "arm" || v === "arm64" || v === "aarch64") {
        arch = "arm64";
        archConfident = !!confident;
      } else if (v === "x86" || v === "x64" || v === "x86_64" || v === "amd64") {
        arch = "x64";
        archConfident = !!confident;
      }
    }

    if (uaData && typeof uaData.getHighEntropyValues === "function") {
      uaData
        .getHighEntropyValues(["architecture", "bitness", "platform"])
        .then(function (vals) {
          if (vals.platform) {
            var p = String(vals.platform).toLowerCase();
            if (/mac/.test(p)) os = "mac";
            else if (/linux/.test(p)) os = "linux";
            else if (/win/.test(p)) os = "win";
          }
          applyArch(vals.architecture, true);
          paint(os, arch, archConfident, window.__agenticaPublished || {});
        })
        .catch(function () {});
    }

    if (/aarch64|arm64|apple silicon/.test(uaLower)) applyArch("arm64", true);
    else if (/intel mac/.test(uaLower)) applyArch("x64", true);
    else if ((os === "linux" || os === "win") && /x86_64|amd64|wow64|win64/.test(uaLower)) applyArch("x64", false);

    if (os === "mac" && arch === "unknown") {
      arch = "arm64";
      archConfident = false;
    }
    if (os === "linux" && arch === "unknown") {
      arch = "x64";
      archConfident = false;
    }
    return { os: os, arch: arch, archConfident: archConfident };
  }

  function publishedHas(published, file) {
    return !!(published && published[file]);
  }

  function btn(href, label, primary, disabled) {
    if (disabled) {
      var span = document.createElement("span");
      span.className = "btn disabled";
      span.textContent = label;
      span.setAttribute("aria-disabled", "true");
      return span;
    }
    var a = document.createElement("a");
    a.className = "btn" + (primary ? " primary" : "");
    a.href = href;
    a.rel = "noopener";
    a.textContent = label;
    return a;
  }

  function liLink(href, label, missing) {
    var li = document.createElement("li");
    if (missing) {
      li.innerHTML = "<span class='soon'>" + label + " — not in latest release</span>";
      return li;
    }
    var a = document.createElement("a");
    a.href = href;
    a.rel = "noopener";
    a.textContent = label;
    li.appendChild(a);
    return li;
  }

  function primaryCandidates(os, arch) {
    if (os === "mac" && arch === "x64") {
      return ["Agentica-mac-x64.dmg", "Agentica-mac-arm64.dmg", "Agentica-mac-x64.zip", "Agentica-mac-arm64.zip"];
    }
    if (os === "mac") {
      return ["Agentica-mac-arm64.dmg", "Agentica-mac-arm64.zip"];
    }
    if (os === "linux" && arch === "arm64") {
      return ["Agentica-linux-arm64.tar.gz", "Agentica-linux-x64.AppImage", "Agentica-linux-x64.tar.gz"];
    }
    if (os === "linux") {
      return ["Agentica-linux-x64.AppImage", "Agentica-linux-x64.tar.gz"];
    }
    return ["Agentica-mac-arm64.dmg"];
  }

  function secondaryFor(os, arch, primaryFile) {
    var out = [];
    CATALOG.forEach(function (item) {
      if (item.file === primaryFile) return;
      // Prefer other formats for same OS first, then other platforms.
      var sameOs = item.os === os || (os === "win" && item.os === "linux");
      out.push({ item: item, rank: sameOs ? 0 : 1 });
    });
    out.sort(function (a, b) { return a.rank - b.rank; });
    return out.map(function (x) { return x.item; });
  }

  function paint(os, arch, archConfident, published) {
    var label = document.getElementById("detect-label");
    var primary = document.getElementById("primary-cta");
    var altList = document.getElementById("alt-list");
    var platformList = document.getElementById("platform-list");
    if (!label || !primary || !altList) return;

    primary.innerHTML = "";
    altList.innerHTML = "";
    if (platformList) platformList.innerHTML = "";

    var osName = os === "mac" ? "macOS" : os === "linux" ? "Linux" : os === "win" ? "Windows" : "your system";
    var archName = "";
    if (os === "mac") archName = arch === "x64" ? "Intel" : "Apple Silicon";
    else if (arch === "arm64") archName = "arm64";
    else if (arch === "x64") archName = "x64";

    label.textContent =
      "Suggested for " +
      osName +
      (archName ? " · " + archName : "") +
      (!archConfident && os === "mac" ? " (defaulting to Apple Silicon)" : "");

    if (os === "win") {
      primary.appendChild(
        btn("#install", "Use WSL — run the one-liner below", true, false)
      );
      // Smooth-scroll install; keep as in-page link only.
      primary.querySelector("a").addEventListener("click", function (e) {
        e.preventDefault();
        var el = document.getElementById("install");
        if (el) el.scrollIntoView({ behavior: "smooth" });
      });
    }

    var chosen = null;
    var candidates = primaryCandidates(os, arch);
    for (var i = 0; i < candidates.length; i++) {
      if (publishedHas(published, candidates[i])) {
        chosen = candidates[i];
        break;
      }
    }

    if (os !== "win") {
      if (chosen) {
        var meta = byFile(chosen);
        var nice =
          os === "mac"
            ? "Download " + (arch === "x64" && chosen.indexOf("x64") >= 0 ? "macOS Intel" : "macOS Apple Silicon") +
              (chosen.slice(-4) === ".dmg" ? " DMG" : " ZIP")
            : "Download " + (meta ? meta.label : chosen);
        primary.appendChild(btn(LATEST + chosen, nice, true, false));

        // Secondary format for same platform if present.
        if (os === "mac" && chosen.indexOf(".dmg") >= 0 && publishedHas(published, chosen.replace(".dmg", ".zip"))) {
          primary.appendChild(btn(LATEST + chosen.replace(".dmg", ".zip"), "ZIP", false, false));
        }
        if (os === "linux" && chosen.indexOf("AppImage") >= 0 && publishedHas(published, "Agentica-linux-x64.tar.gz")) {
          primary.appendChild(btn(LATEST + "Agentica-linux-x64.tar.gz", "tar.gz", false, false));
        }
      } else {
        var missingLabel =
          os === "mac"
            ? "macOS build not in latest release yet"
            : "Linux build not in latest release yet";
        primary.appendChild(btn("#", missingLabel, true, true));
        primary.appendChild(btn("#install", "Use install one-liner", false, false));
        var installBtn = primary.querySelector('a[href="#install"]');
        if (installBtn) {
          installBtn.addEventListener("click", function (e) {
            e.preventDefault();
            var el = document.getElementById("install");
            if (el) el.scrollIntoView({ behavior: "smooth" });
          });
        }
      }
    }

    secondaryFor(os, arch, chosen).forEach(function (item) {
      // Keep hero alt list short: skip duplicate zip if already in primary CTA.
      if (chosen && item.file === chosen.replace(".dmg", ".zip")) return;
      if (chosen && item.file === "Agentica-linux-x64.tar.gz" && String(chosen).indexOf("AppImage") >= 0) return;
      altList.appendChild(
        liLink(LATEST + item.file, item.label, !publishedHas(published, item.file))
      );
    });

    if (platformList) {
      CATALOG.forEach(function (item) {
        platformList.appendChild(
          liLink(LATEST + item.file, item.label, !publishedHas(published, item.file))
        );
      });
    }
  }

  function loadPublished() {
    return fetch(API, { headers: { Accept: "application/vnd.github+json" } })
      .then(function (r) {
        if (!r.ok) throw new Error("api " + r.status);
        return r.json();
      })
      .then(function (data) {
        var map = {};
        (data.assets || []).forEach(function (a) {
          if (a && a.name) map[a.name] = true;
        });
        window.__agenticaPublished = map;
        return map;
      })
      .catch(function () {
        // Safe fallback: only advertise mac arm64 which we know ships on v0.3.0.
        var map = {
          "Agentica-mac-arm64.dmg": true,
          "Agentica-mac-arm64.zip": true,
        };
        window.__agenticaPublished = map;
        return map;
      });
  }

  function wireCopy() {
    var oneliner = document.getElementById("oneliner");
    var btnEl = document.getElementById("copy-btn");
    var status = document.getElementById("copy-status");
    if (oneliner) oneliner.textContent = INSTALL;
    if (!btnEl || !oneliner) return;
    btnEl.addEventListener("click", function () {
      var text = oneliner.textContent || INSTALL;
      function ok() {
        btnEl.textContent = "Copied";
        btnEl.classList.add("copied");
        if (status) {
          status.hidden = false;
          status.textContent = "Copied.";
        }
        setTimeout(function () {
          btnEl.textContent = "Copy";
          btnEl.classList.remove("copied");
          if (status) status.hidden = true;
        }, 1600);
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(ok).catch(function () {
          fallbackCopy(text, ok);
        });
      } else {
        fallbackCopy(text, ok);
      }
    });
  }

  function fallbackCopy(text, ok) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.select();
    try {
      document.execCommand("copy");
      ok();
    } catch (e) {
      var status = document.getElementById("copy-status");
      if (status) {
        status.hidden = false;
        status.textContent = "Select the command and copy manually.";
      }
    }
    document.body.removeChild(ta);
  }

  var d = detect();
  wireCopy();
  loadPublished().then(function (published) {
    paint(d.os, d.arch, d.archConfident, published);
  });
  // Optimistic first paint with empty map → disabled until API returns,
  // unless fallback already set.
  paint(d.os, d.arch, d.archConfident, window.__agenticaPublished || {});
})();
