import type { AsrLatencySample } from '@/lib/teleprompter/telemetry';

export interface TeleprompterAsrClient {
  start(
    onPartial: (text: string) => void,
    onFinal: (text: string) => void,
    onRms: (rms: number) => void,
    onTelemetry?: (sample: AsrLatencySample) => void,
  ): Promise<void>;

  stop(): Promise<void>;
}
