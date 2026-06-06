import type { TeleprompterAsrClient } from '@/lib/teleprompter/asr-client';
import type { AsrLatencySample } from '@/lib/teleprompter/telemetry';
// eslint-disable-next-line import/no-unresolved
import asrBindingJsUrl from '@/assets/asr-browser/sherpa-onnx-asr.js?url';
// eslint-disable-next-line import/no-unresolved
import wasmRuntimeJsUrl from '@/assets/asr-browser/sherpa-onnx-wasm-main-asr.js?url';
// eslint-disable-next-line import/no-unresolved
import wasmBinaryUrl from '@/assets/asr-browser/sherpa-onnx-wasm-main-asr.wasm?url';
// eslint-disable-next-line import/no-unresolved
import wasmDataUrl from '@/assets/asr-browser/sherpa-onnx-wasm-main-asr.data?url';
import { logger } from '@lark-apaas/client-toolkit/logger';

type SherpaModule = {
  setStatus?: (status: string) => void;
  locateFile?: (path: string, scriptDirectory?: string) => string;
  onRuntimeInitialized?: () => void;
  onAbort?: (reason: unknown) => void;
};
type SherpaRecognizer = any;
type SherpaStream = any;

export type SherpaAsrLoadStage =
  | 'idle'
  | 'loading_binding'
  | 'loading_runtime'
  | 'initializing_recognizer'
  | 'ready'
  | 'error';

export interface SherpaAsrLoadState {
  stage: SherpaAsrLoadStage;
  message: string;
  error?: string;
}

let moduleInstance: SherpaModule | null = null;
let moduleLoading: Promise<SherpaModule> | null = null;
let recognizerInstance: SherpaRecognizer | null = null;
let recognizerLoading: Promise<SherpaRecognizer> | null = null;
let loadState: SherpaAsrLoadState = {
  stage: 'idle',
  message: '本地语音模型尚未加载',
};

const ASR_BINDING_JS_URL = asrBindingJsUrl;
const WASM_RUNTIME_JS_URL = wasmRuntimeJsUrl;

function resolveSiblingAssetUrl(entryUrl: string, fileName: string): string {
  try {
    return new URL(fileName, new URL(entryUrl, window.location.href)).toString();
  } catch {
    return fileName;
  }
}

// 通过 Vite ?url 注入的方式获取带 hash 的资源路径，防止 CDN 404
const WASM_URL = wasmBinaryUrl;
const WASM_DATA_URL = wasmDataUrl;

const loadStateListeners = new Set<(state: SherpaAsrLoadState) => void>();

function emitLoadState(
  stage: SherpaAsrLoadStage,
  message: string,
  error?: string,
): void {
  loadState = { stage, message, error };
  loadStateListeners.forEach((listener) => listener(loadState));
  if (stage === 'error') {
    logger.error(`[SherpaASR] ${message}`, error ?? '');
    return;
  }
  logger.info(`[SherpaASR] ${message}`);
}

function logSherpaDebug(message: string, details?: unknown): void {
  if (details === undefined) {
    logger.info(`[SherpaASR][debug] ${message}`);
    return;
  }
  logger.info(`[SherpaASR][debug] ${message}`, details);
}

function rewriteEsmScriptForBlob(code: string, sourceUrl: string): string {
  let rewritten = code.replace(
    "var Module = typeof Module != 'undefined' ? Module : {};",
    "var Module = globalThis.Module || {}; globalThis.Module = Module;",
  );

  rewritten = rewritten.replace(/import\s+.*?logger.*?\s+from\s+['"][^'"]+['"];?/g, '');

  rewritten = rewritten.replace(
    /(from\s+['"])(\/[^'"]+)(['"])/g,
    (_match, prefix, specifier, suffix) =>
      `${prefix}${new URL(specifier, window.location.origin).toString()}${suffix}`,
  );

  rewritten = rewritten.replace(
    /(import\s+['"])(\/[^'"]+)(['"])/g,
    (_match, prefix, specifier, suffix) =>
      `${prefix}${new URL(specifier, window.location.origin).toString()}${suffix}`,
  );

  return `${rewritten}\n//# sourceURL=${sourceUrl}`;
}

export function subscribeSherpaAsrLoadState(
  listener: (state: SherpaAsrLoadState) => void,
): () => void {
  loadStateListeners.add(listener);
  listener(loadState);
  return () => {
    loadStateListeners.delete(listener);
  };
}

function updateStatusFromRuntime(status: string): void {
  logSherpaDebug('runtime 状态更新', { status });

  if (!status) {
    emitLoadState('ready', '本地语音模型加载完成');
    return;
  }

  if (status === 'Running...') {
    emitLoadState('initializing_recognizer', '模型已下载，正在初始化识别器');
    return;
  }

  const downloadMatch = status.match(/Downloading data... \((\d+)\/(\d+)\)/);
  if (downloadMatch) {
    const downloaded = Number(downloadMatch[1]);
    const total = Number(downloadMatch[2]);
    const percent =
      total === 0 ? 0 : Math.max(0, Math.min(99, Math.round((downloaded / total) * 100)));
    emitLoadState(
      'loading_runtime',
      `正在下载本地语音模型 ${percent}% (${(downloaded / 1024 / 1024).toFixed(1)}MB/${(
        total / 1024 / 1024
      ).toFixed(1)}MB)`,
    );
    return;
  }

  emitLoadState('loading_runtime', status);
}

async function tryLoadScript(url: string): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const existing = document.querySelector(
      `script[data-sherpa-src="${url}"]`,
    ) as HTMLScriptElement | null;

    if (existing) {
      if (existing.dataset.loaded === 'true') {
        resolve();
        return;
      }

      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener(
        'error',
        () => reject(new Error(`加载脚本失败: ${url}`)),
        { once: true },
      );
      return;
    }

    void (async () => {
      try {
        const response = await fetch(url, { credentials: 'same-origin' });
        if (!response.ok) {
          throw new Error(`加载脚本失败: ${url} (HTTP ${response.status})`);
        }

        const code = await response.text();
        const snippet = code.slice(0, 200).replace(/\s+/g, ' ').trim();
        const esmSyntaxPattern = /(^|\n)\s*(import|export)\s/m;
        const htmlPattern = /<(?:!doctype|html|head|body|script)\b/i;
        const isEsmScript = esmSyntaxPattern.test(code);

        if (htmlPattern.test(code.slice(0, 500))) {
          throw new Error(`脚本请求返回了 HTML 而不是 JS: ${url} snippet=${snippet}`);
        }

        if (url === ASR_BINDING_JS_URL && code.indexOf('createOnlineRecognizer') < 0) {
          throw new Error(
            `绑定脚本内容异常，未找到 createOnlineRecognizer: ${url} snippet=${snippet}`,
          );
        }

        const script = document.createElement('script');
        script.async = true;
        if (isEsmScript) {
          script.type = 'module';
          logSherpaDebug('检测到 ESM 脚本，按 module 方式执行', { url });
          const rewrittenCode = rewriteEsmScriptForBlob(code, url);
          const blob = new Blob([rewrittenCode], { type: 'text/javascript' });
          const blobUrl = URL.createObjectURL(blob);
          script.src = blobUrl;
          script.dataset.blobUrl = blobUrl;
        } else {
          const blob = new Blob(
            [`${code}\n//# sourceURL=${url}`],
            { type: 'text/javascript' },
          );
          const blobUrl = URL.createObjectURL(blob);
          script.src = blobUrl;
          script.dataset.blobUrl = blobUrl;
        }
        script.dataset.sherpaSrc = url;
        script.onload = () => {
          if (script.dataset.blobUrl) {
            URL.revokeObjectURL(script.dataset.blobUrl);
            delete script.dataset.blobUrl;
          }
          script.dataset.loaded = 'true';
          resolve();
        };
        script.onerror = () => {
          if (script.dataset.blobUrl) {
            URL.revokeObjectURL(script.dataset.blobUrl);
            delete script.dataset.blobUrl;
          }
          script.remove();
          reject(new Error(`加载脚本失败: ${url}`));
        };
        document.head.appendChild(script);
      } catch (error) {
        reject(error instanceof Error ? error : new Error(String(error)));
      }
    })();
  });
}

async function loadBrowserScript(url: string): Promise<void> {
  const startedAt = performance.now();
  logSherpaDebug('尝试加载浏览器脚本', { url });
  await tryLoadScript(url);
  logSherpaDebug('浏览器脚本加载完成', {
    url,
    durationMs: Math.round(performance.now() - startedAt),
  });
}

async function loadSherpaModule(): Promise<SherpaModule> {
  if (moduleInstance) return moduleInstance;
  if (moduleLoading) return moduleLoading;

  moduleLoading = (async () => {
    emitLoadState('loading_binding', '正在加载本地语音识别绑定');
    await loadBrowserScript(ASR_BINDING_JS_URL);

    emitLoadState('loading_runtime', '正在加载本地语音运行时');
    logSherpaDebug('准备加载 browser runtime', {
      runtimeJs: WASM_RUNTIME_JS_URL,
      wasm: WASM_URL,
      data: WASM_DATA_URL,
    });

    const runtimeStartedAt = performance.now();
    const runtimeModule = ((globalThis as any).Module ||= {}) as SherpaModule;

    const moduleReady = new Promise<SherpaModule>((resolve, reject) => {
      runtimeModule.locateFile = (path: string) => {
        if (path.endsWith('.wasm')) {
          logSherpaDebug('browser runtime 请求 wasm 文件', {
            requested: path,
            resolved: WASM_URL,
          });
          return WASM_URL;
        }

        if (path.endsWith('.data')) {
          logSherpaDebug('browser runtime 请求 data 文件', {
            requested: path,
            resolved: WASM_DATA_URL,
          });
          return WASM_DATA_URL;
        }

        logSherpaDebug('browser runtime 请求附属文件', { requested: path });
        return path;
      };

      runtimeModule.setStatus = (status: string) => {
        updateStatusFromRuntime(status);
      };

      runtimeModule.onRuntimeInitialized = () => {
        moduleInstance = runtimeModule;
        logSherpaDebug('browser runtime 初始化完成', {
          durationMs: Math.round(performance.now() - runtimeStartedAt),
        });
        resolve(runtimeModule);
      };

      runtimeModule.onAbort = (reason: unknown) => {
        reject(
          new Error(
            typeof reason === 'string' ? reason : 'browser runtime 初始化中止',
          ),
        );
      };
    });

    await loadBrowserScript(WASM_RUNTIME_JS_URL);
    return moduleReady;
  })();

  return moduleLoading;
}

async function createRecognizer(mod: SherpaModule): Promise<SherpaRecognizer> {
  const recognizerStartedAt = performance.now();
  const createOnlineRecognizer = (globalThis as any).createOnlineRecognizer;

  if (typeof createOnlineRecognizer !== 'function') {
    throw new Error('浏览器版 createOnlineRecognizer 未加载成功');
  }

  logSherpaDebug('开始创建浏览器版识别器');
  const recognizer = createOnlineRecognizer(mod);
  logSherpaDebug('识别器创建完成', {
    durationMs: Math.round(performance.now() - recognizerStartedAt),
  });
  emitLoadState('ready', '本地语音模型加载完成');
  return recognizer;
}

async function getSharedRecognizer(): Promise<SherpaRecognizer> {
  if (recognizerInstance) {
    return recognizerInstance;
  }

  if (recognizerLoading) {
    return recognizerLoading;
  }

  recognizerLoading = (async () => {
    const mod = await loadSherpaModule();
    emitLoadState('initializing_recognizer', '正在初始化本地语音识别器');
    const recognizer = await createRecognizer(mod);
    recognizerInstance = recognizer;
    return recognizer;
  })();

  try {
    return await recognizerLoading;
  } finally {
    recognizerLoading = null;
  }
}

export async function preloadSherpaAsr(): Promise<void> {
  logSherpaDebug('收到预加载请求');
  await getSharedRecognizer();
}

export class SherpaOnnxAsrClient implements TeleprompterAsrClient {
  private audioContext: AudioContext | null = null;
  private mediaStream: MediaStream | null = null;
  private processor: ScriptProcessorNode | null = null;
  private isRunning = false;
  private recognizer: SherpaRecognizer | null = null;
  private stream: SherpaStream | null = null;
  private callbacks: {
    onPartial: (text: string) => void;
    onFinal: (text: string) => void;
    onRms: (rms: number) => void;
    onTelemetry?: (sample: AsrLatencySample) => void;
  } | null = null;

  async start(
    onPartial: (text: string) => void,
    onFinal: (text: string) => void,
    onRms: (rms: number) => void,
    onTelemetry?: (sample: AsrLatencySample) => void,
  ): Promise<void> {
    if (this.isRunning) return;

    this.callbacks = { onPartial, onFinal, onRms, onTelemetry };
    logSherpaDebug('开始启动本地 ASR');

    if (window.isSecureContext === false) {
      throw new Error(
        'Microphone access requires a secure (HTTPS) connection.',
      );
    }

    if (!navigator.mediaDevices?.getUserMedia) {
      throw new Error(
        'Your browser does not support microphone access.',
      );
    }

    try {
      this.recognizer = await getSharedRecognizer();
      this.stream = this.recognizer.createStream();
      logSherpaDebug('识别流创建完成');
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      emitLoadState('error', '本地语音识别器初始化失败', msg);
      throw new Error(`本地 ASR 引擎初始化失败: ${msg}`);
    }

    try {
      logSherpaDebug('开始申请麦克风权限');
      this.mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          channelCount: 1,
          echoCancellation: false,
          noiseSuppression: false,
          autoGainControl: false,
        },
      });
      logSherpaDebug('麦克风权限申请成功', {
        tracks: this.mediaStream.getTracks().length,
      });
    } catch (error: any) {
      this.cleanup();
      const detail = `(${error.name}: ${error.message})`;
      throw new Error(`麦克风访问失败 ${detail}`);
    }

    try {
      this.audioContext = new AudioContext({ sampleRate: 16000 });
      logSherpaDebug('AudioContext 已创建', {
        state: this.audioContext.state,
        sampleRate: this.audioContext.sampleRate,
      });
      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume();
        logSherpaDebug('AudioContext 已恢复', {
          state: this.audioContext.state,
        });
      }

      const source = this.audioContext.createMediaStreamSource(
        this.mediaStream,
      );
      this.processor = this.audioContext.createScriptProcessor(4096, 1, 1);

      let lastPartialText = '';

        this.processor.onaudioprocess = (e) => {
          if (!this.isRunning || !this.recognizer || !this.stream) return;

          const float32 = new Float32Array(
            e.inputBuffer.getChannelData(0),
          );

          const rmsValue = Math.sqrt(
            float32.reduce((s, v) => s + v * v, 0) / float32.length,
          );
          this.callbacks?.onRms(Number(rmsValue.toFixed(3)));

          this.stream.acceptWaveform(16000, float32);

          while (this.recognizer.isReady(this.stream)) {
            this.recognizer.decode(this.stream);
          }

          const isEndpoint = this.recognizer.isEndpoint(this.stream);
          const result = this.recognizer.getResult(this.stream);

          if (result.text && result.text !== lastPartialText) {
            lastPartialText = result.text;
            this.callbacks?.onPartial(result.text);
          }

          if (isEndpoint) {
            if (lastPartialText) {
              this.callbacks?.onFinal(lastPartialText);
              lastPartialText = '';
            }
            this.recognizer.reset(this.stream);
          }
        };

      source.connect(this.processor);
      this.processor.connect(this.audioContext.destination);
      this.isRunning = true;

      logger.info('[SherpaASR] Started listening');
      logSherpaDebug('本地 ASR 已开始监听音频流');
    } catch (error) {
      emitLoadState(
        'error',
        '本地音频处理链初始化失败',
        error instanceof Error ? error.message : String(error),
      );
      this.cleanup();
      throw error;
    }
  }

  async stop(): Promise<void> {
    if (!this.isRunning) return;
    this.isRunning = false;
    logSherpaDebug('收到停止本地 ASR 请求');
    this.cleanup();
    logger.info('[SherpaASR] Stopped');
  }

  private cleanup(): void {
    if (this.processor) {
      this.processor.disconnect();
      this.processor = null;
    }
    if (this.audioContext) {
      try {
        this.audioContext.close();
      } catch {
        // ignore
      }
      this.audioContext = null;
    }
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach((t) => t.stop());
      this.mediaStream = null;
    }
    if (this.stream) {
      this.stream.free();
      this.stream = null;
    }
    this.recognizer = null;
    this.callbacks = null;
  }
}
