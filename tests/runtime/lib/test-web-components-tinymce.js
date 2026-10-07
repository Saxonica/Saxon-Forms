(() => {
  const script = document.createElement("script");
  // TEST-TRACE: load TinyMCE webcomponent from local test-app assets to keep TinyMCE tests offline-stable; helps tests/supplemental/web-components.spec.ts "Web components integration (tinymce)".
  script.src = "/lib/tinymce-webcomponent.js";
  script.defer = true;
  document.head.appendChild(script);
})();
