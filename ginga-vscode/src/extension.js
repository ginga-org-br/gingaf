const path = require('path');
let vscode;
try {
  vscode = require('vscode');
} catch (e) {
  vscode = {
    ViewColumn: { Two: 2 },
    Range: class Range { constructor() {} },
    CodeLens: class CodeLens { constructor() {} },
    window: {
      activeTextEditor: {
        document: {
          fileName: 'test.ncl',
          getText: () => '<ncl><head></head><body><port id="p1" component="media1"/><media id="media1" src="media1.mp4"/></body ></ncl>'
        }
      },
      onDidChangeActiveTextEditor: () => ({ dispose: () => {} }),
      createWebviewPanel: () => ({
        webview: { html: '', postMessage: () => {}, onDidReceiveMessage: () => {} },
        reveal: () => {},
        onDidDispose: () => {}
      }),
      showInformationMessage: () => {},
      showWarningMessage: () => {}
    },
    languages: {
      registerCodeLensProvider: () => ({ dispose: () => {} })
    },
    commands: {
      registerCommand: (name, cb) => ({ name, cb })
    },
    workspace: {
      textDocuments: [],
      onDidOpenTextDocument: () => ({ dispose: () => {} }),
      onDidChangeTextDocument: () => ({ dispose: () => {} }),
      onDidCloseTextDocument: () => ({ dispose: () => {} })
    },
    tests: {
      createTestController: () => ({
        createRunProfile: () => ({ dispose: () => {} }),
        items: {
          add: () => {},
          delete: () => {},
          get: () => undefined,
          forEach: () => {}
        },
        createTestItem: (id, label, uri) => ({ id, label, uri }),
        dispose: () => {}
      })
    },
    TestRunProfileKind: {
      Run: 1,
      Debug: 2,
      Coverage: 3
    }
  };
}


let currentPanel = undefined;
let isExecuting = false;
let virtualClockMs = 0;
let breakpoints = new Set();
let activeEvents = new Map();
let variables = new Map();
let lastActiveEditor = undefined;
let targetDocumentUri = undefined;
let extensionContext = undefined;

function getWebviewContent(title, playerUri, cspSource) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self' ${cspSource} https: data: blob: 'unsafe-inline' 'unsafe-eval'; frame-src 'self' ${cspSource} https: data: blob:; connect-src 'self' ${cspSource} https: data: blob:; img-src 'self' ${cspSource} https: data: blob:; media-src 'self' ${cspSource} https: data: blob:; script-src 'self' ${cspSource} https: 'unsafe-inline' 'unsafe-eval' blob:; style-src 'self' ${cspSource} 'unsafe-inline';">
  <title>${title}</title>
  <style>
    body {
      font-family: var(--vscode-font-family, sans-serif);
      background-color: var(--vscode-editor-background, #1e1e1e);
      color: var(--vscode-editor-foreground, #d4d4d4);
      padding: 16px;
      margin: 0;
    }
    .toolbar {
      display: flex;
      gap: 8px;
      align-items: center;
      margin-bottom: 16px;
      padding-bottom: 8px;
      border-bottom: 1px solid var(--vscode-widget-border, #454545);
    }
    button {
      background: var(--vscode-button-background, #0e639c);
      color: var(--vscode-button-foreground, #ffffff);
      border: none;
      padding: 6px 12px;
      cursor: pointer;
      font-size: 13px;
      border-radius: 2px;
    }
    button:hover {
      background: var(--vscode-button-hoverBackground, #1177bb);
    }
    button:disabled {
      background: var(--vscode-button-secondaryBackground, #3a3d41);
      color: var(--vscode-button-secondaryForeground, #cccccc);
      cursor: not-allowed;
    }
    .status-badge {
      font-size: 12px;
      padding: 4px 8px;
      border-radius: 4px;
      background: var(--vscode-badge-background, #4d4d4d);
      color: var(--vscode-badge-foreground, #ffffff);
      margin-left: auto;
    }
    #player-frame {
      width: 100%;
      height: 480px;
      border: 1px solid var(--vscode-widget-border, #454545);
      background: #000;
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <button id="btn-start">Start</button>
    <button id="btn-stop" disabled>Stop</button>
    <button id="btn-tick-100">Tick (+100ms)</button>
    <button id="btn-tick-1s">Tick (+1s)</button>
    <span class="status-badge" id="status-clock">Clock: 0 ms | Status: STOPPED</span>
  </div>
  <div id="player-container">
    <iframe id="player-frame" src="${playerUri}"></iframe>
  </div>

  <script>
    const vscode = acquireVsCodeApi();
    const btnStart = document.getElementById('btn-start');
    const btnStop = document.getElementById('btn-stop');
    const btnTick100 = document.getElementById('btn-tick-100');
    const btnTick1s = document.getElementById('btn-tick-1s');
    const statusClock = document.getElementById('status-clock');
    const iframe = document.getElementById('player-frame');

    let pendingFiles = null;
    let pendingMain = null;

    function logToExtension(msg) {
      console.log('[Webview]', msg);
      vscode.postMessage({ command: 'log', message: msg });
    }

    let isFirstLoad = true;
    logToExtension('Webview initialized. Setting up iframe load listener.');
    iframe.addEventListener('load', () => {
      logToExtension('Iframe loaded. isFirstLoad = ' + isFirstLoad);
      if (isFirstLoad) {
        isFirstLoad = false;
        logToExtension('Posting playerReady to extension host.');
        vscode.postMessage({ command: 'playerReady' });
      }

      if (pendingFiles && pendingMain) {
        logToExtension('Sending LOAD_PLAYGROUND_FILES to iframe.');
        iframe.contentWindow.postMessage({
          type: 'LOAD_PLAYGROUND_FILES',
          mainFile: pendingMain,
          files: pendingFiles
        }, '*');
        pendingFiles = null;
        pendingMain = null;
      }
    });

    btnStart.addEventListener('click', () => {
      logToExtension('Start button clicked.');
      vscode.postMessage({ command: 'start' });
    });

    btnStop.addEventListener('click', () => {
      logToExtension('Stop button clicked.');
      vscode.postMessage({ command: 'stop' });
    });

    btnTick100.addEventListener('click', () => {
      logToExtension('Tick 100ms clicked.');
      vscode.postMessage({ command: 'tick', deltaMs: 100 });
    });

    btnTick1s.addEventListener('click', () => {
      logToExtension('Tick 1s clicked.');
      vscode.postMessage({ command: 'tick', deltaMs: 1000 });
    });

    window.addEventListener('message', event => {
      let message = event.data;
      logToExtension('Webview received window message: ' + (typeof message === 'object' ? JSON.stringify(message) : message));
      try {
        if (typeof message === 'string') {
          message = JSON.parse(message);
        }
      } catch (e) {}

      if (message.command === 'updateState') {
        statusClock.textContent = 'Clock: ' + message.clockMs + ' ms | Status: ' + (message.running ? 'RUNNING' : 'STOPPED');
        btnStart.disabled = message.running;
        btnStop.disabled = !message.running;
      } else if (message.command === 'loadUri') {
        logToExtension('Webview loading URI: ' + message.uri);
        if (message.fileContent && message.fileName) {
          pendingFiles = {};
          pendingFiles[message.fileName] = message.fileContent;
          pendingMain = message.fileName;
        }
        iframe.src = message.uri;
      } else if (message.type === 'PLAYER_READY') {
        logToExtension('Webview received PLAYER_READY from iframe. Forwarding to host.');
        vscode.postMessage({ command: 'playerReady' });
      } else if (message.type === 'PLAYER_STATE_UPDATE') {
        vscode.postMessage({
          command: 'playerStateUpdate',
          clockMs: message.clockMs,
          running: message.running
        });
      } else if (message.type === 'PLAYER_LOG') {
        vscode.postMessage({
          command: 'log',
          message: \`[Player \${message.level}] \${message.message}\`
        });
      }
    });
  </script>
</body>
</html>`;
}

function updateWebviewState() {
  if (currentPanel) {
    currentPanel.webview.postMessage({
      command: 'updateState',
      running: isExecuting,
      clockMs: virtualClockMs
    });
  }
}

function isExecutableAvailable(executable) {
  const fs = require('fs');
  if (path.isAbsolute(executable)) {
    return fs.existsSync(executable);
  }
  const pathDirs = (process.env.PATH || '').split(process.platform === 'win32' ? ';' : ':');
  const extensions = process.platform === 'win32' ? ['.exe', '.cmd', '.bat', ''] : [''];
  for (const dir of pathDirs) {
    for (const ext of extensions) {
      const fullPath = path.join(dir, executable + ext);
      if (fs.existsSync(fullPath)) {
        return true;
      }
    }
  }
  return false;
}

function openPlayer(context, targetUri) {
  console.log('[Extension] openPlayer called for URI:', targetUri ? targetUri.toString() : 'null');
  if (targetUri) {
    targetDocumentUri = targetUri;
  }
  extensionContext = context;

  let documentPath = undefined;
  if (targetUri) {
    documentPath = targetUri.fsPath;
  } else {
    const activeEditor = vscode.window.activeTextEditor || lastActiveEditor;
    if (activeEditor) {
      documentPath = activeEditor.document.fileName;
    }
  }

  if (!documentPath) {
    vscode.window.showWarningMessage('No active editor open or document path found.');
    return;
  }

  const cp = require('child_process');
  const fs = require('fs');

  let executable = 'gingaf';

  const userConfig = vscode.workspace.getConfiguration('ginga-vscode');
  const configuredPath = userConfig ? userConfig.get('gingafExePath') : undefined;
  if (configuredPath && configuredPath.trim() !== '') {
    executable = configuredPath.trim();
  } else if (vscode.workspace && vscode.workspace.workspaceFolders) {
    for (const folder of vscode.workspace.workspaceFolders) {
      const rootPath = folder.uri.fsPath;
      let possiblePaths = [];
      if (process.platform === 'win32') {
        possiblePaths = [
          path.join(rootPath, 'ginga', 'build', 'windows', 'x64', 'runner', 'Debug', 'gingaf.exe'),
          path.join(rootPath, 'ginga', 'build', 'windows', 'x64', 'runner', 'Release', 'gingaf.exe'),
          path.join(rootPath, 'build', 'windows', 'x64', 'runner', 'Debug', 'gingaf.exe'),
          path.join(rootPath, 'build', 'windows', 'x64', 'runner', 'Release', 'gingaf.exe'),
          path.join(rootPath, '..', 'ginga', 'build', 'windows', 'x64', 'runner', 'Debug', 'gingaf.exe'),
          path.join(rootPath, '..', 'ginga', 'build', 'windows', 'x64', 'runner', 'Release', 'gingaf.exe'),
        ];
      } else if (process.platform === 'darwin') {
        possiblePaths = [
          path.join(rootPath, 'ginga', 'build', 'macos', 'Build', 'Products', 'Debug', 'gingaf.app', 'Contents', 'MacOS', 'gingaf'),
          path.join(rootPath, 'ginga', 'build', 'macos', 'Build', 'Products', 'Release', 'gingaf.app', 'Contents', 'MacOS', 'gingaf'),
          path.join(rootPath, '..', 'ginga', 'build', 'macos', 'Build', 'Products', 'Debug', 'gingaf.app', 'Contents', 'MacOS', 'gingaf'),
          path.join(rootPath, '..', 'ginga', 'build', 'macos', 'Build', 'Products', 'Release', 'gingaf.app', 'Contents', 'MacOS', 'gingaf'),
        ];
      } else {
        possiblePaths = [
          path.join(rootPath, 'ginga', 'build', 'linux', 'x64', 'debug', 'bundle', 'gingaf'),
          path.join(rootPath, 'ginga', 'build', 'linux', 'x64', 'release', 'bundle', 'gingaf'),
          path.join(rootPath, '..', 'ginga', 'build', 'linux', 'x64', 'debug', 'bundle', 'gingaf'),
          path.join(rootPath, '..', 'ginga', 'build', 'linux', 'x64', 'release', 'bundle', 'gingaf'),
        ];
      }

      for (const p of possiblePaths) {
        if (fs.existsSync(p)) {
          executable = p;
          break;
        }
      }
      if (executable !== 'gingaf') {
        break;
      }
    }
  }

  if (!isExecutableAvailable(executable)) {
    if (configuredPath) {
      vscode.window.showErrorMessage(`Ginga player executable was not found at configured path '${configuredPath}'. Please correct the 'ginga-vscode.gingafExePath' setting.`);
    } else {
      vscode.window.showErrorMessage(`Ginga player executable '${executable}' was not found in the workspace or system PATH. Please configure the setting 'ginga-vscode.gingafExePath' in VS Code.`);
    }
    return;
  }

  try {
    const spawnEnv = { ...process.env, APP: documentPath };
    const child = cp.spawn(executable, [], {
      detached: true,
      stdio: 'ignore',
      env: spawnEnv
    });
    child.unref();
    vscode.window.showInformationMessage(`Started Ginga player for: ${path.basename(documentPath)}`);
  } catch (err) {
    vscode.window.showErrorMessage(`Failed to start Ginga player: ${err.message}`);
  }
}

function startExecution() {
  console.log('[Extension] startExecution called.');
  let document = undefined;

  if (targetDocumentUri) {
    const openDoc = vscode.workspace.textDocuments.find(
      d => d.uri.toString() === targetDocumentUri.toString()
    );
    if (openDoc) {
      document = openDoc;
    }
  }

  if (!document) {
    const activeEditor = vscode.window.activeTextEditor || lastActiveEditor;
    if (activeEditor) {
      document = activeEditor.document;
    }
  }

  if (!document) {
    console.log('[Extension] startExecution failed: no active document found.');
    vscode.window.showWarningMessage('No active editor open to execute.');
    return;
  }

  const fileName = path.basename(document.fileName);
  const fileText = document.getText();
  console.log('[Extension] Loading NCL document:', fileName);

  isExecuting = true;
  virtualClockMs = 0;
  updateWebviewState();

  if (currentPanel && extensionContext) {
    currentPanel.title = `Ginga Player: ${fileName}`;
    const fileUri = currentPanel.webview.asWebviewUri(document.uri).toString();
    const playerUriBase = currentPanel.webview.asWebviewUri(
      vscode.Uri.file(path.join(extensionContext.extensionPath, 'player', 'index.html'))
    ).toString();
    const targetPlayerUri = `${playerUriBase}?APP=${encodeURIComponent(fileUri)}`;
    currentPanel.webview.postMessage({
      command: 'loadUri',
      uri: targetPlayerUri,
      fileContent: fileText,
      fileName: fileName
    });
  }
  vscode.window.showInformationMessage('Ginga NCL document execution started.');
}

function stopExecution() {
  isExecuting = false;
  updateWebviewState();
  if (currentPanel) {
    currentPanel.title = 'Ginga Visual Player & Debugger';
  }
  vscode.window.showInformationMessage('Ginga NCL document execution stopped.');
}

function tickClock(deltaMs = 100) {
  if (!isExecuting) {
    vscode.window.showWarningMessage('Cannot tick Virtual Clock when execution is stopped.');
    return;
  }
  virtualClockMs += deltaMs;
  updateWebviewState();
}

function handleBridgeMessage(message) {
  if (!message || typeof message !== 'object') {
    return { status: 'error', error: 'Invalid message payload' };
  }

  switch (message.type) {
    case 'step':
      tickClock(message.deltaMs || 100);
      return { status: 'ok', type: 'stepResponse', clockMs: virtualClockMs, running: isExecuting };
    case 'inspectState':
      return { status: 'ok', type: 'stateResponse', clockMs: virtualClockMs, running: isExecuting };
    case 'triggerEvent':
      if (message.eventId && message.state) {
        activeEvents.set(message.eventId, message.state);
      }
      return { status: 'ok', type: 'eventTriggered', eventId: message.eventId, active: true };
    case 'linkEvaluated':
      return { status: 'ok', type: 'linkStatus', linkId: message.linkId, evaluated: true };
    case 'setBreakpoint':
      if (message.nodeId) breakpoints.add(message.nodeId);
      return { status: 'ok', type: 'breakpointSet', nodeId: message.nodeId, breakpoints: Array.from(breakpoints) };
    case 'clearBreakpoint':
      if (message.nodeId) breakpoints.delete(message.nodeId);
      return { status: 'ok', type: 'breakpointCleared', nodeId: message.nodeId, breakpoints: Array.from(breakpoints) };
    case 'getBreakpoints':
      return { status: 'ok', type: 'breakpointsList', breakpoints: Array.from(breakpoints) };
    case 'inspectActiveEvents':
      return { status: 'ok', type: 'activeEventsResponse', events: Array.from(activeEvents.entries()).map(([id, state]) => ({ id, state })) };
    case 'setVariable':
      if (message.name !== undefined && message.value !== undefined) {
        variables.set(message.name, message.value);
      }
      return { status: 'ok', type: 'variableSet', name: message.name, value: message.value };
    case 'inspectVariable':
      const value = message.name ? variables.get(message.name) : undefined;
      return { status: 'ok', type: 'variableInspected', name: message.name, value: value };
    case 'listVariables':
      return { status: 'ok', type: 'variablesListResponse', variables: Array.from(variables.entries()).map(([name, val]) => ({ name, val })) };
    default:
      return { status: 'error', error: 'Unknown message type: ' + message.type };
  }
}

function activate(context) {
  extensionContext = context;
  const initialEditor = vscode.window.activeTextEditor;
  if (initialEditor && (initialEditor.document.languageId === 'xml' || initialEditor.document.fileName.endsWith('.ncl') || initialEditor.document.fileName.endsWith('.html'))) {
    lastActiveEditor = initialEditor;
  }

  const changeEditorSub = vscode.window.onDidChangeActiveTextEditor(editor => {
    if (editor && (editor.document.languageId === 'xml' || editor.document.fileName.endsWith('.ncl') || editor.document.fileName.endsWith('.html'))) {
      lastActiveEditor = editor;
    }
  });

  context.subscriptions.push(changeEditorSub);
}

function deactivate() {
  currentPanel = undefined;
  isExecuting = false;
  virtualClockMs = 0;
  breakpoints.clear();
  activeEvents.clear();
  variables.clear();
}

module.exports = {
  activate,
  deactivate,
  startExecution,
  stopExecution,
  tickClock,
  openPlayer,
  getWebviewContent,
  handleBridgeMessage
};

