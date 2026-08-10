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
let outputChannel = undefined;

function getOutputChannel() {
  if (!outputChannel) {
    outputChannel = vscode.window.createOutputChannel('Ginga Player');
  }
  return outputChannel;
}

function logToOutput(message) {
  const channel = getOutputChannel();
  channel.appendLine(message);
  channel.show(true);
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

function getExecutableInStorage(storageDir) {
  const fs = require('fs');
  if (process.platform === 'win32') {
    const exe = path.join(storageDir, 'gingaf.exe');
    if (fs.existsSync(exe)) return exe;
  } else if (process.platform === 'darwin') {
    const macApp = path.join(storageDir, 'gingaf.app', 'Contents', 'MacOS', 'gingaf');
    if (fs.existsSync(macApp)) return macApp;
    const bin = path.join(storageDir, 'gingaf');
    if (fs.existsSync(bin)) return bin;
  } else {
    const bin = path.join(storageDir, 'gingaf');
    if (fs.existsSync(bin)) return bin;
  }
  return undefined;
}

function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    const https = require('https');
    const http = require('http');
    const fs = require('fs');

    function fetchUrl(currentUrl, redirects = 0) {
      if (redirects > 5) return reject(new Error('Too many redirects'));
      const client = currentUrl.startsWith('https') ? https : http;
      client.get(currentUrl, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return fetchUrl(res.headers.location, redirects + 1);
        }
        if (res.statusCode !== 200) {
          return reject(new Error(`Failed to download: HTTP ${res.statusCode}`));
        }
        const fileStream = fs.createWriteStream(destPath);
        res.pipe(fileStream);
        fileStream.on('finish', () => {
          fileStream.close(resolve);
        });
        fileStream.on('error', (err) => {
          fs.unlink(destPath, () => reject(err));
        });
      }).on('error', reject);
    }
    fetchUrl(url);
  });
}

async function resolveOrDownloadExecutable(context, documentPath) {
  const fs = require('fs');

  logToOutput(`[Ginga Player] Resolving executable for document: ${documentPath}`);

  const userConfig = vscode.workspace.getConfiguration('vscode');
  const configuredPath = (userConfig.get('gingafExePath') || userConfig.get('gingafExecutable') || '').trim();
  if (configuredPath && fs.existsSync(configuredPath)) {
    logToOutput(`[Ginga Player] Using configured executable path: ${configuredPath}`);
    return configuredPath;
  }

  const storageDir = context && context.globalStorageUri
    ? context.globalStorageUri.fsPath
    : (context ? path.join(context.extensionPath, 'bin') : path.join(__dirname, '..', 'bin'));

  const storageExec = getExecutableInStorage(storageDir);
  if (storageExec && fs.existsSync(storageExec)) {
    logToOutput(`[Ginga Player] Using downloaded release executable from storage: ${storageExec}`);
    return storageExec;
  }

  const packageJson = require('../package.json');
  const version = packageJson.version || '0.1.1';
  let platformName = 'windows-x64';
  if (process.platform === 'darwin') {
    const arch = process.arch === 'arm64' ? 'arm64' : 'x64';
    platformName = `macos-${arch}`;
  } else if (process.platform === 'linux') {
    const arch = process.arch === 'arm64' ? 'arm64' : 'x86_64';
    platformName = `linux-${arch}`;
  }

  const zipName = `gingaf-v${version}-${platformName}.zip`;
  const downloadUrl = `https://github.com/ginga-org-br/gingaf/releases/download/v${version}/${zipName}`;

  logToOutput(`[Ginga Player] Release executable not found locally. Downloading release v${version} from: ${downloadUrl}`);

  if (!fs.existsSync(storageDir)) {
    fs.mkdirSync(storageDir, { recursive: true });
  }

  const zipPath = path.join(storageDir, 'release.zip');

  await vscode.window.withProgress({
    location: vscode.ProgressLocation.Notification,
    title: `Downloading Ginga player release v${version}...`,
    cancellable: false
  }, async () => {
    await downloadFile(downloadUrl, zipPath);
    logToOutput(`[Ginga Player] Extracting release zip to: ${storageDir}`);
    const cp = require('child_process');
    if (process.platform === 'win32') {
      cp.execSync(`powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${storageDir}' -Force"`);
    } else {
      cp.execSync(`unzip -o "${zipPath}" -d "${storageDir}"`);
    }
    if (fs.existsSync(zipPath)) {
      fs.unlinkSync(zipPath);
    }
  });

  const downloadedExec = getExecutableInStorage(storageDir);
  if (downloadedExec && fs.existsSync(downloadedExec)) {
    if (process.platform !== 'win32') {
      try {
        fs.chmodSync(downloadedExec, 0o755);
      } catch (e) {}
    }
    logToOutput(`[Ginga Player] Successfully downloaded and extracted release executable: ${downloadedExec}`);
    return downloadedExec;
  }

  logToOutput(`[Ginga Player] ERROR: Release executable was not found after downloading from ${downloadUrl}`);
  throw new Error(`Ginga player release executable was not found after downloading from ${downloadUrl}`);
}

async function openPlayer(context, targetUri) {
  console.log('[Extension] openPlayer called for URI:', targetUri ? targetUri.toString() : 'null');
  if (targetUri) {
    targetDocumentUri = targetUri;
  }
  extensionContext = context;

  let documentPath = undefined;
  if (targetUri && typeof targetUri === 'string') {
    documentPath = targetUri;
  } else if (targetUri && targetUri.fsPath) {
    documentPath = targetUri.fsPath;
  } else {
    const activeEditor = vscode.window.activeTextEditor || lastActiveEditor;
    if (activeEditor && activeEditor.document) {
      documentPath = activeEditor.document.fileName;
    }
  }

  if (!documentPath) {
    vscode.window.showWarningMessage('No active editor open or document path found.');
    return;
  }

  let executable;
  try {
    executable = await resolveOrDownloadExecutable(context, documentPath);
  } catch (err) {
    vscode.window.showErrorMessage(`Failed to resolve Ginga player executable: ${err.message}`);
    return;
  }

  const cp = require('child_process');
  try {
    console.log('[Extension] Spawning Ginga player executable:', executable, 'with documentPath:', documentPath);
    const spawnEnv = Object.assign({}, process.env, { APP: documentPath });
    const child = cp.spawn(executable, [documentPath], {
      detached: true,
      stdio: 'ignore',
      cwd: path.dirname(executable),
      env: spawnEnv
    });
    child.on('error', (err) => {
      console.error('[Extension] Failed child process spawn error:', err);
    });
    child.unref();
    vscode.window.showInformationMessage(`Started Ginga player for: ${path.basename(documentPath)}`);
  } catch (err) {
    console.error('[Extension] Exception during cp.spawn:', err);
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

  const openPlayerCmd = vscode.commands.registerCommand('ginga.openPlayer', (uri) => openPlayer(context, uri));

  context.subscriptions.push(changeEditorSub, openPlayerCmd);
}

function deactivate() {
  currentPanel = undefined;
  isExecuting = false;
  virtualClockMs = 0;
  breakpoints.clear();
  activeEvents.clear();
  variables.clear();
  if (outputChannel) {
    outputChannel.dispose();
    outputChannel = undefined;
  }
}

module.exports = {
  activate,
  deactivate,
  startExecution,
  stopExecution,
  tickClock,
  openPlayer,
  handleBridgeMessage
};

