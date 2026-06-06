
/**
 * Feishu ASR Client for streaming speech-to-text.
 */
export interface FeishuConfig {
  appId: string;
  appSecret: string;
  baseUrl: string;
  engineType: string;
}

export class FeishuASRClient {
  private config: FeishuConfig;
  private token: string | null = null;
  private tokenExpiry: number = 0;
  private streamId: string = '';
  private sequenceId: number = 0;
  private isRunning: boolean = false;
  private audioContext: AudioContext | null = null;
  private mediaStream: MediaStream | null = null;
  private processor: ScriptProcessorNode | null = null;

  constructor(config: FeishuConfig) {
    this.config = config;
  }

  async testConnection(): Promise<{ success: boolean; message: string }> {
    try {
      await this.getAccessToken();
      return { success: true, message: 'Successfully connected to Feishu API' };
    } catch (error) {
      return { success: false, message: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  private async getAccessToken(): Promise<string> {
    if (this.token && Date.now() < this.tokenExpiry - 120000) {
      return this.token;
    }

    console.log(`[FeishuASR] Fetching new access token from: ${this.config.baseUrl}/open-apis/auth/v3/tenant_access_token/internal`);
    const response = await fetch(`${this.config.baseUrl}/open-apis/auth/v3/tenant_access_token/internal`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({
        app_id: this.config.appId,
        app_secret: this.config.appSecret,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`[FeishuASR] Token HTTP Error: ${response.status}`, errorText);
      throw new Error(`Failed to get Feishu access token: HTTP ${response.status}`);
    }

    const data = await response.json();
    if (data.code !== 0) {
      console.error('[FeishuASR] Token error:', data.code, data.msg);
      throw new Error(`Failed to get Feishu access token: ${data.msg}`);
    }

    console.log('[FeishuASR] Token retrieved successfully');
    this.token = data.tenant_access_token;
    this.tokenExpiry = Date.now() + data.expire * 1000;
    return this.token!;
  }

  async start(onPartial: (text: string) => void, onFinal: (text: string) => void, onRms: (rms: number) => void) {
    if (this.isRunning) return;
    this.isRunning = true;
    this.streamId = Math.random().toString(36).substring(2, 10) + Math.random().toString(36).substring(2, 10); // Ensure 16 chars
    this.sequenceId = 0;
    let isFirstPacket = true;

    if (window.isSecureContext === false) {
      this.isRunning = false;
      throw new Error('Microphone access requires a secure (HTTPS) connection. Please check your URL.');
    }

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.isRunning = false;
      throw new Error('Your browser does not support microphone access or it is blocked by security settings.');
    }

    try {
      this.mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (error: any) {
      this.isRunning = false;
      console.error('getUserMedia error:', error);
      
      const errorDetails = `(${error.name}: ${error.message})`;
      
      if (error.name === 'NotFoundError' || error.name === 'DevicesNotFoundError') {
        // Try to enumerate devices to see if any audio input exists
        let hasAudio = false;
        try {
          const devices = await navigator.mediaDevices.enumerateDevices();
          hasAudio = devices.some(d => d.kind === 'audioinput');
        } catch (e) {
          // Ignore enumeration errors
        }
        
        if (!hasAudio) {
          throw new Error(`No microphone detected ${errorDetails}. Please plug in a microphone and try again.`);
        }
        throw new Error(`Microphone not found ${errorDetails}. Please check your device connection or browser permissions.`);
      } else if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
        throw new Error(`Microphone access denied ${errorDetails}. Please grant permission in your browser.`);
      } else if (error.name === 'NotReadableError' || error.name === 'TrackStartError') {
        throw new Error(`Microphone is already in use by another application ${errorDetails}.`);
      } else {
        throw new Error(`Microphone error ${errorDetails}: ${error.message || 'Unknown error'}`);
      }
    }

    try {
      this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 16000 });
      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume();
      }
      console.log('[FeishuASR] AudioContext state:', this.audioContext.state);

      const source = this.audioContext.createMediaStreamSource(this.mediaStream);
      
      // Using ScriptProcessorNode for simplicity in this environment
      this.processor = this.audioContext.createScriptProcessor(4096, 1, 1);
      
      let audioBuffer: Int16Array[] = [];
      let bufferSize = 0;
      const CHUNK_SIZE = 3200; // 200ms at 16kHz
      let silenceChunks = 0;
      let hasSpoken = false;
      const SILENCE_THRESHOLD = 0.005; // Lowered from 0.01
      const MAX_SILENCE_CHUNKS = 15; // 3 seconds of silence
      const MAX_SEQUENCE = 500; // Force end after ~100 seconds

      console.log('[FeishuASR] Processor starting...');

      this.processor.onaudioprocess = (e) => {
        if (!this.isRunning) return;
        const inputData = e.inputBuffer.getChannelData(0);
        
        // Calculate RMS for silence detection
        let sum = 0;
        for (let i = 0; i < inputData.length; i++) {
          sum += inputData[i] * inputData[i];
        }
        const rms = Math.sqrt(sum / inputData.length);
        onRms(rms);

        if (rms > SILENCE_THRESHOLD) {
          if (!hasSpoken) console.log('[FeishuASR] Speech detected (RMS > threshold)');
          hasSpoken = true;
          silenceChunks = 0;
        } else {
          silenceChunks++;
        }

        // Convert to Int16 PCM
        const pcmData = new Int16Array(inputData.length);
        for (let i = 0; i < inputData.length; i++) {
          pcmData[i] = Math.max(-1, Math.min(1, inputData[i])) * 0x7FFF;
        }

        audioBuffer.push(pcmData);
        bufferSize += pcmData.length;

        if (bufferSize >= CHUNK_SIZE) {
          const chunk = new Int16Array(bufferSize);
          let offset = 0;
          for (const buf of audioBuffer) {
            chunk.set(buf, offset);
            offset += buf.length;
          }
          audioBuffer = [];
          bufferSize = 0;

          // Check for end of sentence
          if ((hasSpoken && silenceChunks >= MAX_SILENCE_CHUNKS) || this.sequenceId >= MAX_SEQUENCE) {
            this.sendChunk(chunk, 2, onPartial, onFinal);
            // Reset for next stream
            this.streamId = Math.random().toString(36).substring(2, 10) + Math.random().toString(36).substring(2, 10);
            this.sequenceId = 0;
            isFirstPacket = true;
            hasSpoken = false;
            silenceChunks = 0;
          } else {
            const action = isFirstPacket ? 1 : 0;
            this.sendChunk(chunk, action, onPartial, onFinal);
            isFirstPacket = false;
          }
        }
      };

      source.connect(this.processor);
      this.processor.connect(this.audioContext.destination);

    } catch (error) {
      this.isRunning = false;
      throw error;
    }
  }

  private async sendChunk(chunk: Int16Array, action: number, onPartial: (text: string) => void, onFinal: (text: string) => void) {
    try {
      const token = await this.getAccessToken();
      const base64Audio = btoa(String.fromCharCode(...new Uint8Array(chunk.buffer)));
      
      const url = `${this.config.baseUrl}/open-apis/speech_to_text/v1/speech/stream_recognize`;
      console.log(`[FeishuASR] Sending chunk to ${url}: action=${action}, sequence=${this.sequenceId}, size=${chunk.length}`);

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: JSON.stringify({
          speech: { speech: base64Audio },
          config: {
            stream_id: this.streamId,
            sequence_id: this.sequenceId++,
            action: action,
            format: 'pcm',
            engine_type: this.config.engineType,
          },
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[FeishuASR] ASR HTTP Error: ${response.status}`, errorText);
        return;
      }

      const data = await response.json();
      if (data.code === 0 && data.data) {
        const text = data.data.recognition_text;
        console.log(`[FeishuASR] Received: "${text}" (action=${action})`);
        if (action === 2) {
          onFinal(text);
        } else {
          onPartial(text);
        }
      } else {
        console.error('[FeishuASR] API Error:', data.code, data.msg, data);
      }
    } catch (error) {
      console.error('[FeishuASR] Network/Fetch Error:', error);
    }
  }

  async stop() {
    if (!this.isRunning) return;
    this.isRunning = false;

    // Send final chunk with action=2
    await this.sendChunk(new Int16Array(0), 2, () => {}, () => {});

    if (this.processor) {
      this.processor.disconnect();
      this.processor = null;
    }
    if (this.audioContext) {
      await this.audioContext.close();
      this.audioContext = null;
    }
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop());
      this.mediaStream = null;
    }
  }
}
