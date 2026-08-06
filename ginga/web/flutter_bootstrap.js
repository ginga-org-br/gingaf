{{flutter_js}}
{{flutter_build_config}}

(function () {
  let scriptUrl = '';
  if (document.currentScript && document.currentScript.src) {
    scriptUrl = document.currentScript.src.substring(0, document.currentScript.src.lastIndexOf('/') + 1);
  }

  const targetElement = document.getElementById('ginga-container') || document.body;

  window.GingaApp = window.GingaApp || {};
  window.GingaApp.mountTarget = window.GingaApp.mountTarget || targetElement;
  window.GingaApp.appPath = window.GingaApp.appPath || null;
  window.GingaApp.files = window.GingaApp.files || {};

  window.GingaApp.mount = function (element) {
    window.GingaApp.mountTarget = typeof element === 'string' ? document.querySelector(element) : element;
  };

  window.GingaApp.play = function (appPath, files) {
    if (appPath) window.GingaApp.appPath = appPath;
    if (files) window.GingaApp.files = files;
  };

  window.GingaApp.stop = function () {
    window.GingaApp.appPath = null;
    window.GingaApp.files = {};
  };

  function getTargetElement() {
    return window.GingaApp.mountTarget || document.getElementById('ginga-container') || document.body;
  }

  _flutter.loader.load({
    config: {
      assetBase: scriptUrl,
    },
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
      const target = getTargetElement();
      const appRunner = await engineInitializer.initializeEngine({
        hostElement: target,
        assetBase: scriptUrl,
      });

      await appRunner.runApp();
    }
  });
})();
