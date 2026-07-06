import * as monaco from 'monaco-editor';
import EditorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker';

// @ts-ignore
import videoNcl from '../../examples/video.ncl?raw';
// @ts-ignore
import luaCanvasNcl from '../../examples/lua_canvas.ncl?raw';
// @ts-ignore
import luaCanvasLua from '../../examples/lua_canvas.lua?raw';
// @ts-ignore
import imageNcl from '../../examples/image.ncl?raw';
// @ts-ignore
import imageHtml from '../../examples/image.html?raw';
// @ts-ignore
import currentServiceHtml from '../../examples/current_service.html?raw';

self.MonacoEnvironment = {
  getWorker(_workerId: string, _label: string) {
    return new EditorWorker();
  }
};

interface Example {
  mainFile: string;
  files: Record<string, string>;
}

const examples: Record<string, Example> = {
  video: { mainFile: 'video.ncl', files: { 'video.ncl': videoNcl } },
  lua_canvas: { mainFile: 'lua_canvas.ncl', files: { 'lua_canvas.ncl': luaCanvasNcl, 'lua_canvas.lua': luaCanvasLua } },
  image: { mainFile: 'image.ncl', files: { 'image.ncl': imageNcl } },
  image_html: { mainFile: 'image.html', files: { 'image.html': imageHtml } },
  current_service: { mainFile: 'current_service.html', files: { 'current_service.html': currentServiceHtml } },
};

const editorContainer = document.getElementById('editor-container');
const editorTabs = document.getElementById('editor-tabs');
const runBtn = document.getElementById('run-btn');
const uploadBtn = document.getElementById('upload-btn');
const fileInput = document.getElementById('file-input') as HTMLInputElement;
const selectEl = document.getElementById('example-select') as HTMLSelectElement;
const iframe = document.getElementById('preview-frame') as HTMLIFrameElement;

const isEditableFile = (fileName: string) => {
  return fileName.endsWith('.ncl') || 
         fileName.endsWith('.xml') || 
         fileName.endsWith('.lua') || 
         fileName.endsWith('.html') || 
         fileName.endsWith('.js') || 
         fileName.endsWith('.css') || 
         fileName.endsWith('.txt');
};

if (editorContainer && editorTabs && runBtn && selectEl && iframe) {
  let currentExample = examples['video'];
  let currentFileName = currentExample.mainFile;
  let isRunning = false;

  const editor = monaco.editor.create(editorContainer, {
    value: currentExample.files[currentFileName],
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
          editor.setValue(currentExample.files[currentFileName]);
          monaco.editor.setModelLanguage(editor.getModel()!, fileName.endsWith('.lua') ? 'lua' : (fileName.endsWith('.html') ? 'html' : 'xml'));
          renderTabs();
        }
      });
      editorTabs.appendChild(tab);
    }
  };

  renderTabs();

  selectEl.addEventListener('change', () => {
    const selected = selectEl.value;
    if (examples[selected]) {
      if (isRunning) {
        runBtn.click();
      }
      currentExample = examples[selected];
      currentFileName = currentExample.mainFile;
      editor.setValue(currentExample.files[currentFileName]);
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
      
      sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(currentExample.files));
      sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', currentExample.mainFile);
      
      editor.updateOptions({ readOnly: true });
      document.getElementById('editor-overlay')?.classList.remove('hidden');
      runBtn.textContent = 'Stop';
      iframe.src = 'player/index.html';
      isRunning = true;
    }
  });

  window.addEventListener('message', (event) => {
    if (event.data === 'ginga_app_exited' && isRunning) {
      runBtn.click();
    }
  });
}
