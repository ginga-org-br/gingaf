import bundledExamples from './examples.json';

export interface Example {
  mainFile: string;
  rawMainUrl?: string;
  category?: string;
  description?: string;
  files: Record<string, string>;
  fileUrls?: Record<string, string>;
}

const examples: Record<string, Example> = bundledExamples as Record<string, Example>;

const RAW_GITHUB_BASE = 'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/gingaf/ginga/examples/';
const RAW_PJ_BASE = `${RAW_GITHUB_BASE}primeiro-joao/`;

const pjMediaFiles: Record<string, string> = {
  'media/animGar.mp4': `${RAW_PJ_BASE}media/animGar.mp4`,
  'media/background.png': `${RAW_PJ_BASE}media/background.png`,
  'media/backgroundPassive.png': `${RAW_PJ_BASE}media/backgroundPassive.png`,
  'media/cartoes.png': `${RAW_PJ_BASE}media/cartoes.png`,
  'media/cartoon.mp4': `${RAW_PJ_BASE}media/cartoon.mp4`,
  'media/cartoon.png': `${RAW_PJ_BASE}media/cartoon.png`,
  'media/chorinho.png': `${RAW_PJ_BASE}media/chorinho.png`,
  'media/choro.mp4': `${RAW_PJ_BASE}media/choro.mp4`,
  'media/chut.png': `${RAW_PJ_BASE}media/chut.png`,
  'media/chuteira_mod.png': `${RAW_PJ_BASE}media/chuteira_mod.png`,
  'media/drible.mp4': `${RAW_PJ_BASE}media/drible.mp4`,
  'media/enComprou.htm': `${RAW_PJ_BASE}media/enComprou.htm`,
  'media/enForm.htm': `${RAW_PJ_BASE}media/enForm.htm`,
  'media/icon.png': `${RAW_PJ_BASE}media/icon.png`,
  'media/iconPassive.png': `${RAW_PJ_BASE}media/iconPassive.png`,
  'media/intOff.png': `${RAW_PJ_BASE}media/intOff.png`,
  'media/intOn.png': `${RAW_PJ_BASE}media/intOn.png`,
  'media/photo.png': `${RAW_PJ_BASE}media/photo.png`,
  'media/ptComprou.htm': `${RAW_PJ_BASE}media/ptComprou.htm`,
  'media/ptForm.htm': `${RAW_PJ_BASE}media/ptForm.htm`,
  'media/rock.mp4': `${RAW_PJ_BASE}media/rock.mp4`,
  'media/rock.png': `${RAW_PJ_BASE}media/rock.png`,
  'media/shoes.mp4': `${RAW_PJ_BASE}media/shoes.mp4`,
  'media/techno.mp4': `${RAW_PJ_BASE}media/techno.mp4`,
  'media/techno.png': `${RAW_PJ_BASE}media/techno.png`,
};

export function initPlayer(): void {
  console.log('[ginga-node] INFO: initPlayer() starting...');
  document.body.classList.add('mode-player');
  const appEl = document.getElementById('app');
  if (!appEl) {
    console.error('[ginga-node] #app element not found');
    return;
  }

  const urlParams = new URLSearchParams(window.location.search);
  const appParam = urlParams.get('app');
  const playerParam = urlParams.get('player');

  let playerBaseUrl = 'gingaf-web/index.html';
  const isHostedEnv = typeof process !== 'undefined' && (process as any).env ? (process as any).env.VITE_USE_HOSTED_PLAYER === 'true' : false;
  const useHosted = playerParam === 'hosted' || (playerParam !== 'local' && isHostedEnv);
  if (useHosted) {
    playerBaseUrl = 'https://ginga-org-br.github.io/gingaf/dst/gingaf-web/index.html';
  }

  let targetExample: Example | undefined;
  if (appParam) {
    const extractedFileName = appParam.split('/').pop() || appParam;
    const extractedKey = extractedFileName.replace(/\.[^/.]+$/, "");

    if (examples[appParam]) {
      targetExample = examples[appParam];
    } else if (examples[extractedFileName]) {
      targetExample = examples[extractedFileName];
    } else if (examples[extractedKey]) {
      targetExample = examples[extractedKey];
    } else {
      for (const key of Object.keys(examples)) {
        if (examples[key].mainFile === extractedFileName || examples[key].mainFile === appParam) {
          targetExample = examples[key];
          break;
        }
      }
    }
  }

  if (!targetExample) {
    targetExample = examples['video'];
  }

  console.log('[ginga-node] INFO: Player target example resolved:', targetExample.mainFile);

  const allFiles = targetExample.category === 'primeiro-joao'
    ? { ...pjMediaFiles, ...targetExample.files }
    : targetExample.files;

  try {
    window.sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(allFiles));
    window.sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', targetExample.mainFile);
    (window as any).GingaApp = {
      appPath: targetExample.mainFile,
      files: allFiles
    };
  } catch (e) {
    console.warn('[ginga-node] Could not set window.sessionStorage:', e);
  }

  const iframe = document.createElement('iframe');
  iframe.id = 'preview-frame';
  iframe.style.cssText = 'width:100vw; height:100vh; border:none; margin:0; padding:0; display:block;';

  iframe.onload = () => {
    try {
      const win = iframe.contentWindow as any;
      if (win && targetExample) {
        win.sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(allFiles));
        win.sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', targetExample.mainFile);
        win.GingaApp = {
          appPath: targetExample.mainFile,
          files: allFiles
        };
      }
    } catch (_) {}
  };

  const srcUrl = `${playerBaseUrl}?app=${encodeURIComponent(targetExample.mainFile)}`;
  console.log('[ginga-node] INFO: Mounting inner player iframe src:', srcUrl);

  iframe.src = srcUrl;
  appEl.innerHTML = '';
  appEl.appendChild(iframe);
}
