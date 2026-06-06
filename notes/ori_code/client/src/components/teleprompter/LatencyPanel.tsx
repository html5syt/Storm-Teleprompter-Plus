import { Activity, Clock3, Send, Wifi, XCircle } from 'lucide-react';

import type { AsrLatencySnapshot } from '@/lib/teleprompter/telemetry';

interface LatencyPanelProps {
  snapshot: AsrLatencySnapshot;
}

const metricClassName =
  'rounded-xl border border-white/10 bg-black/40 px-3 py-2';

export const LatencyPanel: React.FC<LatencyPanelProps> = ({ snapshot }) => {
  const latest = snapshot.latest;
  const latestQueue =
    latest?.sentAt != null ? latest.sentAt - latest.queuedAt : 0;
  const latestNetwork =
    latest?.responseAt != null && latest.sentAt != null
      ? latest.responseAt - latest.sentAt
      : 0;
  const latestEndToEnd =
    latest?.responseAt != null
      ? latest.responseAt - latest.captureStartedAt
      : 0;

  return (
    <div className="px-3 py-2 bg-black/60 backdrop-blur-md border border-white/10 rounded-lg flex flex-col gap-2 min-w-[280px]">
      <div className="flex items-center gap-2 text-[10px] font-bold text-white/40 uppercase tracking-widest">
        <Activity size={10} /> Latency Monitor
      </div>
      <div className="grid grid-cols-2 gap-2" data-ai-section-type="card-stat">
        <div className={metricClassName}>
          <div className="flex items-center gap-2 text-[10px] text-white/40 uppercase tracking-widest">
            <Send size={10} /> Queue
          </div>
          <div className="mt-1 text-sm font-mono text-yellow-400">
            {snapshot.avgQueueMs}ms
          </div>
        </div>
        <div className={metricClassName}>
          <div className="flex items-center gap-2 text-[10px] text-white/40 uppercase tracking-widest">
            <Wifi size={10} /> Network
          </div>
          <div className="mt-1 text-sm font-mono text-yellow-400">
            {snapshot.avgNetworkMs}ms
          </div>
        </div>
        <div className={metricClassName}>
          <div className="flex items-center gap-2 text-[10px] text-white/40 uppercase tracking-widest">
            <Clock3 size={10} /> E2E
          </div>
          <div className="mt-1 text-sm font-mono text-yellow-400">
            {snapshot.avgEndToEndMs}ms
          </div>
        </div>
        <div className={metricClassName}>
          <div className="flex items-center gap-2 text-[10px] text-white/40 uppercase tracking-widest">
            <XCircle size={10} /> Failed
          </div>
          <div className="mt-1 text-sm font-mono text-red-400">
            {snapshot.failedCount}
          </div>
        </div>
      </div>
      <div className="rounded-xl border border-white/10 bg-black/30 px-3 py-2">
        <div className="flex flex-wrap justify-between gap-2 text-[10px] text-white/40 uppercase tracking-widest">
          <span>Latest Seq {latest?.sequenceId ?? '--'}</span>
          <span>Status {latest?.status ?? 'idle'}</span>
        </div>
        <div className="mt-2 flex flex-wrap gap-4 text-[11px] font-mono">
          <span className="text-yellow-400">Q {latestQueue}ms</span>
          <span className="text-yellow-400">N {latestNetwork}ms</span>
          <span className="text-yellow-400">E {latestEndToEnd}ms</span>
        </div>
        <div className="mt-2 flex flex-wrap gap-4 text-[10px] text-white/45">
          <span>pending {snapshot.pendingCount}</span>
          <span>done {snapshot.completedCount}</span>
          <span>{latest?.recognitionText ?? '等待识别结果'}</span>
        </div>
      </div>
    </div>
  );
};
