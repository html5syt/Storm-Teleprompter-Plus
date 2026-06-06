import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { AlertTriangle, CheckCircle2, FileText, Search, Settings, XCircle } from 'lucide-react';
import { UniversalLink } from '@lark-apaas/client-toolkit/components/UniversalLink';
import { logger } from '@lark-apaas/client-toolkit/logger';
import { toast } from 'sonner';

import {
  deleteArticle,
  getGlobalSettings,
  listArticles,
} from '@/api';
import { GlobalSettingsDialog } from '@/components/teleprompter/GlobalSettingsDialog';
import { TeleprompterView } from '@/components/teleprompter/TeleprompterView';
import {
  CREATE_TEMPLATE_URL,
  DEFAULT_APP_SETTINGS,
  GUIDE_URL,
} from '@/components/teleprompter/types';
import type {
  AppSettings,
  Script,
  ToastState,
} from '@/components/teleprompter/types';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { preloadSherpaAsr } from '@/lib/teleprompter/sherpa-asr-client';
import {
  createTempScript,
  getTempScript,
  removeTempScript,
  subscribeTempScripts,
  updateTempScript,
} from '@/lib/teleprompter/temp-script-store';
import { ArticleCardList } from './ArticleCardList';
import { ArticleDeleteDialog } from './ArticleDeleteDialog';

type ViewType = 'manager' | 'prompter';

const Home = () => {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const [view, setView] = useState<ViewType>('manager');
  const [remoteScripts, setRemoteScripts] = useState<Script[]>([]);
  const [temporaryScripts, setTemporaryScripts] = useState<Script[]>([]);
  const [activeScriptId, setActiveScriptId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [appSettings, setAppSettings] = useState<AppSettings>(
    DEFAULT_APP_SETTINGS,
  );
  const [showGlobalSettings, setShowGlobalSettings] = useState(false);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [toastState, setToastState] = useState<ToastState | null>(null);
  const [isDeletingArticle, setIsDeletingArticle] = useState(false);
  const [isLoadingArticles, setIsLoadingArticles] = useState(true);
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handleScroll = () => setScrollY(window.scrollY);
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const headerOpacity = Math.min(scrollY / 200, 1);

  useEffect(() => {
    return subscribeTempScripts((scripts) => {
      setTemporaryScripts(scripts);
    });
  }, []);

  useEffect(() => {
    logger.info('[SherpaASR][page] 检测到本地识别主链，开始页面级预热');
    void preloadSherpaAsr().catch((error) => {
      logger.error('[SherpaASR][page] 页面级预热失败', error);
    });
  }, []);

  useEffect(() => {
    const loadAppSettings = async () => {
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

    void loadAppSettings();
  }, []);

  useEffect(() => {
    const loadArticles = async () => {
      try {
        const response = await listArticles();
        const loadedScripts: Script[] = response.items.map((item) => ({
          id: item.id,
          title: item.title,
          content: item.content,
          coverImage: item.coverImage,
          lastModified: new Date(item.updatedAt).getTime(),
        }));
        setRemoteScripts(loadedScripts);
      } catch (error) {
        logger.error('加载稿件列表失败', error);
        setRemoteScripts([]);
        toast.error('加载稿件列表失败');
      } finally {
        setIsLoadingArticles(false);
      }
    };

    void loadArticles();
  }, []);

  useEffect(() => {
    const prompterId = searchParams.get('prompter');
    if (!prompterId) {
      return;
    }

    const allScripts = [
      ...temporaryScripts,
      ...remoteScripts,
    ];
    const found = allScripts.find((script) => script.id === prompterId);

    if (found) {
      setActiveScriptId(prompterId);
      setView('prompter');
      const nextParams = new URLSearchParams(searchParams);
      nextParams.delete('prompter');
      setSearchParams(nextParams, { replace: true });
      return;
    }

    if (!isLoadingArticles) {
      toast.error('稿件不存在');
      const nextParams = new URLSearchParams(searchParams);
      nextParams.delete('prompter');
      setSearchParams(nextParams, { replace: true });
    }
  }, [
    isLoadingArticles,
    remoteScripts,
    searchParams,
    setSearchParams,
    temporaryScripts,
  ]);

  const scripts = useMemo(
    () => [...temporaryScripts, ...remoteScripts],
    [remoteScripts, temporaryScripts],
  );

  const addScript = () => {
    if (appSettings.useTemporaryBrowserCreate) {
      const tempScript = createTempScript();
      navigate(`/editor/${tempScript.id}`);
      return;
    }

    navigate('/editor/new');
  };

  const canEditScript = (script: Script) =>
    script.isTemporary || !appSettings.useTemporaryBrowserCreate;

  const canDeleteScript = (script: Script) =>
    script.isTemporary || !appSettings.useTemporaryBrowserCreate;

  const deleteScript = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setDeleteConfirmId(id);
  };

  const updateScriptContent = (id: string, content: string) => {
    if (getTempScript(id)) {
      updateTempScript(id, { content, lastModified: Date.now() });
      return;
    }

    setRemoteScripts((current) =>
      current.map((script) =>
        script.id === id
          ? { ...script, content, lastModified: Date.now() }
          : script,
      ),
    );
  };

  const filteredScripts = useMemo(() => {
    return scripts.filter(
      (script) =>
        script.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        script.content.toLowerCase().includes(searchQuery.toLowerCase()),
    );
  }, [scripts, searchQuery]);

  const activeScript = scripts.find((script) => script.id === activeScriptId);

  const deletingArticle =
    scripts.find((script) => script.id === deleteConfirmId) ?? null;

  const handleArticleDelete = async () => {
    if (!deletingArticle) {
      return;
    }

    if (deletingArticle.isTemporary) {
      removeTempScript(deletingArticle.id);
      if (activeScriptId === deletingArticle.id) {
        setActiveScriptId(null);
        setView('manager');
      }
      setDeleteConfirmId(null);
      toast.success('临时稿件已删除');
      return;
    }

    try {
      setIsDeletingArticle(true);
      await deleteArticle(deletingArticle.id);
      setRemoteScripts((current) =>
        current.filter((script) => script.id !== deletingArticle.id),
      );
      if (activeScriptId === deletingArticle.id) {
        setActiveScriptId(null);
        setView('manager');
      }
      setDeleteConfirmId(null);
      toast.success('稿件已删除');
    } catch (error) {
      logger.error('删除稿件失败', error);
      toast.error('删除稿件失败');
    } finally {
      setIsDeletingArticle(false);
    }
  };

  const handlePlayScript = (scriptId: string) => {
    setActiveScriptId(scriptId);
    setView('prompter');
  };

  return (
    <>
      {activeScriptId && (
        <div className={view === 'prompter' ? 'block' : 'hidden'}>
          {activeScript && (
            <TeleprompterView
              script={activeScript}
              onBack={() => setView('manager')}
              onUpdateScript={updateScriptContent}
              setToast={setToastState}
            />
          )}
        </div>
      )}

      <div
        className={
          view === 'manager'
            ? 'min-h-screen flex flex-col bg-canvas-bg font-sans text-foreground selection:bg-yellow-500/30'
            : 'hidden'
        }
      >
        <header
          className="fixed top-0 z-50 w-full transition-colors duration-300"
          style={{
            backgroundColor: `rgba(13, 13, 13, ${0.4 + headerOpacity * 0.6})`,
          }}
        >
          <div className="relative mx-auto flex h-16 max-w-7xl items-center justify-between gap-3 px-4 sm:px-6">
            <div className="flex min-w-0 shrink-0 items-center gap-2">
              <img
                src="https://miaoda.feishu.cn/aily/api/v1/feisuda/attachments/675029d7-1f24-43d6-83fe-96277db479d5/raw"
                alt="飓风提词器"
                width={160}
                className="h-8 w-auto object-contain"
              />
              <UniversalLink
                to="https://miaoda.feishu.cn/home"
                target="_blank"
                rel="noopener noreferrer"
                className="hidden md:inline-block text-[10px] text-neutral-500 transition-colors hover:text-yellow-500"
              >
                Power By 飞书妙搭
              </UniversalLink>
            </div>

            <div className="absolute right-4 top-1/2 -translate-y-1/2 md:left-1/2 md:right-auto md:-translate-x-1/2 md:px-2">
              <UniversalLink
                to={CREATE_TEMPLATE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="truncate text-right text-xs font-medium text-yellow-400 transition-colors hover:text-yellow-300 md:text-center sm:text-sm"
              >
                <span className="hidden md:inline">【点击此处进入模板获取页 右上角获同款】</span>
                <span className="inline md:hidden">点击获取同款</span>
              </UniversalLink>
            </div>

            <div className="hidden shrink-0 items-center justify-end gap-3 md:flex">
              <div className="group relative">
                <Search
                  className="absolute top-1/2 left-3 -translate-y-1/2 text-neutral-600 transition-colors group-focus-within:text-yellow-500"
                  size={16}
                />
                <Input
                  placeholder="搜索稿件..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="h-9 w-56 rounded-full border-border/60 bg-surface-bg py-2 pr-4 pl-10 text-sm text-foreground placeholder:text-muted-foreground"
                />
              </div>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => setShowGlobalSettings(true)}
                className="h-9 w-9 rounded-full border border-border/60 bg-surface-bg text-muted-foreground hover:border-primary/50 hover:text-foreground"
              >
                <Settings size={18} />
              </Button>
              <Button
                onClick={addScript}
                className="h-9 rounded-full border-0 bg-yellow-400 px-5 text-sm text-black hover:bg-yellow-300"
              >
                新建稿件
              </Button>
            </div>
          </div>
        </header>

        <main className="flex-1">
          <section className="relative overflow-hidden border-b border-border/40">
            <div className="relative w-full">
              <video
                autoPlay
                muted
                loop
                playsInline
                className="h-auto w-full max-h-[calc(100vh-320px)] object-cover"
              >
                <source
                  src="https://public.ysjf.com/mediastorm/banner/5294c11cb3ed6be81d6f855f42b0bfb8.webm"
                  type="video/webm"
                />
              </video>
              <div className="absolute inset-0 flex items-center">
                <div className="mx-auto flex w-full max-w-7xl items-center justify-center px-6">
                  <div className="max-w-md">
                    <img
                      src="https://miaoda.feishu.cn/aily/api/v1/feisuda/attachments/5d5cec25-ec4e-456f-941f-43045dfc8891/raw"
                      alt="智能提词，从容表达"
                      className="mb-2 h-auto w-[200px] object-contain"
                    />
                  </div>
                </div>
              </div>
              <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-background to-transparent" />
            </div>
          </section>

          <section className="mx-auto max-w-7xl px-6 py-10 pb-24">
            <div className="mb-8 flex items-start justify-between gap-4">
              <div className="flex flex-wrap items-center gap-3">
                <h3 className="text-lg font-semibold text-white">全部稿件</h3>
                <UniversalLink
                  to={GUIDE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center rounded-full border border-yellow-500/20 bg-yellow-500/8 px-3 py-1 text-xs font-medium text-yellow-300 transition-colors hover:border-yellow-400/35 hover:bg-yellow-500/14 hover:text-yellow-200"
                >
                  使用必看
                </UniversalLink>
                <p className="w-full text-xs text-muted-foreground">
                  共 {filteredScripts.length} 条{searchQuery ? ' 匹配结果' : ''}
                </p>
              </div>
            </div>

            {filteredScripts.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-24 text-center">
                <div className="mb-6 flex h-24 w-24 items-center justify-center rounded-3xl border border-border/60 bg-card/50 text-muted-foreground">
                  <FileText size={40} />
                </div>
                <h3 className="mb-2 text-xl font-semibold text-foreground">
                  {searchQuery ? '未找到匹配稿件' : '暂无稿件'}
                </h3>
                <p className="mb-8 max-w-sm text-sm leading-relaxed text-muted-foreground">
                  {searchQuery
                    ? '尝试更换搜索关键词，或清除搜索条件查看全部稿件。'
                    : '点击右上角“新建稿件”开始创作您的第一个提词脚本，支持富文本编辑与 AI 优化。'}
                </p>
                {!searchQuery && (
                  <Button
                    onClick={addScript}
                    className="rounded-full bg-yellow-500 px-6 text-black hover:bg-yellow-400"
                  >
                    立即创建
                  </Button>
                )}
              </div>
            ) : (
              <ArticleCardList
                scripts={filteredScripts}
                onPlay={(scriptId) => {
                  void handlePlayScript(scriptId);
                }}
                onEdit={(scriptId) => navigate(`/editor/${scriptId}`)}
                onDelete={deleteScript}
                canEditScript={canEditScript}
                canDeleteScript={canDeleteScript}
              />
            )}
          </section>
        </main>

        <GlobalSettingsDialog
          open={showGlobalSettings}
          onOpenChange={setShowGlobalSettings}
          setToast={setToastState}
        />

        <ArticleDeleteDialog
          open={!!deletingArticle}
          pending={isDeletingArticle}
          title={deletingArticle?.title ?? ''}
          onOpenChange={(open) => !open && setDeleteConfirmId(null)}
          onConfirm={handleArticleDelete}
        />

        <AnimatePresence>
          {toastState && (
            <motion.div
              initial={{ opacity: 0, y: 50 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 50 }}
              className={`fixed bottom-10 left-1/2 z-[100] flex -translate-x-1/2 items-center gap-3 rounded-xl border px-6 py-3 text-white shadow-2xl ${
                toastState.type === 'success'
                  ? 'border-yellow-500 bg-yellow-600'
                  : 'border-red-500 bg-red-600'
              }`}
            >
              {toastState.type === 'success' ? (
                <CheckCircle2 size={20} />
              ) : (
                <AlertTriangle size={20} />
              )}
              <span className="text-sm font-medium">{toastState.message}</span>
              <button
                data-ai-section-type="button"
                type="button"
                title="关闭提示"
                aria-label="关闭提示"
                onClick={() => setToastState(null)}
                className="ml-4 rounded-full p-1 hover:bg-white/20"
              >
                <XCircle size={16} />
              </button>
            </motion.div>
          )}
        </AnimatePresence>

        <footer className="border-t border-border/40 bg-background/60 py-6 backdrop-blur-sm">
          <div className="mx-auto flex max-w-7xl items-center justify-between gap-6 px-6 text-xs text-muted-foreground">
            <div>Storm Teleprompter</div>
            <div className="flex items-center gap-6">
              <UniversalLink
                to={GUIDE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors hover:text-foreground"
              >
                使用指南
              </UniversalLink>
              <UniversalLink
                to={CREATE_TEMPLATE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="transition-colors hover:text-foreground"
              >
                一键获取同款
              </UniversalLink>
            </div>
          </div>
        </footer>
      </div>
    </>
  );
};

export default Home;
