import type { AsrLatencySample } from '@/lib/teleprompter/telemetry';
import type { TeleprompterAsrClient } from '@/lib/teleprompter/asr-client';
import { logger } from '@lark-apaas/client-toolkit/logger';

type SherpaOnlineStream = {
  acceptWaveform: (sampleRate: number, samples: Float32Array) => void;
  free?: () => void;
};

type SherpaOnlineRecognizer = {
  createStream: () => SherpaOnlineStream;
  isReady: (stream: SherpaOnlineStream) => boolean;
  decode: (stream: SherpaOnlineStream) => void;
  isEndpoint: (stream: SherpaOnlineStream) => boolean;
  reset: (stream: SherpaOnlineStream) => void;
  getResult: (stream: SherpaOnlineStream) => { text?: string };
};

type SherpaWasmModule = {
  ready?: Promise<SherpaWasmModule>;
};

type SherpaWasmFactory = {
  (moduleArg?: Record<string, unknown>): SherpaWasmModule | Promise<SherpaWasmModule>;
}

const MODEL_BASE_PATH = '/models/sherpa-zh-14m-int8';
const WASM_PATH = '/asr/sherpa-onnx-wasm-nodejs.wasm';

function getWasmFactory(): SherpaWasmFactory | undefined {
  return (window as unknown as Record<string, unknown>)
    .Module as SherpaWasmFactory | undefined;
}

function getCreateOnlineRecognizer(): ((
  moduleInstance: SherpaWasmModule,
  config: Record<string, unknown>,
) => SherpaOnlineRecognizer) | undefined {
  return (window as unknown as Record<string, unknown>)
    .createOnlineRecognizer as
    | ((
        moduleInstance: SherpaWasmModule,
        config: Record<string, unknown>,
      ) => SherpaOnlineRecognizer)
    | undefined;
}

export class LocalBrowserASRClient implements TeleprompterAsrClient {
  private static modulePromise: Promise<SherpaWasmModule> | null = null;
  private static recognizerPromise: Promise<SherpaOnlineRecognizer> | null =
    null;

  private audioContext: AudioContext | null = null;
  private mediaStream: MediaStream | null = null;
  private processor: ScriptProcessorNode | null = null;
  private stream: SherpaOnlineStream | null = null;
  private isRunning = false;
  private currentTranscript = '';

  private static async getModule(): Promise<SherpaWasmModule> {
    if (!LocalBrowserASRClient.modulePromise) {
      const createWasmModule = getWasmFactory();
      if (!createWasmModule) {
        throw new Error(
          'sherpa-onnx WASM module not loaded. Ensure the script tags are present in index.html.',
        );
      }

      const moduleResult = createWasmModule({
        locateFile: (path: string) =>
          path.endsWith('.wasm') ? WASM_PATH : path,
        print: () => undefined,
        printErr: (text: string) => logger.error(text),
      });

      LocalBrowserASRClient.modulePromise = Promise.resolve(
        moduleResult,
      ).then((mod: SherpaWasmModule) => {
        if (mod.ready) {
          return mod.ready;
        }
        return mod;
      });
    }

    return LocalBrowserASRClient.modulePromise;
  }

  private static async getRecognizer(): Promise<SherpaOnlineRecognizer> {
    if (!LocalBrowserASRClient.recognizerPromise) {
      LocalBrowserASRClient.recognizerPromise =
        LocalBrowserASRClient.getModule().then((moduleInstance) => {
          const createRecognizer = getCreateOnlineRecognizer();
          if (!createRecognizer) {
            throw new Error(
              'sherpa-onnx ASR module not loaded. Ensure the script tags are present in index.html.',
            );
          }

          return createRecognizer(moduleInstance, {
            featConfig: {
              sampleRate: 16000,
              featureDim: 80,
            },
            modelConfig: {
              transducer: {
                encoder: `${MODEL_BASE_PATH}/encoder-epoch-99-avg-1.int8.onnx`,
                decoder: `${MODEL_BASE_PATH}/decoder-epoch-99-avg-1.int8.onnx`,
                joiner: `${MODEL_BASE_PATH}/joiner-epoch-99-avg-1.int8.onnx`,
              },
              paraformer: {
                encoder: '',
                decoder: '',
              },
              zipformer2Ctc: {
                model: '',
              },
              nemoCtc: {
                model: '',
              },
              toneCtc: {
                model: '',
              },
              tokens: `${MODEL_BASE_PATH}/tokens.txt`,
              numThreads: 1,
              provider: 'cpu',
              debug: 0,
              modelType: '',
              modelingUnit: 'cjkchar',
              bpeVocab: '',
            },
            decodingMethod: 'greedy_search',
            maxActivePaths: 4,
            enableEndpoint: 1,
            rule1MinTrailingSilence: 2.4,
            rule2MinTrailingSilence: 1.2,
            rule3MinUtteranceLength: 20,
            hotwordsFile: '',
            hotwordsScore: 1.5,
            ctcFstDecoderConfig: {
              graph: '',
              maxActive: 3000,
            },
            ruleFsts: '',
            ruleFars: '',
          });
        });
    }

    return LocalBrowserASRClient.recognizerPromise;
  }

  async start(
    onPartial: (text: string) => void,
    onFinal: (text: string) => void,
    onRms: (rms: number) => void,
    onTelemetry?: (sample: AsrLatencySample) => void,
  ): Promise<void> {
    void onTelemetry;

    if (this.isRunning) {
      return;
    }

    if (window.isSecureContext === false) {
      throw new Error('本地语音识别需要在 HTTPS 或 localhost 环境下访问麦克风。');
    }

    if (!navigator.mediaDevices?.getUserMedia) {
      throw new Error('当前浏览器不支持麦克风访问。');
    }

    this.isRunning = true;
    this.currentTranscript = '';

    const recognizer = await LocalBrowserASRClient.getRecognizer();

    try {
      this.mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: true,
      });
      const AudioContextCtor =
        window.AudioContext ||
        (window as typeof window & { webkitAudioContext?: typeof AudioContext })
          .webkitAudioContext;

      if (!AudioContextCtor) {
        throw new Error('当前浏览器不支持 AudioContext。');
      }

      this.audioContext = new AudioContextCtor({ sampleRate: 16000 });
      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume();
      }

      const source = this.audioContext.createMediaStreamSource(this.mediaStream);
      this.processor = this.audioContext.createScriptProcessor(4096, 1, 1);
      this.stream = recognizer.createStream();

      this.processor.onaudioprocess = (event) => {
        if (!this.isRunning || !this.stream) {
          return;
        }

        const inputData = event.inputBuffer.getChannelData(0);
        let sum = 0;
        for (let i = 0; i < inputData.length; i += 1) {
          sum += inputData[i] * inputData[i];
        }
        onRms(Math.sqrt(sum / inputData.length));

        const samples = new Float32Array(inputData);
        this.stream.acceptWaveform(16000, samples);

        while (recognizer.isReady(this.stream)) {
          recognizer.decode(this.stream);
        }

        const result = recognizer.getResult(this.stream);
        const text = result.text?.trim() ?? '';
        if (text && text !== this.currentTranscript) {
          this.currentTranscript = text;
          onPartial(text);
        }

        if (recognizer.isEndpoint(this.stream)) {
          if (this.currentTranscript) {
            onFinal(this.currentTranscript);
            this.currentTranscript = '';
          }
          recognizer.reset(this.stream);
        }
      };

      source.connect(this.processor);
      this.processor.connect(this.audioContext.destination);
    } catch (error) {
      this.isRunning = false;
      await this.stop();
      throw error;
    }
  }

  async stop(): Promise<void> {
    this.isRunning = false;
    this.currentTranscript = '';

    if (this.processor) {
      this.processor.disconnect();
      this.processor.onaudioprocess = null;
      this.processor = null;
    }

    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach((track) => track.stop());
      this.mediaStream = null;
    }

    if (this.audioContext) {
      await this.audioContext.close();
      this.audioContext = null;
    }

    this.stream?.free?.();
    this.stream = null;
  }
}
