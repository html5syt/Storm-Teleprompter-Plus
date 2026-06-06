import { motion } from 'framer-motion';
import { Clock, Edit3, FileText, Play, Trash2 } from 'lucide-react';

import type { Script } from '@/components/teleprompter/types';

interface ArticleCardListProps {
  scripts: Script[];
  onPlay: (scriptId: string) => void;
  onEdit: (scriptId: string) => void;
  onDelete: (scriptId: string, event: React.MouseEvent<HTMLButtonElement>) => void;
  canEditScript?: (script: Script) => boolean;
  canDeleteScript?: (script: Script) => boolean;
}

function stripHtml(html: string): string {
  if (!html.includes('<')) return html;
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  return tmp.textContent || tmp.innerText || '';
}

export const ArticleCardList: React.FC<ArticleCardListProps> = ({
  scripts,
  onPlay,
  onEdit,
  onDelete,
  canEditScript,
  canDeleteScript,
}) => {
  return (
    <div
      className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3"
      data-ai-section-type="card-list"
    >
      {scripts.map((script) => (
        (() => {
          const canEdit = canEditScript ? canEditScript(script) : true;
          const canDelete = canDeleteScript ? canDeleteScript(script) : true;
          const showActions = canEdit || canDelete;

          return (
        <motion.div
          key={script.id}
          onClick={() => onPlay(script.id)}
          className="group relative flex h-full cursor-pointer flex-col overflow-hidden rounded-3xl border border-neutral-800/50 bg-neutral-900/40 p-6 transition-all duration-300 hover:-translate-y-1 hover:border-yellow-500/40 hover:shadow-lg hover:shadow-yellow-500/5"
        >
          <div className="mb-4 flex items-start justify-between gap-3">
            <div className="rounded-lg bg-neutral-800 p-2 text-neutral-400 transition-colors group-hover:text-yellow-500">
              <FileText size={20} />
            </div>
            {showActions ? (
              <div className="flex flex-wrap items-center justify-end gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                {canEdit && (
                  <button
                    type="button"
                    title="编辑稿件"
                    aria-label="编辑稿件"
                    data-ai-section-type="button"
                    onClick={(event) => {
                      event.stopPropagation();
                      onEdit(script.id);
                    }}
                    className="rounded-lg p-2 text-neutral-400 hover:bg-neutral-800 hover:text-white"
                  >
                    <Edit3 size={16} />
                  </button>
                )}
                {canDelete && (
                  <button
                    type="button"
                    title="删除稿件"
                    aria-label="删除稿件"
                    data-ai-section-type="button"
                    onClick={(event) => onDelete(script.id, event)}
                    className="rounded-lg p-2 text-neutral-400 hover:bg-red-500/10 hover:text-red-400"
                  >
                    <Trash2 size={16} />
                  </button>
                )}
              </div>
            ) : null}
          </div>

          <h3 className="mb-2 truncate text-lg font-semibold text-white transition-colors group-hover:text-yellow-500">{script.title}</h3>

          <p className="mb-6 flex-1 line-clamp-3 text-sm leading-relaxed text-neutral-500">
            {stripHtml(script.content) || <span className="italic text-neutral-700">无内容...</span>}
          </p>

          <div className="mt-auto border-t border-neutral-800/50 pt-4">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2 font-mono text-[10px] uppercase tracking-wider text-neutral-600">
                <Clock size={12} />
                {new Date(script.lastModified).toLocaleDateString()}
              </div>
              <div className="translate-x-4 text-xs font-bold text-yellow-500 opacity-0 transition-all group-hover:translate-x-0 group-hover:opacity-100">
                <span className="inline-flex items-center gap-2">
                  开始提词 <Play size={14} fill="currentColor" />
                </span>
              </div>
            </div>
          </div>

          <div className="absolute -right-10 -bottom-10 h-32 w-32 rounded-full bg-yellow-500/5 blur-[60px] transition-all group-hover:bg-yellow-500/10" />
        </motion.div>
          );
        })()
      ))}
    </div>
  );
};
