export interface AsrLatencySample {
  id: string;
  sequenceId: number;
  action: number;
  chunkDurationMs: number;
  captureStartedAt: number;
  queuedAt: number;
  sentAt?: number;
  responseAt?: number;
  recognitionText?: string;
  status: 'queued' | 'sent' | 'completed' | 'failed';
  errorMessage?: string;
}

export interface AsrLatencySnapshot {
  latest?: AsrLatencySample;
  samples: AsrLatencySample[];
  avgQueueMs: number;
  avgNetworkMs: number;
  avgEndToEndMs: number;
  pendingCount: number;
  completedCount: number;
  failedCount: number;
}

export const MAX_ASR_LATENCY_SAMPLES = 20;

const average = (values: number[]): number => {
  if (values.length === 0) {
    return 0;
  }

  return Math.round(
    values.reduce((sum, value) => sum + value, 0) / values.length,
  );
};

export const buildAsrLatencySnapshot = (
  samples: AsrLatencySample[],
): AsrLatencySnapshot => {
  const latest = samples[0];
  const completed = samples.filter((sample) => sample.status === 'completed');
  const failedCount = samples.filter((sample) => sample.status === 'failed').length;
  const pendingCount = samples.filter(
    (sample) => sample.status === 'queued' || sample.status === 'sent',
  ).length;

  const queueValues = completed
    .map((sample) => sample.sentAt && sample.queuedAt
      ? sample.sentAt - sample.queuedAt
      : 0)
    .filter((value) => value > 0);

  const networkValues = completed
    .map((sample) => sample.responseAt && sample.sentAt
      ? sample.responseAt - sample.sentAt
      : 0)
    .filter((value) => value > 0);

  const endToEndValues = completed
    .map((sample) => sample.responseAt
      ? sample.responseAt - sample.captureStartedAt
      : 0)
    .filter((value) => value > 0);

  return {
    latest,
    samples,
    avgQueueMs: average(queueValues),
    avgNetworkMs: average(networkValues),
    avgEndToEndMs: average(endToEndValues),
    pendingCount,
    completedCount: completed.length,
    failedCount,
  };
};
