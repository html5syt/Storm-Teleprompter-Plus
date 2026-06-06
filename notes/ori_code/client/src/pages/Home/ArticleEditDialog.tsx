import { Sparkles, WandSparkles } from 'lucide-react';
import { useEffect, useState } from 'react';
import { toast } from 'sonner';

import { optimizeTextWithAI } from '@/api';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';

import type { Script } from '@/components/teleprompter/types';

interface ArticleEditDialogProps {
  open: boolean;
  article: Script | null;
  pending: boolean;
  onOpenChange: (open: boolean) => void;
  onSubmit: (payload: {
    title: string;
    content: string;
  }) => Promise<void>;
}

export const ArticleEditDialog: React.FC<ArticleEditDialogProps> = ({
  open,
  article,
  pending,
  onOpenChange,
  onSubmit,
}) => {
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [optimizing, setOptimizing] = useState(false);
  const [optimizedPreview, setOptimizedPreview] = useState('');

  useEffect(() => {
    if (!article) {
      setTitle('');
      setContent('');
      setOptimizing(false);
      setOptimizedPreview('');
      return;
    }

    setTitle(article.title);
    setContent(article.content);
    setOptimizing(false);
    setOptimizedPreview('');
  }, [article]);

  const handleOptimize = async () => {
    if (!content.trim()) {
      toast.error('请先输入需要优化的正文');
      return;
    }

    setOptimizing(true);
    setOptimizedPreview('');

    try {
      let nextContent = '';
      for await (const chunk of optimizeTextWithAI(content.trim())) {
        nextContent += chunk;
        setOptimizedPreview(nextContent);
      }
      if (!nextContent.trim()) {
        toast.error('AI 暂未返回优化结果');
        return;
      }
      setContent(nextContent.trim());
      toast.success('正文已优化为标准段落');
    } catch {
      toast.error('AI 文本优化失败，请稍后重试');
    } finally {
      setOptimizing(false);
    }
  };

  const handleSubmit = async () => {
    await onSubmit({
      title,
      content,
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent showCloseButton={false} className="flex max-h-[85vh] max-w-2xl flex-col overflow-hidden rounded-3xl border-neutral-800 bg-neutral-950 text-white">
        <DialogHeader className="flex-row items-start justify-between gap-4">
          <div className="space-y-1.5">
            <DialogTitle className="text-xl">编辑稿件</DialogTitle>
            <DialogDescription className="text-neutral-400">
              修改标题、正文和封面图地址，保存后列表会同步更新。
            </DialogDescription>
          </div>
          <button
            type="button"
            onClick={() => onOpenChange(false)}
            className="mt-1 inline-flex h-8 items-center rounded-lg border border-[#2e2e2e] bg-[#1a1a1a] px-3 text-xs font-medium text-neutral-400 transition-colors hover:bg-[#252525] hover:text-white"
          >
            关闭
          </button>
        </DialogHeader>
        <div className="grid flex-1 gap-4 overflow-y-auto pr-1">
          <div className="grid gap-2">
            <span className="text-sm text-neutral-300">标题</span>
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="border-neutral-800 bg-neutral-900"
              placeholder="请输入稿件标题"
            />
          </div>
          <div className="grid gap-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-sm text-neutral-300">正文</span>
              <div className="flex flex-wrap items-center justify-end gap-2">
                <Button
                  variant="outline"
                  onClick={handleOptimize}
                  disabled={pending || optimizing || !content.trim()}
                  data-ai-section-type="button"
                  className="border-yellow-500/40 bg-yellow-500/10 text-yellow-200 hover:bg-yellow-500/20"
                >
                  {optimizing ? (
                    <>
                      <Sparkles className="animate-pulse" />
                      正在优化中...
                    </>
                  ) : (
                    <>
                      <WandSparkles />
                      AI 优化正文
                    </>
                  )}
                </Button>
              </div>
            </div>
            <Textarea
              value={content}
              onChange={(e) => setContent(e.target.value)}
              className="min-h-48 max-h-[40vh] overflow-y-auto border-neutral-800 bg-neutral-900"
              placeholder="请输入稿件正文，AI 可自动整理成标准中文段落"
            />
            {(optimizing || optimizedPreview) && (
              <div className="rounded-2xl border border-yellow-500/20 bg-gradient-to-br from-yellow-500/10 via-neutral-950 to-neutral-950 p-4">
                <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-2 text-sm text-yellow-200">
                    <Sparkles className={optimizing ? 'animate-pulse' : ''} />
                    <span>
                      {optimizing ? 'AI 正在整理标点与段落…' : '本次优化已完成'}
                    </span>
                  </div>
                  <Badge
                    variant="outline"
                    className="border-yellow-500/30 text-yellow-100"
                  >
                    {optimizing ? '处理中' : '已应用'}
                  </Badge>
                </div>
                <div className="max-h-48 overflow-y-auto whitespace-pre-wrap break-words rounded-xl bg-black/20 p-3 text-sm leading-7 text-neutral-100 transition-all duration-300">
                  {optimizedPreview || 'AI 将在这里实时展示优化后的标准段落。'}
                </div>
              </div>
            )}
            {!optimizing && (
              <Alert className="border-neutral-800 bg-neutral-900/80 text-neutral-200">
                <Sparkles />
                <AlertTitle>优化说明</AlertTitle>
                <AlertDescription>
                  AI 会尽量保留原意，只整理逗号、句号和段落节奏，适合口播稿件场景。
                </AlertDescription>
              </Alert>
            )}
          </div>
        </div>
        <DialogFooter>
          <Button
            variant="secondary"
            onClick={() => onOpenChange(false)}
            disabled={pending || optimizing}
          >
            取消
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={pending || optimizing || !title.trim() || !content.trim()}
            className="bg-yellow-500 text-black hover:bg-yellow-400"
          >
            {pending ? '保存中...' : optimizing ? '等待优化完成...' : '保存修改'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
