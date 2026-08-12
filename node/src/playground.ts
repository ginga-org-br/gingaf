import * as monaco from 'monaco-editor';
import EditorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker';
import bundledExamples from './examples.json';
import { Example } from './player';

const RAW_GITHUB_BASE = 'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/';
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

(self as any).MonacoEnvironment = {
  getWorker(_workerId: string, _label: string) {
    return new EditorWorker();
  }
};

const examples: Record<string, Example> = bundledExamples as Record<string, Example>;

async function loadExampleFiles(example: Example): Promise<void> {
  if (example.fileUrls) {
    for (const [fileName, url] of Object.entries(example.fileUrls)) {
      if (!(fileName in example.files)) {
        try {
          const res = await fetch(url);
          if (res.ok) {
            example.files[fileName] = await res.text();
          }
        } catch (_) {}
      }
    }
  }
}

function resolveExampleKey(requested: string | null, available: Record<string, Example> = examples): string {
  if (!requested) return 'video';
  const key = Object.keys(available).find(k =>
    k === requested ||
    available[k].mainFile === requested ||
    available[k].mainFile === requested + '.ncl'
  );
  return key || 'video';
}

function parseQueryConfig(searchString: string) {
  const params = new URLSearchParams(searchString);
  const rateStr = params.get('rate') || params.get('playbackRate');
  const parsedRate = rateStr ? parseFloat(rateStr) : 1.0;
  return {
    requestedExample: params.get('example') || params.get('app'),
    isEmbed: params.get('embed') === 'true' || params.get('mode') === 'single' || params.get('mode') === 'playgroundSingle',
    category: params.get('category'),
    theme: params.get('theme'),
    playbackRate: isNaN(parsedRate) ? 1.0 : parsedRate
  };
}

const isEditableFile = (fileName: string) => {
  return fileName.endsWith('.ncl') ||
    fileName.endsWith('.xml') ||
    fileName.endsWith('.lua') ||
    fileName.endsWith('.html') ||
    fileName.endsWith('.htm') ||
    fileName.endsWith('.js') ||
    fileName.endsWith('.css') ||
    fileName.endsWith('.txt');
};

export async function initPlayground(mode: string): Promise<void> {
  console.log('[ginga-node] INFO: initPlayground() starting in mode:', mode);
  const editorContainer = document.getElementById('editor-container');
  const editorTabs = document.getElementById('editor-tabs');
  const runBtn = document.getElementById('run-btn');
  const uploadBtn = document.getElementById('upload-btn');
  const fileInput = document.getElementById('file-input') as HTMLInputElement;
  const selectEl = document.getElementById('example-select') as HTMLSelectElement;
  const iframe = document.getElementById('preview-frame') as HTMLIFrameElement;

  if (!editorContainer || !editorTabs || !runBtn || !selectEl || !iframe) {
    console.error('[ginga-node] Required Playground DOM elements not found');
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

  if (mode === 'single' || mode === 'playgroundSingle') {
    document.body.classList.add('mode-single');
    const controls = document.querySelector('.controls') as HTMLElement;
    if (controls) controls.style.display = 'none';
    if (uploadBtn) uploadBtn.style.display = 'none';
  }

  const queryConfig = parseQueryConfig(window.location.search);
  const requested = queryConfig.requestedExample;

  if (queryConfig.isEmbed) {
    document.body.classList.add('embed-mode');
  }

  let defaultKey = resolveExampleKey(requested, examples);

  if (requested && !examples[defaultKey]) {
    const isUrl = requested.startsWith('http://') || requested.startsWith('https://');
    const fileName = requested.split('/').pop()?.split('?')[0] || 'app.ncl';
    defaultKey = 'requested_app';
    examples[defaultKey] = {
      mainFile: fileName,
      rawMainUrl: isUrl ? requested : undefined,
      files: {},
      fileUrls: isUrl ? { [fileName]: requested } : undefined
    };
  }

  let currentExample = examples[defaultKey];
  let currentFileName = currentExample.mainFile;
  let isRunning = false;

  selectEl.value = defaultKey;
  await loadExampleFiles(currentExample);

  const editor = monaco.editor.create(editorContainer, {
    value: currentExample.files[currentFileName] || '',
    language: 'xml',
    theme: 'vs-dark',
    minimap: { enabled: false },
    automaticLayout: true,
    wordWrap: 'on',
  });

  const renderTabs = () => {
    editorTabs.innerHTML = '';
    for (const fileName of Object.keys(currentExample.files)) {
      if (!isEditableFile(fileName)) continue;
      const tab = document.createElement('div');
      tab.className = 'tab' + (fileName === currentFileName ? ' active' : '');
      tab.textContent = fileName;
      tab.addEventListener('click', () => {
        if (!isRunning) {
          currentExample.files[currentFileName] = editor.getValue();
          currentFileName = fileName;
          editor.setValue(currentExample.files[currentFileName] || '');
          monaco.editor.setModelLanguage(editor.getModel()!, fileName.endsWith('.lua') ? 'lua' : (fileName.endsWith('.html') ? 'html' : 'xml'));
          renderTabs();
        }
      });
      editorTabs.appendChild(tab);
    }
  };

  renderTabs();

  selectEl.addEventListener('change', async () => {
    const selected = selectEl.value;
    if (examples[selected]) {
      if (isRunning) {
        runBtn.click();
      }
      currentExample = examples[selected];
      await loadExampleFiles(currentExample);
      currentFileName = currentExample.mainFile;
      editor.setValue(currentExample.files[currentFileName] || '');
      monaco.editor.setModelLanguage(editor.getModel()!, currentFileName.endsWith('.lua') ? 'lua' : (currentFileName.endsWith('.html') ? 'html' : 'xml'));
      renderTabs();
    }
  });

  if (uploadBtn && fileInput) {
    uploadBtn.addEventListener('click', () => {
      if (!isRunning) {
        fileInput.click();
      }
    });

    fileInput.addEventListener('change', async () => {
      const files = fileInput.files;
      if (!files || files.length === 0) return;

      if (!examples['uploaded']) {
        examples['uploaded'] = {
          mainFile: '',
          files: {}
        };
      }

      let mainFileCandidate = '';
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        if (isEditableFile(file.name)) {
          const text = await file.text();
          examples['uploaded'].files[file.name] = text;
        } else {
          const url = URL.createObjectURL(file);
          examples['uploaded'].files[file.name] = url;
        }

        if (file.name.endsWith('.ncl')) {
          mainFileCandidate = file.name;
        } else if (file.name.endsWith('.html') && !mainFileCandidate.endsWith('.ncl')) {
          mainFileCandidate = file.name;
        } else if (!mainFileCandidate && isEditableFile(file.name)) {
          mainFileCandidate = file.name;
        }
      }

      if (mainFileCandidate) {
        examples['uploaded'].mainFile = mainFileCandidate;
      }

      let uploadedOption = Array.from(selectEl.options).find(opt => opt.value === 'uploaded');
      if (!uploadedOption) {
        uploadedOption = document.createElement('option');
        uploadedOption.value = 'uploaded';
        uploadedOption.textContent = 'Uploaded Files';
        selectEl.appendChild(uploadedOption);
      }

      selectEl.value = 'uploaded';
      selectEl.dispatchEvent(new Event('change'));
      fileInput.value = '';
    });
  }

  if (appParam) {
    const extractedFileName = appParam.split('/').pop() || appParam;
    const extractedKey = extractedFileName.replace(/\.[^/.]+$/, "");

    let matchedExample: Example | undefined;
    if (examples[appParam]) matchedExample = examples[appParam];
    else if (examples[extractedFileName]) matchedExample = examples[extractedFileName];
    else if (examples[extractedKey]) matchedExample = examples[extractedKey];
    else {
      for (const key of Object.keys(examples)) {
        if (examples[key].mainFile === extractedFileName || examples[key].mainFile === appParam) {
          matchedExample = examples[key];
          break;
        }
      }
    }

    if (matchedExample) {
      currentExample = matchedExample;
      currentFileName = currentExample.mainFile;
      editor.setValue(currentExample.files[currentFileName] || '');
      monaco.editor.setModelLanguage(editor.getModel()!, currentFileName.endsWith('.lua') ? 'lua' : 'xml');
      if (selectEl) {
        for (let i = 0; i < selectEl.options.length; i++) {
          if (selectEl.options[i].value === appParam || selectEl.options[i].value === extractedKey) {
            selectEl.selectedIndex = i;
            break;
          }
        }
      }
      renderTabs();
    } else {
      try {
        const res = await fetch(appParam);
        if (res.ok) {
          const text = await res.text();
          const customAppKey = 'remote_app';
          examples[customAppKey] = {
            mainFile: 'app.ncl',
            rawMainUrl: appParam,
            category: 'remote',
            description: 'Remote NCL App',
            files: { 'app.ncl': text }
          };
          currentExample = examples[customAppKey];
          currentFileName = currentExample.mainFile;
          editor.setValue(text);
          monaco.editor.setModelLanguage(editor.getModel()!, 'xml');
          renderTabs();
        }
      } catch (e) {
        console.warn('Could not fetch app GET parameter URL:', e);
      }
    }
  }

  iframe.src = 'about:blank';

  runBtn.addEventListener('click', async () => {
    if (isRunning) {
      editor.updateOptions({ readOnly: false });
      document.getElementById('editor-overlay')?.classList.add('hidden');
      runBtn.textContent = 'Run';
      iframe.src = 'about:blank';
      isRunning = false;
    } else {
      currentExample.files[currentFileName] = editor.getValue();

      const allFiles = currentExample.category === 'primeiro-joao'
        ? { ...pjMediaFiles, ...currentExample.files }
        : currentExample.files;

      sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(allFiles));
      sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', currentExample.mainFile);

      editor.updateOptions({ readOnly: true });
      document.getElementById('editor-overlay')?.classList.remove('hidden');
      runBtn.textContent = 'Stop';

      iframe.src = playerBaseUrl;
      iframe.onload = () => {
        try {
          const win = iframe.contentWindow as any;
          if (win) {
            win.sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(allFiles));
            win.sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', currentExample.mainFile);
            win.GingaApp = {
              appPath: currentExample.mainFile,
              files: allFiles
            };
          }
        } catch (_) {}
      };
      isRunning = true;
    }
  });
}
