import {
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  ChevronLeft,
  ChevronDown,
  ListFilter,
  Send,
  Sparkles,
  WandSparkles,
  X,
} from 'lucide-react';
import { toast } from 'sonner';
import { logger } from '@lark-apaas/client-toolkit/logger';
import { capabilityClient } from '@lark-apaas/client-toolkit';
import { useCurrentEditor } from '@tiptap/react';

import { Button } from '@/components/ui/button';
import {
  TiptapEditorToolbarSeparator,
} from '@/components/miaoda/tiptap-editor/tiptap-editor';
import { MarkToolbarButton } from '@/components/miaoda/tiptap-editor/components/mark-toolbar-button';
import { HeadingToolbarButton } from '@/components/miaoda/tiptap-editor/components/heading-toolbar-button';
import { ListToolbarButton } from '@/components/miaoda/tiptap-editor/components/list-toolbar-button';
import { TextAlignToolbarButton } from '@/components/miaoda/tiptap-editor/components/text-align-toolbar-button';
import { ColorHighlightToolbarButton } from '@/components/miaoda/tiptap-editor/components/color-highlight-toolbar-button';
import { LinkToolbarButton } from '@/components/miaoda/tiptap-editor/components/link-toolbar-button';
import type { AiTextRewriteThreeInput, AiTextRewriteThreeOutput } from '@shared/plugin-types';

const toneOptions = [
  { label: '更口语', instruction: '将这段文字改写成更口语化、更自然的表达，像日常对话一样' },
  { label: '更活泼', instruction: '将这段文字改写成更活泼、更有活力的风格' },
  { label: '更正式', instruction: '将这段文字改写成更正式、更专业的书面语风格' },
  { label: '更专业', instruction: '将这段文字改写成更专业、更严谨的行业表达' },
  { label: '更直白', instruction: '将这段文字改写成更直白、更简洁易懂的表达' },
];

const styleOptions = [
  { label: '更文艺', instruction: '将这段文字改写成更文艺、更优美的文学风格' },
  { label: '更幽默', instruction: '将这段文字改写成更幽默、更有趣的表达方式' },
  { label: '更犀利', instruction: '将这段文字改写成更犀利、更有观点性的表达' },
];

const editOptions = [
  { label: '扩写', instruction: '对这段文字进行扩写，增加细节和例子，让内容更丰富' },
  { label: '缩写', instruction: '对这段文字进行缩写，保留核心信息，去除冗余表达' },
  { label: '总结', instruction: '对这段文字进行总结，提炼核心要点' },
];

interface AiRewritePanelProps {
  onApply: (text: string) => void;
  onClose: () => void;
}

type SubOption = { label: string; instruction: string };

type MenuCategory = {
  key: string;
  label: string;
  icon: React.ReactNode;
  subOptions: SubOption[];
};

const menuCategories: MenuCategory[] = [
  {
    key: 'tone',
    label: '调整语气',
    icon: <Sparkles size={16} />,
    subOptions: toneOptions,
  },
  {
    key: 'style',
    label: '调整风格',
    icon: <WandSparkles size={16} />,
    subOptions: styleOptions,
  },
];

function AiRewritePanel({ onApply, onClose }: AiRewritePanelProps) {
  const { editor } = useCurrentEditor();
  const [customInput, setCustomInput] = useState('');
  const [rewriting, setRewriting] = useState(false);
  const [result, setResult] = useState('');
  const [activeCategory, setActiveCategory] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const selectedText = useMemo(() => {
    if (!editor) return '';
    const { from, to } = editor.state.selection;
    if (from === to) return '';
    return editor.state.doc.textBetween(from, to, ' ');
  }, [editor]);

  const handleRewrite = async (instruction: string) => {
    if (!selectedText.trim() || !editor) return;
    setRewriting(true);
    setResult('');
    try {
      const plugin = capabilityClient.load('ai_text_rewrite_3');
      const input: AiTextRewriteThreeInput = {
        original_text: selectedText.trim(),
        rewrite_instruction: instruction,
      };
      const stream = await plugin.callStream('textGenerate', input as unknown as Record<string, unknown>);
      let full = '';
      for await (const chunk of stream) {
        const data = chunk as AiTextRewriteThreeOutput;
        if (data.content) {
          full += data.content;
          setResult(full);
        }
      }
    } catch (err) {
      logger.error('AI 改写失败', err);
      toast.error('AI 改写失败');
    } finally {
      setRewriting(false);
    }
  };

  const handleCustomSubmit = () => {
    if (!customInput.trim()) return;
    void handleRewrite(customInput.trim());
  };

  const handleApply = () => {
    if (!result.trim() || !editor) return;
    const { from, to } = editor.state.selection;
    editor
      .chain()
      .focus()
      .deleteRange({ from, to })
      .insertContent(result.trim())
      .run();
    onApply(result.trim());
  };

  const handleBack = () => {
    setActiveCategory(null);
  };

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  if (!selectedText) return null;

  return (
    <div className="w-72 rounded-2xl border border-[#2e2e2e] bg-[#1a1a1a] shadow-2xl">
      {!result && !rewriting && (
        <>
          <div className="border-b border-[#2e2e2e] p-4">
            <div className="flex items-center gap-2 rounded-xl border border-[#2e2e2e] bg-[#0d0d0d] px-3 py-2">
              <Sparkles size={14} className="shrink-0 text-yellow-500" />
              <input
                ref={inputRef}
                value={customInput}
                onChange={(e) => setCustomInput(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') handleCustomSubmit(); }}
                placeholder="让AI调整选中的内容..."
                className="flex-1 bg-transparent text-sm text-white placeholder:text-neutral-600 outline-none"
              />
              <button
                onClick={handleCustomSubmit}
                disabled={!customInput.trim()}
                className="shrink-0 rounded-full bg-neutral-700 p-1.5 text-white hover:bg-neutral-600 disabled:opacity-30"
              >
                <Send size={12} />
              </button>
            </div>
          </div>

          <div className="p-2">
            {activeCategory ? (
              <>
                <button
                  onClick={handleBack}
                  className="mb-2 flex w-full items-center gap-2 rounded-xl px-3 py-2 text-sm text-neutral-400 hover:bg-neutral-800 hover:text-white"
                >
                  <ChevronLeft size={14} />
                  返回
                </button>
                {menuCategories
                  .find((c) => c.key === activeCategory)
                  ?.subOptions.map((opt) => (
                    <button
                      key={opt.label}
                      onClick={() => void handleRewrite(opt.instruction)}
                      className="flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-sm text-neutral-300 transition-colors hover:bg-neutral-800 hover:text-white"
                    >
                      {opt.label}
                    </button>
                  ))}
              </>
            ) : (
              <>
                <div className="mb-1 px-3 py-1 text-xs font-medium text-neutral-500">推荐</div>
                {menuCategories.map((cat) => (
                  <button
                    key={cat.key}
                    onClick={() => setActiveCategory(cat.key)}
                    className="flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-sm text-neutral-300 transition-colors hover:bg-neutral-800 hover:text-white"
                  >
                    <span className="flex items-center gap-2">
                      {cat.icon}
                      {cat.label}
                    </span>
                    <ChevronDown size={14} className="rotate-[-90deg] text-neutral-500" />
                  </button>
                ))}

                <div className="my-2 h-px bg-[#2e2e2e]" />

                <div className="mb-1 px-3 py-1 text-xs font-medium text-neutral-500">编辑</div>
                {editOptions.map((opt) => (
                  <button
                    key={opt.label}
                    onClick={() => void handleRewrite(opt.instruction)}
                    className="flex w-full items-center gap-2 rounded-xl px-3 py-2.5 text-sm text-neutral-300 transition-colors hover:bg-neutral-800 hover:text-white"
                  >
                    <ListFilter size={14} className="text-neutral-500" />
                    {opt.label}
                  </button>
                ))}
              </>
            )}
          </div>
        </>
      )}

      {(rewriting || result) && (
        <div className="p-4 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-yellow-500">
              {rewriting ? 'AI 改写中...' : '改写完成'}
            </span>
            <button onClick={onClose} className="rounded p-1 text-neutral-500 hover:bg-neutral-800 hover:text-white">
              <X size={14} />
            </button>
          </div>
          <div className="max-h-48 overflow-y-auto rounded-xl bg-[#0d0d0d] p-3 text-sm leading-relaxed text-neutral-200">
            {result || '正在改写中...'}
          </div>
          {!rewriting && result && (
            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={onClose}
                className="flex-1 rounded-full border-[#2e2e2e] text-neutral-300 hover:bg-neutral-800"
              >
                取消
              </Button>
              <Button
                size="sm"
                onClick={handleApply}
                className="flex-1 rounded-full bg-yellow-500 text-black hover:bg-yellow-400"
              >
                应用
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export function FloatingToolbar() {
  const { editor } = useCurrentEditor();
  const [visible, setVisible] = useState(false);
  const [pos, setPos] = useState<{ x: number; y: number } | null>(null);
  const [showRewritePanel, setShowRewritePanel] = useState(false);
  const hideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!editor) return;

    const handleSelection = () => {
      if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
      const { from, to } = editor.state.selection;
      if (from === to) {
        hideTimerRef.current = setTimeout(() => {
          setVisible(false);
          setShowRewritePanel(false);
        }, 200);
        return;
      }

      const view = editor.view;
      const start = view.coordsAtPos(from);
      const end = view.coordsAtPos(to);
      const container = view.dom.closest('[data-editor-container]') as HTMLElement | null;
      const containerRect = container?.getBoundingClientRect();

      const centerX = (start.left + end.left) / 2;
      const bottomY = Math.max(start.bottom, end.bottom);

      setPos({
        x: containerRect ? centerX - containerRect.left : centerX,
        y: containerRect ? bottomY - containerRect.top + 8 : bottomY + 8,
      });
      setVisible(true);
      setShowRewritePanel(false);
    };

    editor.on('selectionUpdate', handleSelection);
    return () => {
      editor.off('selectionUpdate', handleSelection);
      if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
    };
  }, [editor]);

  if (!visible || !pos) return null;

  return (
    <div
      className="absolute z-50"
      style={{ left: pos.x, top: pos.y, transform: 'translateX(-50%)' }}
    >
      {showRewritePanel ? (
        <AiRewritePanel
          onApply={() => {
            setShowRewritePanel(false);
            setVisible(false);
          }}
          onClose={() => setShowRewritePanel(false)}
        />
      ) : (
        <div className="flex items-center gap-1 rounded-xl border border-[#2e2e2e] bg-[#1a1a1a] px-2 py-1.5 shadow-2xl backdrop-blur-xl">
          <button
            onClick={() => setShowRewritePanel(true)}
            className="flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs font-medium text-yellow-400 hover:bg-neutral-800"
          >
            <Sparkles size={14} />
            AI 改写
          </button>
          <TiptapEditorToolbarSeparator />
          <HeadingToolbarButton />
          <TiptapEditorToolbarSeparator />
          <MarkToolbarButton format="bold" />
          <MarkToolbarButton format="italic" />
          <MarkToolbarButton format="underline" />
          <MarkToolbarButton format="strike" />
          <TiptapEditorToolbarSeparator />
          <ColorHighlightToolbarButton />
          <LinkToolbarButton />
          <TiptapEditorToolbarSeparator />
          <TextAlignToolbarButton />
          <ListToolbarButton />
        </div>
      )}
    </div>
  );
}
