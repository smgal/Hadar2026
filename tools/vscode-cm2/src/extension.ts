import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind,
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;
let output: vscode.OutputChannel | undefined;
let watcher: vscode.FileSystemWatcher | undefined;

// Starts and stops run strictly one after another. Restarting while a
// start was still in flight used to leave two servers answering for the
// same files, because stop() throws on a client that is only Starting.
let lifecycle: Promise<void> = Promise.resolve();
function serialized(step: () => Promise<void>): Promise<void> {
  lifecycle = lifecycle.then(step, step);
  return lifecycle;
}

type Resolved = { options: ServerOptions; describe: string } | { error: string };

/**
 * 서버를 어떻게 띄울지 정한다.
 *
 * 1. 설정 `cm2.server.executable` 이 있으면 그 파일.
 * 2. 없으면 `server/build/cm2_lsp` 또는 `cm2_lsp.exe` 가 있는지 본다 (`pnpm run server:build`).
 * 3. 둘 다 없으면 `dart run bin/cm2_lsp.dart` — 단, 이 확장이 레포 안에 있을 때만.
 *    서버의 pubspec 이 `../../../packages/*` 를 가리키므로 설치된 .vsix 폴더에서는 풀리지 않는다.
 *
 * 동사 표(JSON)는 어느 경우든 `--symbols` 로 넘긴다. 컴파일된 실행 파일은
 * package: URI 를 풀 수 없기 때문이다.
 */
function resolveServer(
  context: vscode.ExtensionContext,
  cfg: vscode.WorkspaceConfiguration,
): Resolved {
  const serverDir = path.join(context.extensionPath, 'server');
  const symbols = path.join(serverDir, 'lib', 'data', 'cm2_symbols.json');
  let exe = (cfg.get<string>('server.executable') ?? '').trim();
  if (!exe) {
    for (const name of ['cm2_lsp', 'cm2_lsp.exe']) {
      const built = path.join(serverDir, 'build', name);
      if (fs.existsSync(built)) {
        exe = built;
        break;
      }
    }
  }
  if (exe) {
    return {
      options: {
        command: exe,
        args: ['--symbols', symbols],
        transport: TransportKind.stdio,
      },
      describe: exe,
    };
  }

  const repoPackage = path.join(serverDir, '..', '..', '..', 'packages', 'cm2_script', 'pubspec.yaml');
  if (!fs.existsSync(repoPackage)) {
    return {
      error:
        '컴파일된 언어 서버(server/build/cm2_lsp)가 이 확장에 없거나 이 OS 용이 아닙니다. ' +
        '레포에서 `pnpm run server:build` 를 하거나, 설정 cm2.server.executable 에 서버 실행 파일 경로를 지정하세요.',
    };
  }
  const dart = (cfg.get<string>('server.dartPath') ?? 'dart').trim() || 'dart';
  return {
    options: {
      command: dart,
      args: ['run', 'bin/cm2_lsp.dart', '--symbols', symbols],
      // Windows ships `dart.bat`; spawning it needs a shell.
      options: { cwd: serverDir, shell: process.platform === 'win32' },
      transport: TransportKind.stdio,
    },
    describe: `${dart} run bin/cm2_lsp.dart (cwd: ${serverDir})`,
  };
}

function guessAssetsDir(cfg: vscode.WorkspaceConfiguration): string {
  const configured = (cfg.get<string>('assetsDir') ?? '').trim();
  if (configured) return configured;
  for (const folder of vscode.workspace.workspaceFolders ?? []) {
    const candidate = path.join(folder.uri.fsPath, 'hadar2026_app', 'assets');
    if (fs.existsSync(candidate)) return candidate;
    const self = path.join(folder.uri.fsPath, 'assets');
    if (fs.existsSync(path.join(self, 'const.cm2'))) return self;
  }
  return '';
}

async function startClient(context: vscode.ExtensionContext): Promise<void> {
  const cfg = vscode.workspace.getConfiguration('cm2');
  output ??= vscode.window.createOutputChannel('CM2 Language Server');
  const resolved = resolveServer(context, cfg);
  if ('error' in resolved) {
    output.appendLine(`[cm2] ${resolved.error}`);
    void vscode.window.showErrorMessage(`CM2: ${resolved.error}`);
    return;
  }
  output.appendLine(`[cm2] starting server: ${resolved.describe}`);

  // One watcher for the life of the extension; the client does not own it.
  watcher ??= vscode.workspace.createFileSystemWatcher('**/*.cm2');

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'cm2' }],
    outputChannel: output,
    initializationOptions: {
      assetsDir: guessAssetsDir(cfg),
      eventOverrideHint: cfg.get<boolean>('diagnostics.eventOverrideHint') ?? true,
    },
    synchronize: { fileEvents: watcher },
  };

  const next = new LanguageClient('cm2', 'CM2 Language Server', resolved.options, clientOptions);
  client = next;
  try {
    await next.start();
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    output.appendLine(`[cm2] server failed to start: ${message}`);
    void vscode.window.showErrorMessage(
      `CM2 언어 서버를 못 띄웠습니다: ${message}. 시도한 명령: ${resolved.describe}`,
    );
    if (client === next) client = undefined;
  }
}

async function stopClient(): Promise<void> {
  const current = client;
  client = undefined;
  if (!current) return;
  try {
    // A client that failed to start has nothing to stop; stop() would throw.
    if (current.isRunning()) await current.stop();
  } catch (e) {
    output?.appendLine(`[cm2] stop failed: ${e instanceof Error ? e.message : String(e)}`);
  }
}

export async function activate(context: vscode.ExtensionContext): Promise<void> {
  watcher = vscode.workspace.createFileSystemWatcher('**/*.cm2');
  context.subscriptions.push(watcher);

  context.subscriptions.push(
    vscode.commands.registerCommand('cm2.restartServer', () =>
      serialized(async () => {
        await stopClient();
        await startClient(context);
      }),
    ),
  );
  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      // Every cm2.* setting reaches the server only at start.
      if (e.affectsConfiguration('cm2')) void vscode.commands.executeCommand('cm2.restartServer');
    }),
  );
  await serialized(() => startClient(context));
}

export function deactivate(): Promise<void> {
  return serialized(stopClient);
}
