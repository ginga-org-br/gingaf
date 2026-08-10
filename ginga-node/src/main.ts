import { initPlayer } from './player';
import { initPlayground } from './playground';

function getEffectiveMode(): 'player' | 'playground' | 'playgroundSingle' | 'single' {
  const urlParams = new URLSearchParams(window.location.search);
  const urlMode = urlParams.get('mode');
  if (urlMode === 'player' || urlMode === 'playground' || urlMode === 'playgroundSingle' || urlMode === 'single') {
    return urlMode as any;
  }

  const bodyMode = document.body?.getAttribute('data-mode');
  if (bodyMode === 'player' || bodyMode === 'playground' || bodyMode === 'playgroundSingle' || bodyMode === 'single') {
    return bodyMode as any;
  }

  try {
    const scriptEl = (document.currentScript || document.querySelector('script[type="module"]')) as HTMLScriptElement;
    if (scriptEl && scriptEl.src) {
      const scriptUrl = new URL(scriptEl.src, window.location.href);
      const scriptMode = scriptUrl.searchParams.get('mode');
      if (scriptMode === 'player' || scriptMode === 'playground' || scriptMode === 'playgroundSingle' || scriptMode === 'single') {
        return scriptMode as any;
      }
    }
  } catch (_) {}

  const pathname = window.location.pathname.toLowerCase();
  if (pathname.includes('player.html') || pathname.endsWith('/player') || pathname.endsWith('/player/')) {
    return 'player';
  }

  return 'playground';
}

const mode = getEffectiveMode();
console.log('[ginga-node] INFO: main.ts router dispatched mode:', mode);

if (mode === 'player') {
  initPlayer();
} else {
  initPlayground(mode);
}
