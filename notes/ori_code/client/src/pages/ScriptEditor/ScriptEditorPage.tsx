import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  ChevronLeft,
  Clock,
  FileText,
  Play,
  Search,
  Trash2,
} from 'lucide-react';
import { toast } from 'sonner';
import { logger } from '@lark-apaas/client-toolkit/logger';
import { showConfirm } from '@lark-apaas/client-toolkit';

import {
  createArticle,
  deleteArticle,
  getGlobalSettings,
  listArticles,
  updateArticle,
} from '@/api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  TiptapEditor,
  TiptapEditorContent,
} from '@/components/miaoda/tiptap-editor/tiptap-editor';
import { CompleteKit } from '@/components/miaoda/tiptap-editor/extensions/complete-kit';
import { FloatingToolbar } from '@/components/miaoda/tiptap-editor/components/floating-toolbar';
import {
  CREATE_TEMPLATE_URL,
  DEFAULT_APP_SETTINGS,
  GUIDE_URL,
} from '@/components/teleprompter/types';
import type { AppSettings, Script } from '@/components/teleprompter/types';
import {
  getTempScript,
  isTemporaryScriptId,
  removeTempScript,
  updateTempScript,
} from '@/lib/teleprompter/temp-script-store';

const EDITOR_DRAFT_KEY = 'script_editor_draft';

interface EditorDraft {
  title: string;
  content: string;
  savedAt: number;
}

function stripHtml(html: string): string {
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  return tmp.textContent || tmp.innerText || '';
}

function estimateReadTime(text: string): string {
  const charCount = text.length;
  if (charCount === 0) return '0 分 0 秒';
  const minutes = Math.floor(charCount / 300);
  const seconds = Math.floor((charCount % 300) / 5);
  if (minutes === 0) return `${seconds} 秒`;
  if (seconds === 0) return `${minutes} 分`;
  return `${minutes} 分 ${seconds} 秒`;
}

function formatLastEdit(time: number): string {
  const diff = Date.now() - time;
  if (diff < 60_000) return '刚刚';
  if (diff < 3600_000) return `${Math.floor(diff / 60_000)} 分钟前`;
  if (diff < 86400_000) return `${Math.floor(diff / 3600_000)} 小时前`;
  return new Date(time).toLocaleDateString();
}

const ScriptEditorPage = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isNew = id === 'new';

  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [script, setScript] = useState<Script | null>(null);
  const [loading, setLoading] = useState(!isNew);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [lastSavedAt, setLastSavedAt] = useState<number>(Date.now());
  const [appSettings, setAppSettings] = useState<AppSettings>(DEFAULT_APP_SETTINGS);
  const autoSaveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const editorContainerRef = useRef<HTMLDivElement>(null);

  const plainText = useMemo(() => stripHtml(content), [content]);
  const displayTitle = title.trim();
  const readTime = useMemo(() => estimateReadTime(plainText), [plainText]);
  const isTemporaryEditor = Boolean(script?.isTemporary);
  const isPersistedReadOnly =
    Boolean(script?.id) &&
    !script?.isTemporary &&
    appSettings.useTemporaryBrowserCreate;

  useEffect(() => {
    const loadRemoteAppSettings = async () => {
      try {
        const remoteSettings = await getGlobalSettings();
        setAppSettings({
          useTemporaryBrowserCreate: remoteSettings.useTemporaryBrowserCreate,
        });
      } catch (error) {
        logger.error('加载创建方式配置失败', error);
        setAppSettings(DEFAULT_APP_SETTINGS);
      }
    };

    void loadRemoteAppSettings();
  }, []);
  const editorPlaceholder = isTemporaryEditor
    ? '当前创建仅在网页内有效，关闭或刷新页面后会失效。建议先一键获取同款，再结合首页使用必看继续编辑。'
    : isPersistedReadOnly
      ? '当前已开启网页内临时创建，正式稿件仅支持查看和提词，不支持修改或删除。'
      : '请输入脚本文案';

  useEffect(() => {
    if (isNew) {
      const draftRaw = localStorage.getItem(EDITOR_DRAFT_KEY);
      if (draftRaw) {
        try {
          const draft: EditorDraft = JSON.parse(draftRaw);
          setTitle(draft.title);
          setContent(draft.content);
          setLastSavedAt(draft.savedAt);
        } catch {
          /* noop */
        }
      }
      setLoading(false);
      return;
    }

    const load = async () => {
      const tempScript = id ? getTempScript(id) : undefined;
      if (tempScript) {
        setScript(tempScript);
        setTitle(tempScript.title);
        setContent(tempScript.content);
        setLastSavedAt(tempScript.lastModified);
        setLoading(false);
        return;
      }

      if (id && isTemporaryScriptId(id)) {
        toast.error('当前临时稿件已失效，请重新创建');
        navigate('/', { replace: true });
        setLoading(false);
        return;
      }

      try {
        const response = await listArticles();
        const found = response.items.find((a) => a.id === id);
        if (!found) {
          toast.error('稿件不存在');
          navigate('/', { replace: true });
          return;
        }
        setScript({
          id: found.id,
          title: found.title,
          content: found.content,
          coverImage: found.coverImage,
          lastModified: new Date(found.updatedAt).getTime(),
        });
        setTitle(found.title);
        setContent(found.content);
        setLastSavedAt(new Date(found.updatedAt).getTime());
      } catch (err) {
        logger.error('加载稿件失败', err);
        toast.error('加载稿件失败');
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, [id, isNew, navigate]);

  const doAutoSave = useCallback(() => {
    if (script?.isTemporary && script.id) {
      const savedAt = Date.now();
      updateTempScript(script.id, {
        title: title.trim(),
        content,
        lastModified: savedAt,
      });
      setScript((current) =>
        current
          ? {
              ...current,
              title: title.trim(),
              content,
              lastModified: savedAt,
              isTemporary: true,
            }
          : current,
      );
      setLastSavedAt(savedAt);
      return;
    }

    if (isNew) {
      const draft: EditorDraft = {
        title,
        content,
        savedAt: Date.now(),
      };
      localStorage.setItem(EDITOR_DRAFT_KEY, JSON.stringify(draft));
      setLastSavedAt(draft.savedAt);
    }
  }, [isNew, title, content]);

  useEffect(() => {
    if (autoSaveTimerRef.current) clearTimeout(autoSaveTimerRef.current);
    autoSaveTimerRef.current = setTimeout(() => {
      doAutoSave();
    }, 3000);
    return () => {
      if (autoSaveTimerRef.current) clearTimeout(autoSaveTimerRef.current);
    };
  }, [title, content, doAutoSave]);

  const handleSave = async () => {
    if (isPersistedReadOnly) {
      toast.info('当前模式下，正式稿件仅支持查看和提词');
      return;
    }

    if (!title.trim() || !content.trim()) {
      toast.error('请填写标题和正文');
      return;
    }

    try {
      setSaving(true);
      if (script?.isTemporary && script.id) {
        const savedAt = Date.now();
        updateTempScript(script.id, {
          title: title.trim(),
          content: content.trim(),
          lastModified: savedAt,
        });
        setScript((current) =>
          current
            ? {
                ...current,
                title: title.trim(),
                content: content.trim(),
                lastModified: savedAt,
                isTemporary: true,
              }
            : current,
        );
        setLastSavedAt(savedAt);
        toast.success('临时稿件已保存到当前网页');
      } else if (isNew) {
        const result = await createArticle({
          title: title.trim(),
          content: content.trim(),
        });
        if (!result?.article?.id) {
          toast.error('创建稿件失败：返回数据异常');
          return;
        }
        const created = result.article;
        localStorage.removeItem(EDITOR_DRAFT_KEY);
        toast.success('稿件已创建');
        navigate(`/editor/${created.id}`, { replace: true });
      } else if (script?.id) {
        const updated = await updateArticle(script.id, {
          title: title.trim(),
          content: content.trim(),
        });
        setScript((prev) =>
          prev
            ? {
                ...prev,
                title: updated.title,
                content: updated.content,
                lastModified: new Date(updated.updatedAt).getTime(),
              }
            : prev,
        );
        setLastSavedAt(new Date(updated.updatedAt).getTime());
        toast.success('稿件已保存');
      }
    } catch (err) {
      logger.error('保存稿件失败', err);
      toast.error('保存失败');
    } finally {
      setSaving(false);
    }
  };

  const handleGoToPrompter = () => {
    const scriptId = script?.id;
    if (!scriptId) {
      toast.error('请先保存稿件');
      return;
    }
    navigate(`/?prompter=${scriptId}`);
  };

  const handleDelete = async () => {
    const scriptId = script?.id;
    if (!scriptId) return;
    if (isPersistedReadOnly) {
      toast.info('当前模式下，正式稿件不支持删除');
      return;
    }
    if (!await showConfirm('确定要删除这篇稿件吗？此操作不可恢复。')) return;
    setDeleting(true);
    try {
      if (script.isTemporary) {
        removeTempScript(scriptId);
        toast.success('临时稿件已删除');
      } else {
        await deleteArticle(scriptId);
        toast.success('稿件已删除');
      }
      navigate('/');
    } catch (err) {
      logger.error('删除稿件失败', err);
      toast.error('删除稿件失败');
    } finally {
      setDeleting(false);
    }
  };

  const handleBack = () => {
    navigate('/');
  };

  const handleSearchInContent = () => {
    if (!searchQuery.trim() || !editorContainerRef.current) return;
    const el = editorContainerRef.current.querySelector('.ProseMirror') as HTMLElement | null;
    if (!el) return;
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    const nodes: { node: Text; index: number }[] = [];
    let acc = '';
    let node: Node | null;
    while ((node = walker.nextNode())) {
      const textNode = node as Text;
      nodes.push({ node: textNode, index: acc.length });
      acc += textNode.textContent || '';
    }
    const idx = acc.indexOf(searchQuery);
    if (idx < 0) {
      toast.info('未找到匹配内容');
      return;
    }
    const target = nodes.find((n) => n.index <= idx && n.index + (n.node.textContent || '').length >= idx);
    if (target) {
      const range = document.createRange();
      range.setStart(target.node, idx - target.index);
      range.setEnd(target.node, idx - target.index + searchQuery.length);
      const sel = window.getSelection();
      sel?.removeAllRanges();
      sel?.addRange(range);
      const rect = range.getBoundingClientRect();
      el.scrollTop = rect.top - el.getBoundingClientRect().top + el.scrollTop - 100;
    }
  };

  if (loading) {
    return (
      <div className="flex h-screen w-screen items-center justify-center bg-[#0d0d0d] text-neutral-400">
        <div className="flex flex-col items-center gap-3">
          <FileText size={32} className="animate-pulse text-yellow-500" />
          <span className="text-sm">加载中...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-screen w-screen flex-col bg-[#0d0d0d] font-sans text-foreground">
      <header className="flex h-16 shrink-0 items-center justify-between border-b border-[#2e2e2e] bg-[#0d0d0d] px-6">
        <div className="flex items-center gap-4 min-w-0">
          <Button
            variant="ghost"
            size="icon"
            onClick={handleBack}
            className="shrink-0 rounded-full text-neutral-400 hover:bg-neutral-800 hover:text-white"
          >
            <ChevronLeft size={20} />
          </Button>
          <div className="min-w-0">
            <h1 className={`truncate text-base font-semibold ${displayTitle ? 'text-white' : 'text-neutral-600'}`}>
              {displayTitle || '请输入标题'}
            </h1>
            <div className="flex items-center gap-2 text-xs text-neutral-500">
              <span>上次编辑：{formatLastEdit(lastSavedAt)}</span>
              <span className="text-neutral-700">|</span>
              <span className="flex items-center gap-1">
                <Clock size={10} />
                读完预计：{readTime}
              </span>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="group relative hidden sm:block">
            <Search
              className="absolute top-1/2 left-3 -translate-y-1/2 text-neutral-600 transition-colors group-focus-within:text-yellow-500"
              size={16}
            />
            <Input
              placeholder="搜索"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleSearchInContent();
              }}
              className="w-48 rounded-full border-[#2e2e2e] bg-[#141414] py-1.5 pr-4 pl-9 text-sm text-white placeholder:text-neutral-600"
            />
          </div>

          <Button
            variant="outline"
            onClick={handleSave}
            disabled={isPersistedReadOnly || saving || !title.trim() || !plainText.trim()}
            className="h-9 rounded-full border-[#2e2e2e] bg-transparent px-5 text-sm text-neutral-200 hover:bg-neutral-800 hover:text-white disabled:opacity-40"
          >
            {saving ? '保存中...' : '保存'}
          </Button>

          <Button
            onClick={handleGoToPrompter}
            disabled={!script?.id || saving || deleting}
            className="h-9 gap-2 rounded-full bg-yellow-400 px-5 text-sm text-black hover:bg-yellow-300"
          >
            <Play size={14} fill="currentColor" />
            去提词
          </Button>

          {!isNew && !isPersistedReadOnly && (
            <Button
              variant="ghost"
              size="icon"
              onClick={handleDelete}
              disabled={deleting}
              className="rounded-full text-neutral-400 hover:bg-red-500/10 hover:text-red-400"
            >
              <Trash2 size={18} />
            </Button>
          )}
        </div>
      </header>

      <main className="flex flex-1 flex-col overflow-hidden">
        <div className="flex-1 overflow-y-auto">
          <div className="mx-auto w-full max-w-3xl px-6 py-10">
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="请输入标题"
              readOnly={isPersistedReadOnly}
              className="w-full bg-transparent text-4xl font-bold text-white placeholder:text-neutral-700 outline-none border-none pb-6"
            />

            <div
              ref={editorContainerRef}
              data-editor-container
              className="relative"
            >
               <TiptapEditor
                 value={content}
                 onValueChange={(value) => {
                   if (isPersistedReadOnly) {
                     return;
                   }
                   setContent(value);
                 }}
                 className="min-h-[50vh] border-0 bg-transparent !ring-0 shadow-none focus-within:!border-0 focus-within:!ring-0"
                 extensions={[
                   CompleteKit.configure({
                     placeholder: { placeholder: editorPlaceholder },
                   }),
                 ]}
               >
                  <TiptapEditorContent className="min-h-[50vh] text-lg leading-relaxed text-neutral-300 [&_.ProseMirror]:p-0 [&_.ProseMirror]:text-neutral-300 [&_.ProseMirror]:outline-none [&_.ProseMirror]:ring-0" />
                 <FloatingToolbar />
               </TiptapEditor>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

export default ScriptEditorPage;
