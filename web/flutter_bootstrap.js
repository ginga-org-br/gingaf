{{flutter_js}}
{{flutter_build_config}}

(function () {
  let scriptUrl = '';
  if (document.currentScript && document.currentScript.src) {
    scriptUrl = document.currentScript.src.substring(0, document.currentScript.src.lastIndexOf('/') + 1);
  } else {
    const scripts = document.getElementsByTagName('script');
    for (let i = 0; i < scripts.length; i++) {
      const src = scripts[i].src;
      if (src && (src.includes('flutter_bootstrap.js') || src.includes('flutter.js'))) {
        scriptUrl = src.substring(0, src.lastIndexOf('/') + 1);
        break;
      }
    }
  }

  const targetElement = document.getElementById('ginga-container');

  window.Ginga = window.Ginga || {};
  window.Ginga.mountTarget = window.Ginga.mountTarget || targetElement;
  window.Ginga.app = window.Ginga.app || null;

  window.Ginga.mount = function (element) {
    window.Ginga.mountTarget = typeof element === 'string' ? document.querySelector(element) : element;
  };

  window.Ginga.play = function (app) {
    if (app) {
      window.Ginga.app = app;
      try {
        sessionStorage.setItem('GINGA_APP', app);
      } catch (_) {}
    }
  };

  window.Ginga.stop = function () {
    window.Ginga.app = null;
    try {
      sessionStorage.removeItem('GINGA_APP');
    } catch (_) {}
  };

  window.GingaApp = window.Ginga;

  function getTargetElement() {
    let target = window.Ginga && window.Ginga.mountTarget;
    if (typeof target === 'string') {
      target = document.querySelector(target);
    }
    if (!target) {
      target = document.getElementById('ginga-container');
    }
    if (target && target instanceof HTMLElement && target !== document.body) {
      return target;
    }
    return null;
  }

  _flutter.loader.load({
    config: scriptUrl ? { assetBase: scriptUrl } : {},
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        const target = getTargetElement();
        const engineConfig = {};
        if (target) {
          engineConfig.hostElement = target;
        }
        if (scriptUrl) {
          engineConfig.assetBase = scriptUrl;
        }

        const appRunner = await engineInitializer.initializeEngine(engineConfig);
        await appRunner.runApp();
      } catch (err) {
        console.error('[gingaf-web] Failed to initialize Flutter engine or run app:', err);
      }
    }
  });
})();
