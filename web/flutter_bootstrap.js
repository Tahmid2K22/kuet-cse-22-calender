{{flutter_js}}
{{flutter_build_config}}

// Load CanvasKit from this deployment instead of Google's CDN, so the
// Content-Security-Policy can forbid third-party script execution.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
