import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { useInView } from 'framer-motion';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Settings,
  Bug,
  ChevronLeft,
  AlignJustify,
  FlipHorizontal,
  Type,
  MousePointer2,
  AlignHorizontalSpaceAround,
  Clock,
  Rewind,
  PauseCircle,
  PlayCircle,
  FastForward,
  ChevronDown,
  Minimize2,
  RotateCcw,
  Radio,
} from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Slider } from '@/components/ui/slider';
import {
  TiptapEditor,
  TiptapEditorContent,
} from '@/components/miaoda/tiptap-editor/tiptap-editor';
import { FloatingToolbar } from '@/components/miaoda/tiptap-editor/components/floating-toolbar';
import * as TooltipPrimitive from '@radix-ui/react-tooltip';
import {
  Tooltip,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { cn } from '@/lib/utils';

import type { TeleprompterAsrClient } from '@/lib/teleprompter/asr-client';
import { alignmentEngine } from '@/lib/teleprompter/alignment';
import {
  SherpaOnnxAsrClient,
  subscribeSherpaAsrLoadState,
  type SherpaAsrLoadState,
} from '@/lib/teleprompter/sherpa-asr-client';
import type { AsrLatencySample } from '@/lib/teleprompter/telemetry';
import { SPEED_PRESETS } from './types';
import type { Script, TeleprompterSettings, ToastState } from './types';
import { logger } from '@lark-apaas/client-toolkit/logger';

function ToolbarBtn({
  tooltip,
  children,
  ...props
}: { tooltip: string } & React.ComponentProps<typeof Button>) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button {...props}>{children}</Button>
      </TooltipTrigger>
      <TooltipPrimitive.Portal>
        <TooltipPrimitive.Content
          side="top"
          sideOffset={0}
          className="z-50 w-fit rounded-md bg-black px-3 py-1.5 text-xs text-white shadow-xl border-[0.5px] border-neutral-700"
        >
          {tooltip}
          <TooltipPrimitive.Arrow className="z-50 size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 rounded-[2px] bg-black fill-black border-[0.5px] border-neutral-700" />
        </TooltipPrimitive.Content>
      </TooltipPrimitive.Portal>
    </Tooltip>
  );
}

interface TeleprompterViewProps {
  script: Script;
  onBack: () => void;
  onUpdateScript: (id: string, content: string) => void;
  setToast: (toast: ToastState | null) => void;
}

const getTeleprompterCursorStorageKey = (scriptId: string): string => {
  return `teleprompter_cursor_${scriptId}`;
};

interface FormatChar {
  id: string;
  char: string;
  index: number;
  format: {
    bold?: boolean;
    italic?: boolean;
    underline?: boolean;
    strike?: boolean;
    fontSize?: number;
  };
}

interface TextRow {
  id: string;
  chars: FormatChar[];
  startIndex: number;
  endIndex: number;
  tag?: string;
}

function stripHtmlTags(html: string): string {
  if (!html.includes('<')) return html;
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  return tmp.textContent || tmp.innerText || '';
}

function parseHtmlToRows(html: string): { rows: TextRow[]; plainText: string } {
  if (!html.includes('<')) {
    const rows: TextRow[] = [];
    let globalIndex = 0;
    html.split('\n').forEach((line, lineIndex) => {
      const chars = Array.from(line).map((char) => {
        const token: FormatChar = {
          id: `word_${globalIndex}`,
          char,
          index: globalIndex,
          format: {},
        };
        globalIndex += 1;
        return token;
      });
      const startIndex = chars[0]?.index ?? globalIndex;
      const endIndex = chars[chars.length - 1]?.index ?? globalIndex - 1;
      globalIndex += 1;
      rows.push({ id: `line_${lineIndex}`, chars, startIndex, endIndex });
    });
    return { rows, plainText: html };
  }

  const parser = new DOMParser();
  const doc = parser.parseFromString(`<div>${html}</div>`, 'text/html');
  const root = doc.body.firstChild as HTMLElement;

  const rows: TextRow[] = [];
  let globalIndex = 0;
  const allChars: string[] = [];

  function collectFormats(el: Element): FormatChar['format'] {
    const formats: FormatChar['format'] = {};
    let current: Element | null = el;
    let fontSizeFound = false;
    while (current) {
      const tag = current.tagName.toLowerCase();
      if (tag === 'strong' || tag === 'b') formats.bold = true;
      if (tag === 'em' || tag === 'i') formats.italic = true;
      if (tag === 'u') formats.underline = true;
      if (tag === 's' || tag === 'strike' || tag === 'del') formats.strike = true;
      if (!fontSizeFound) {
        const style = current.getAttribute('style');
        if (style) {
          const match = style.match(/font-size:\s*(\d+(?:\.\d+)?)px/i);
          if (match) {
            const px = parseFloat(match[1]);
            if (px > 0) {
              formats.fontSize = px / 16;
              fontSizeFound = true;
            }
          }
        }
      }
      current = current.parentElement;
    }
    return formats;
  }

  function walkNode(node: Node, parentTag: string): void {
    if (node.nodeType === Node.TEXT_NODE) {
      const text = node.textContent || '';
      if (!text) return;
      const formats = node.parentElement ? collectFormats(node.parentElement) : {};
      for (const char of text) {
        allChars.push(char);
        globalIndex += 1;
      }
      return;
    }

    if (node.nodeType !== Node.ELEMENT_NODE) return;
    const el = node as HTMLElement;
    const tag = el.tagName.toLowerCase();
    const isBlock = ['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'blockquote', 'pre'].includes(tag);

    if (isBlock) {
      const blockChars: FormatChar[] = [];
      const blockStartIndex = globalIndex;

      function walkBlockChild(childNode: Node): void {
        if (childNode.nodeType === Node.TEXT_NODE) {
          const text = childNode.textContent || '';
          if (!text) return;
          const formats = childNode.parentElement ? collectFormats(childNode.parentElement) : {};
          for (const char of text) {
            blockChars.push({
              id: `word_${globalIndex}`,
              char,
              index: globalIndex,
              format: formats,
            });
            allChars.push(char);
            globalIndex += 1;
          }
        } else if (childNode.nodeType === Node.ELEMENT_NODE) {
          childNode.childNodes.forEach((c) => walkBlockChild(c));
        }
      }

      el.childNodes.forEach((child) => walkBlockChild(child));

      if (blockChars.length > 0) {
        rows.push({
          id: `row_${rows.length}`,
          chars: blockChars,
          startIndex: blockStartIndex,
          endIndex: globalIndex - 1,
          tag,
        });
      }
      globalIndex += 1;
      allChars.push('\n');
    } else {
      el.childNodes.forEach((child) => walkNode(child, tag));
    }
  }

  root.childNodes.forEach((child) => walkNode(child, ''));

  if (rows.length === 0 && allChars.length > 0) {
    rows.push({
      id: 'row_0',
      chars: allChars.map((char, i) => ({
        id: `word_${i}`,
        char,
        index: i,
        format: {},
      })),
      startIndex: 0,
      endIndex: allChars.length - 1,
    });
  }

  return { rows, plainText: allChars.join('') };
}

const SHERPA_LOAD_PROGRESS: Record<SherpaAsrLoadState['stage'], number> = {
  idle: 0,
  loading_runtime: 25,
  loading_binding: 55,
  initializing_recognizer: 85,
  ready: 100,
  error: 100,
};

function getResponsiveTeleprompterPreset(width: number, height: number) {
  const shorterSide = Math.min(width, height);

  if (width < 480) {
    return {
      fontSize: shorterSide < 380 ? 32 : 36,
      lineHeight: 1.6,
      paddingX: 4,
    };
  }

  if (width < 768) {
    return {
      fontSize: height < 720 ? 40 : 44,
      lineHeight: 1.55,
      paddingX: 6,
    };
  }

  if (width < 1280) {
    return {
      fontSize: 60,
      lineHeight: 1.5,
      paddingX: 5,
    };
  }

  return {
    fontSize: 68,
    lineHeight: 1.45,
    paddingX: 3,
  };
}

// #region debug-point A:local-asr-jump-report
const reportLocalAsrJumpDebug = (
  hypothesisId: 'A' | 'B' | 'C' | 'D',
  msg: string,
  data: Record<string, unknown>,
): void => {
  logger.info(`[LOCAL-ASR-JUMP][${hypothesisId}] ${msg}`, data);
};
// #endregion

export const TeleprompterView: React.FC<TeleprompterViewProps> = ({
  script,
  onBack,
  onUpdateScript,
  setToast,
}) => {
  const speechScrollMode = 'local';
  const baseLookaheadChars = 8;
  const localAsrMaxInterimJump = 4;
  const localAsrMaxFinalJump = 6;

  const stopSpeechAsr = useCallback((showToast: boolean = false) => {
    setRms(0);
    asrClientRef.current?.stop().catch((error) => {
      if (!showToast) {
        return;
      }

      const message =
        error instanceof Error ? error.message : '语音同步停止失败';
      setToast({
        message,
        type: 'error',
      });
    });
  }, [setToast]);

  const containerRef = useRef<HTMLDivElement>(null);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const lineRefs = useRef<Array<HTMLDivElement | null>>([]);
  const wordRefs = useRef<Array<HTMLSpanElement | null>>([]);
  const scrollFrameRef = useRef<number | null>(null);
  const isVisible = useInView(containerRef, { amount: 0.5 });
  const [currentIndex, setCurrentIndex] = useState<number>(-1);
  const currentIndexRef = useRef<number>(-1);
  const [lastTranscription, setLastTranscription] = useState<string>('');
  const lastTranscriptionRef = useRef('');
  const [showSpeedMenu, setShowSpeedMenu] = useState(false);
  const [rms, setRms] = useState(0);
  const rmsRef = useRef(0);
  const asrClientRef = useRef<TeleprompterAsrClient | null>(null);
  const [localAsrLoadState, setLocalAsrLoadState] = useState<SherpaAsrLoadState>({
    stage: 'idle',
    message: '本地语音模型尚未加载',
  });
  const [debugStats, setDebugStats] = useState({
    droppedCount: 0,
    strategy: 'none',
  });
  const [settings, setSettings] = useState<TeleprompterSettings>({
    fontSize: 64,
    lineHeight: 1.5,
    mirrorMode: false,
    showSettings: false,
    useResponsivePreset: true,
    scrollMode: speechScrollMode,
    wpn: 160,
    isScrolling: false,
    paddingX: 5,
  });
  const [panelWidth, setPanelWidth] = useState(384);
  const [isMobile, setIsMobile] = useState(false);
  const isDraggingRef = useRef(false);
  const startXRef = useRef(0);
  const startWidthRef = useRef(384);

  const scrollLookaheadChars =
    settings.scrollMode === 'local'
      ? baseLookaheadChars
      : 0;

  const activeAsrLabel = 'Local ASR Active';

  const parsedContent = useMemo(() => parseHtmlToRows(script.content), [script.content]);
  const plainTextForAlignment = useMemo(() => stripHtmlTags(script.content), [script.content]);
  const totalChars = plainTextForAlignment.length;
  const cursorStorageKey = getTeleprompterCursorStorageKey(script.id);

  const fontSizePresets = [40, 52, 64, 80, 96];
  const lineHeightPresets = [1.2, 1.4, 1.6, 1.8, 2.0];

  const textRows = parsedContent.rows;

  useEffect(() => {
    const updateViewportMode = () => {
      const width = window.innerWidth;
      const height = window.innerHeight;
      setIsMobile(width < 768);
      setSettings((current) => {
        if (!current.useResponsivePreset) {
          return current;
        }

        const nextPreset = getResponsiveTeleprompterPreset(width, height);
        if (
          current.fontSize === nextPreset.fontSize &&
          current.lineHeight === nextPreset.lineHeight &&
          current.paddingX === nextPreset.paddingX
        ) {
          return current;
        }

        return {
          ...current,
          ...nextPreset,
        };
      });
    };

    updateViewportMode();
    window.addEventListener('resize', updateViewportMode);

    return () => {
      window.removeEventListener('resize', updateViewportMode);
    };
  }, []);

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!isDraggingRef.current || isMobile) return;
      const delta = startXRef.current - e.clientX;
      const newWidth = Math.max(320, Math.min(800, startWidthRef.current + delta));
      setPanelWidth(newWidth);
    };
    const handleMouseUp = () => {
      isDraggingRef.current = false;
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    };
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isMobile]);

  useEffect(() => {
    const savedCursor = localStorage.getItem(cursorStorageKey);
    const parsedCursor = savedCursor ? Number.parseInt(savedCursor, 10) : -1;
    const initialCursor =
      Number.isFinite(parsedCursor) &&
      parsedCursor >= 0 &&
      parsedCursor < totalChars
        ? parsedCursor
        : (totalChars > 0 ? 0 : -1);

    currentIndexRef.current = initialCursor;
    setCurrentIndex(initialCursor);
    alignmentEngine.setCurrentIndex(initialCursor);
    lastTranscriptionRef.current = '';
    setLastTranscription('');
    rmsRef.current = 0;
    setRms(0);
    setDebugStats({ droppedCount: 0, strategy: 'none' });
  }, [cursorStorageKey, totalChars]);

  const updateCurrentIndex = useCallback((index: number, isRemote: boolean = false) => {
    // #region debug-point D:update-current-index-entry
    const previousIndex = currentIndexRef.current;
    if (isRemote) {
      reportLocalAsrJumpDebug('D', 'updateCurrentIndex(remote-entry)', {
        previousIndex,
        requestedIndex: index,
        totalChars,
      });
    }
    // #endregion

    if (isRemote && index < currentIndexRef.current) {
      setDebugStats((prev) => ({
        ...prev,
        droppedCount: prev.droppedCount + 1,
      }));
      return;
    }

    const shouldResetProgress = totalChars > 0 && index >= totalChars - 1;
    const nextIndex = shouldResetProgress ? -1 : index;

    if (nextIndex === currentIndexRef.current) {
      return;
    }

    if (!isRemote) {
      alignmentEngine.setCurrentIndex(nextIndex);
    }

    currentIndexRef.current = nextIndex;
    setCurrentIndex(nextIndex);

    // #region debug-point D:update-current-index-commit
    if (isRemote) {
      reportLocalAsrJumpDebug('D', 'updateCurrentIndex(remote-commit)', {
        previousIndex,
        committedIndex: nextIndex,
      });
    }
    // #endregion

    if (nextIndex < 0) {
      localStorage.removeItem(cursorStorageKey);
      return;
    }

    localStorage.setItem(cursorStorageKey, String(nextIndex));
  }, [cursorStorageKey, totalChars]);

  useEffect(() => {
    asrClientRef.current = new SherpaOnnxAsrClient();
    alignmentEngine.setScript(plainTextForAlignment);
  }, [plainTextForAlignment]);

  useEffect(() => {
    logger.info('[SherpaASR][page] 提词器开始订阅本地模型加载状态');
    return subscribeSherpaAsrLoadState((state) => {
      logger.info('[SherpaASR][page] 加载状态更新', state);
      setLocalAsrLoadState(state);
    });
  }, []);

  useEffect(() => {
    setSettings((current) => {
      if (
        current.scrollMode === 'manual' ||
        current.scrollMode === 'auto' ||
        current.scrollMode === speechScrollMode
      ) {
        return current;
      }

      return {
        ...current,
        scrollMode: speechScrollMode,
        isScrolling: false,
      };
    });
  }, [speechScrollMode]);

  useEffect(() => {
    const container = scrollContainerRef.current;
    if (!container) {
      return;
    }

    if (scrollFrameRef.current !== null) {
      cancelAnimationFrame(scrollFrameRef.current);
    }

    scrollFrameRef.current = requestAnimationFrame(() => {
      // 移动端关闭前瞻漂移，直接跟随真实焦点字。
      const effectiveLookaheadChars = isMobile ? 0 : scrollLookaheadChars;
      const lookaheadIndex = Math.min(
        Math.max(0, currentIndex) + effectiveLookaheadChars,
        totalChars - 1,
      );
      
      // 2. 获取虚拟焦点字 DOM
      let targetElement = wordRefs.current[lookaheadIndex];
      if (!targetElement) {
        // 如果找不到字，尝试找当前真实焦点字
        targetElement = wordRefs.current[currentIndex];
      }

      if (!targetElement) {
        scrollFrameRef.current = null;
        return;
      }

      // 3. 直接把这个虚拟焦点字当成一切的基准
      const targetLine = targetElement.closest('.teleprompter-row') as HTMLElement | null;
      if (!targetLine) {
        scrollFrameRef.current = null;
        return;
      }

      // 移动端用更稳定的阅读线，避免“焦点漂移”的体感。
      const readingLineY = window.innerHeight * (isMobile ? 0.3 : 0.25);
      
      const targetRect = targetElement.getBoundingClientRect();
      const containerRect = container.getBoundingClientRect();
      const lineRect = targetLine.getBoundingClientRect();
      
      const relativeReadingY = readingLineY - containerRect.top;
      const boxHeight = settings.fontSize * settings.lineHeight * 3;

      // 计算焦点字在段落内的相对偏移
      const wordOffsetInLine = targetRect.top - lineRect.top;
      
      // 正常跟踪的目标位置
      const trueTargetTopInContainer = lineRect.top - containerRect.top + wordOffsetInLine;

      // 该段落的底部锁定边界
      const maxTargetTopInContainer = lineRect.bottom - containerRect.top - boxHeight;
      
      // 底部锁死逻辑：直接限制在当前段落（即虚拟焦点所在段落）的底部
      const finalTargetTopInContainer = lineRect.height < boxHeight
        ? trueTargetTopInContainer
        : Math.min(trueTargetTopInContainer, maxTargetTopInContainer);

      const targetScrollTop = Math.max(0, container.scrollTop + finalTargetTopInContainer - relativeReadingY);

      if (Math.abs(container.scrollTop - targetScrollTop) < 2) {
        scrollFrameRef.current = null;
        return;
      }

      container.scrollTo({
        top: targetScrollTop,
        behavior: currentIndex >= 0 ? 'smooth' : 'auto',
      });
      scrollFrameRef.current = null;
    });

    return () => {
      if (scrollFrameRef.current !== null) {
        cancelAnimationFrame(scrollFrameRef.current);
        scrollFrameRef.current = null;
      }
    };
  }, [currentIndex, textRows, scrollLookaheadChars, settings.fontSize, settings.lineHeight, isMobile]);

  const handleTelemetry = useCallback((sample: AsrLatencySample) => {
    void sample;
  }, []);

  const clampRemoteAdvance = useCallback(
    (index: number, isFinal: boolean): number => {
      if (index < 0) {
        return index;
      }

      const current = currentIndexRef.current;
      if (current < 0 || index <= current) {
        return index;
      }

      const maxJump = isFinal ? localAsrMaxFinalJump : localAsrMaxInterimJump;
      const clampedIndex = Math.min(index, current + maxJump);
      // #region debug-point C:clamp-remote-advance
      reportLocalAsrJumpDebug('C', 'clampRemoteAdvance(local)', {
        currentIndex: current,
        requestedIndex: index,
        clampedIndex,
        isFinal,
        maxJump,
      });
      // #endregion
      return clampedIndex;
    },
    [localAsrMaxFinalJump, localAsrMaxInterimJump],
  );

  useEffect(() => {
    const shouldAsrBeOn =
      isVisible &&
      settings.scrollMode === 'local' &&
      settings.isScrolling;

    if (shouldAsrBeOn) {
      logger.info('[SherpaASR][page] 准备启动语音识别', {
        scrollMode: settings.scrollMode,
      });
      asrClientRef.current
        ?.start(
          (text) => {
            if (text !== lastTranscriptionRef.current) {
              lastTranscriptionRef.current = text;
              setLastTranscription(text);
            }
            const result = alignmentEngine.consumeTranscript(text, false);
            const clampedIndex = clampRemoteAdvance(result.index, false);
            // #region debug-point A:local-asr-interim
            reportLocalAsrJumpDebug('A', 'local ASR interim result', {
              textLength: text.length,
              textPreview: text.slice(-30),
              alignmentIndex: result.index,
              clampedIndex,
              strategy: result.meta.strategy,
              currentIndex: currentIndexRef.current,
            });
            // #endregion
            updateCurrentIndex(clampedIndex, true);
            setDebugStats((prev) =>
              prev.strategy === result.meta.strategy
                ? prev
                : { ...prev, strategy: result.meta.strategy }
            );
          },
          (text) => {
            if (text !== lastTranscriptionRef.current) {
              lastTranscriptionRef.current = text;
              setLastTranscription(text);
            }
            const result = alignmentEngine.consumeTranscript(text, true);
            const clampedIndex = clampRemoteAdvance(result.index, true);
            // #region debug-point B:local-asr-final
            reportLocalAsrJumpDebug('B', 'local ASR final result', {
              textLength: text.length,
              textPreview: text.slice(-30),
              alignmentIndex: result.index,
              clampedIndex,
              strategy: result.meta.strategy,
              currentIndex: currentIndexRef.current,
            });
            // #endregion
            updateCurrentIndex(clampedIndex, true);
            setDebugStats((prev) =>
              prev.strategy === result.meta.strategy
                ? prev
                : { ...prev, strategy: result.meta.strategy }
            );
          },
          (rmsValue) => {
            const nextRms = Number(rmsValue.toFixed(3));
            if (nextRms === rmsRef.current) {
              return;
            }
            rmsRef.current = nextRms;
            setRms(nextRms);
          },
          handleTelemetry,
        )
        .catch((error) => {
          logger.error('[SherpaASR][page] 语音识别启动失败', error);
          setToast({
            message: error.message || '语音同步启动失败',
            type: 'error',
          });
          setSettings((s) => ({ ...s, isScrolling: false }));
        });
    } else {
      stopSpeechAsr();
    }

    return () => {
      stopSpeechAsr();
    };
  }, [
    isVisible,
    settings.scrollMode,
    settings.isScrolling,
    stopSpeechAsr,
    updateCurrentIndex,
    setToast,
    handleTelemetry,
    clampRemoteAdvance,
  ]);

  useEffect(() => {
    let lastTime = performance.now();
    let rafId: number;
    let accumulator = 0;

    const scroll = (time: number) => {
      if (settings.scrollMode === 'auto' && settings.isScrolling) {
        const deltaTime = time - lastTime;
        lastTime = time;

        const msPerChar = 60000 / settings.wpn;
        accumulator += deltaTime;

        if (accumulator >= msPerChar) {
          const charsToAdvance = Math.floor(accumulator / msPerChar);
          accumulator %= msPerChar;

          const newIndex = Math.min(
            totalChars - 1,
            currentIndexRef.current + charsToAdvance,
          );

          if (newIndex >= totalChars - 1) {
            updateCurrentIndex(0);
            setSettings((s) => ({ ...s, isScrolling: false }));
            return;
          }

          if (newIndex !== currentIndexRef.current) {
            updateCurrentIndex(newIndex);
          }
        }
        rafId = requestAnimationFrame(scroll);
      }
    };

    if (settings.scrollMode === 'auto' && settings.isScrolling) {
      rafId = requestAnimationFrame(scroll);
    }

    return () => {
      if (rafId) cancelAnimationFrame(rafId);
    };
  }, [
    settings.scrollMode,
    settings.isScrolling,
    settings.wpn,
    updateCurrentIndex,
    totalChars,
  ]);

  const toggleScrolling = () => {
    setSettings((s) => {
      const nextIsScrolling = !s.isScrolling;
      if (!nextIsScrolling && s.scrollMode === 'local') {
        stopSpeechAsr(true);
      }
      return { ...s, isScrolling: nextIsScrolling };
    });
  };

  const jumpIndex = (delta: number) => {
    const newIndex = Math.max(
      0,
      Math.min(totalChars - 1, currentIndexRef.current + delta),
    );
    updateCurrentIndex(newIndex);
  };

  const setResponsiveAwareSettings = useCallback(
    (
      updater: (current: TeleprompterSettings) => TeleprompterSettings,
      options?: { keepResponsivePreset?: boolean },
    ) => {
      setSettings((current) => {
        const next = updater(current);
        if (options?.keepResponsivePreset) {
          return next;
        }

        return {
          ...next,
          useResponsivePreset: false,
        };
      });
    },
    [],
  );

  return (
    <div
      ref={containerRef}
      className="relative flex h-screen w-screen flex-col overflow-hidden bg-black font-sans text-white"
    >
      <div className="pointer-events-none fixed bottom-6 left-6 z-[100] hidden md:flex flex-col gap-2">
        <div className="flex flex-col gap-1 rounded-lg border border-white/10 bg-black/60 px-3 py-2 backdrop-blur-md">
          <div className="flex items-center gap-2 text-[10px] font-bold uppercase tracking-widest text-white/40">
            <Bug size={10} /> Debug Monitor
          </div>
          <div className="grid grid-cols-2 gap-x-4 gap-y-1">
            <div className="flex justify-between gap-4">
              <span className="text-[10px] text-white/40">WPM:</span>
              <span className="text-[10px] font-mono text-yellow-400">
                {settings.wpn}
              </span>
            </div>
            <div className="flex justify-between gap-4">
              <span className="text-[10px] text-white/40">DROPPED:</span>
              <span className="text-[10px] font-mono text-yellow-400">
                {debugStats.droppedCount}
              </span>
            </div>
            <div className="col-span-2 flex justify-between gap-4">
              <span className="text-[10px] text-white/40">STRATEGY:</span>
              <span className="text-[10px] font-mono uppercase text-yellow-400">
                {debugStats.strategy}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className="pointer-events-none absolute top-0 left-0 right-0 z-50 flex items-center justify-between gap-3 bg-gradient-to-b from-black/90 to-transparent p-3 sm:p-4">
        <div className="pointer-events-auto flex items-center gap-4">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => {
              setSettings((s) => ({ ...s, isScrolling: false }));
              stopSpeechAsr(true);
              alignmentEngine.setCurrentIndex(-1);
              currentIndexRef.current = -1;
              setCurrentIndex(-1);
              localStorage.removeItem(cursorStorageKey);
              onBack();
            }}
            className="rounded-full bg-neutral-900/50 text-neutral-400 hover:bg-neutral-800 hover:text-white"
          >
            <ChevronLeft size={20} />
          </Button>
          <h1 className="max-w-[120px] truncate text-xs font-medium text-neutral-400 sm:max-w-[280px]">
            {script.title}
          </h1>
        </div>

        <div className="pointer-events-auto flex items-center gap-3">
          <div className="hidden items-center gap-2 text-xs text-neutral-500 sm:flex">
            <span className="hidden sm:inline">总字数:</span>
            <span className="font-mono text-neutral-300">
              {Array.from(script.content).length.toLocaleString()}
            </span>
            <span className="mx-1 text-neutral-700">|</span>
            <span className="hidden sm:inline">进度:</span>
            <span className="font-mono text-neutral-300">
              {Math.min(
                100,
                Math.round(
                  (currentIndex + 1) /
                    Math.max(1, Array.from(script.content).length) *
                    100
                )
              )}%
            </span>
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={() =>
                setSettings((s) => ({ ...s, showSettings: !s.showSettings }))
            }
            className="rounded-full bg-neutral-900/50 text-neutral-400 hover:bg-neutral-800 hover:text-white"
          >
            <Settings size={20} />
          </Button>
        </div>
      </div>

      <div
        ref={scrollContainerRef}
        className={`teleprompter-container flex-1 overflow-y-auto break-all ${
          settings.mirrorMode ? 'mirror-mode' : ''
        }`}
        style={{
          fontSize: `${settings.fontSize}px`,
          lineHeight: settings.lineHeight,
          scrollbarWidth: 'none',
          paddingLeft: `calc(${isMobile ? 16 : 64}px + ${settings.paddingX}%)`,
          paddingRight: `calc(${isMobile ? 16 : 64}px + ${settings.paddingX}%)`,
        }}
      >
        <div className="text-left pt-[80vh] pb-[80vh]">
          {textRows.map((row, rowIndex) => {
            return (
                <div
                key={row.id}
                ref={(element) => {
                  lineRefs.current[rowIndex] = element;
                }}
                className="relative teleprompter-row"
                style={{
                  ...row.tag?.match(/^h[1-6]$/)
                    ? {
                        fontSize:
                          row.tag === 'h1'
                            ? '2em'
                            : row.tag === 'h2'
                              ? '1.5em'
                              : row.tag === 'h3'
                                ? '1.17em'
                                : row.tag === 'h4'
                                  ? '1em'
                                  : row.tag === 'h5'
                                    ? '0.83em'
                                    : '0.67em',
                      }
                    : {},
                  marginLeft: `calc(${isMobile ? 0 : 32}px + ${isMobile ? 0 : 5}%)`,
                  marginRight: `calc(${isMobile ? 0 : 32}px + ${isMobile ? 0 : 5}%)`,
                }}
              >
                {row.chars.length === 0 ? (
                  <button
                    type="button"
                    onClick={() => updateCurrentIndex(row.startIndex)}
                    className="block min-h-[1.2em] w-full cursor-pointer"
                    aria-label="跳转到空行"
                  />
                ) : (
                  row.chars.map((token) => {
                    return (
                      <span
                        key={token.id}
                        id={token.id}
                        ref={(element) => {
                          wordRefs.current[token.index] = element;
                        }}
                        onClick={() => updateCurrentIndex(token.index)}
                        className={cn(
                          'inline cursor-pointer rounded px-0.5 transition-colors duration-150 hover:bg-white/10',
                          token.format.bold && 'font-bold',
                          token.format.italic && 'italic',
                          token.format.underline && 'underline',
                          token.format.strike && 'line-through',
                          'text-white',
                        )}
                        style={
                          token.format.fontSize
                            ? { fontSize: `${settings.fontSize * token.format.fontSize}px` }
                            : undefined
                        }
                      >
                        {token.char}
                      </span>
                    );
                  })
                )}
              </div>
            );
          })}
        </div>
      </div>

      <AnimatePresence>
        {settings.showSettings && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() =>
                setSettings((s) => ({ ...s, showSettings: false }))
              }
              className="absolute inset-0 z-[60] bg-black/60"
            />
            <motion.div
              initial={{ x: '100%' }}
              animate={{ x: 0 }}
              exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              style={isMobile ? undefined : { width: panelWidth }}
              className="absolute top-0 right-0 bottom-0 z-[70] flex w-full flex-col border-l border-white/5 bg-[#0a0a0a] shadow-2xl sm:w-96"
            >
              {!isMobile && (
                <div
                  onMouseDown={(e) => {
                    isDraggingRef.current = true;
                    startXRef.current = e.clientX;
                    startWidthRef.current = panelWidth;
                    document.body.style.cursor = 'ew-resize';
                    document.body.style.userSelect = 'none';
                  }}
                  className="absolute top-0 left-0 bottom-0 z-10 w-1 cursor-ew-resize hover:bg-yellow-500/30"
                />
              )}
              <div className="flex items-center justify-between border-b border-white/5 px-6 py-4">
                <h2 className="flex items-center gap-2 text-base font-semibold text-white">
                  <Settings size={18} /> 提词设置
                </h2>
                <button
                  type="button"
                  title="关闭提词设置"
                  aria-label="关闭提词设置"
                  onClick={() =>
                    setSettings((s) => ({ ...s, showSettings: false }))
                  }
                  className="text-neutral-500 transition-colors hover:text-white"
                >
                  <Minimize2 size={18} />
                </button>
              </div>

              <div className="flex-1 overflow-y-auto p-6 space-y-6">
                <div className="flex items-center justify-between gap-3 rounded-2xl border border-[#2e2e2e] bg-[#141414] p-4">
                  <div>
                    <span className="block text-sm text-white">自动适配</span>
                    <span className="text-xs text-neutral-500">
                      根据页面大小自动匹配字号、行距和边距
                    </span>
                  </div>
                  <button
                    type="button"
                    title={settings.useResponsivePreset ? '关闭自动适配' : '开启自动适配'}
                    aria-label={settings.useResponsivePreset ? '关闭自动适配' : '开启自动适配'}
                    onClick={() => {
                      if (settings.useResponsivePreset) {
                        setSettings((s) => ({ ...s, useResponsivePreset: false }));
                        return;
                      }

                      const nextPreset = getResponsiveTeleprompterPreset(
                        window.innerWidth,
                        window.innerHeight,
                      );
                      setSettings((s) => ({
                        ...s,
                        ...nextPreset,
                        useResponsivePreset: true,
                      }));
                    }}
                    className={
                      settings.useResponsivePreset
                        ? 'inline-flex h-8 items-center rounded-lg bg-yellow-400 px-3 text-xs font-medium text-black transition-colors hover:bg-yellow-300'
                        : 'inline-flex h-8 items-center rounded-lg border border-[#2e2e2e] bg-[#1a1a1a] px-3 text-xs font-medium text-neutral-400 transition-colors hover:bg-[#252525] hover:text-white'
                    }
                  >
                    {settings.useResponsivePreset ? '已开启' : '已关闭'}
                  </button>
                </div>

                <div className="space-y-4 rounded-2xl border border-[#2e2e2e] bg-[#141414] p-4">
                  <div className="flex items-center justify-between gap-3 text-sm">
                    <span className="flex items-center gap-2 text-neutral-400">
                      <Type size={16} /> 字号
                    </span>
                    <div className="flex flex-wrap items-center justify-end gap-2">
                      <span className="font-mono text-white">
                        {settings.fontSize}px
                      </span>
                      <button
                        type="button"
                        title="重置字号"
                        aria-label="重置字号"
                        onClick={() =>
                          setResponsiveAwareSettings((s) => ({ ...s, fontSize: 64 }))
                        }
                        className="inline-flex h-8 w-8 items-center justify-center rounded-full text-neutral-500 transition-colors hover:bg-[#1a1a1a] hover:text-white"
                      >
                        <RotateCcw size={14} />
                      </button>
                    </div>
                  </div>
                  <Slider
                    min={24}
                    max={120}
                    step={2}
                    value={[settings.fontSize]}
                    onValueChange={(value) =>
                      setResponsiveAwareSettings((s) => ({
                        ...s,
                        fontSize: value[0] ?? s.fontSize,
                      }))
                    }
                  />
                  <div className="flex flex-wrap justify-start gap-2">
                    {fontSizePresets.map((preset) => (
                      <button
                        key={preset}
                        type="button"
                        onClick={() =>
                          setResponsiveAwareSettings((s) => ({ ...s, fontSize: preset }))
                        }
                        className={
                          settings.fontSize === preset
                            ? 'inline-flex h-8 items-center rounded-lg bg-yellow-400 px-3 text-xs font-medium text-black transition-colors hover:bg-yellow-300'
                            : 'inline-flex h-8 items-center rounded-lg border border-[#2e2e2e] bg-[#1a1a1a] px-3 text-xs font-medium text-neutral-400 transition-colors hover:bg-[#252525] hover:text-white'
                        }
                      >
                        {preset}px
                      </button>
                    ))}
                  </div>
                </div>

                <div className="space-y-4 rounded-2xl border border-[#2e2e2e] bg-[#141414] p-4">
                  <div className="flex items-center justify-between gap-3 text-sm">
                    <span className="flex items-center gap-2 text-neutral-400">
                      <AlignJustify size={16} /> 行距
                    </span>
                    <div className="flex flex-wrap items-center justify-end gap-2">
                      <span className="font-mono text-white">
                        {settings.lineHeight.toFixed(1)}
                      </span>
                      <button
                        type="button"
                        title="重置行距"
                        aria-label="重置行距"
                        onClick={() =>
                          setResponsiveAwareSettings((s) => ({ ...s, lineHeight: 1.5 }))
                        }
                        className="inline-flex h-8 w-8 items-center justify-center rounded-full text-neutral-500 transition-colors hover:bg-[#1a1a1a] hover:text-white"
                      >
                        <RotateCcw size={14} />
                      </button>
                    </div>
                  </div>
                  <Slider
                    min={1}
                    max={2.5}
                    step={0.1}
                    value={[settings.lineHeight]}
                    onValueChange={(value) =>
                      setResponsiveAwareSettings((s) => ({
                        ...s,
                        lineHeight: value[0] ?? s.lineHeight,
                      }))
                    }
                  />
                  <div className="flex flex-wrap justify-start gap-2">
                    {lineHeightPresets.map((preset) => (
                      <button
                        key={preset}
                        type="button"
                        onClick={() =>
                          setResponsiveAwareSettings((s) => ({
                            ...s,
                            lineHeight: preset,
                          }))
                        }
                        className={
                          settings.lineHeight === preset
                            ? 'inline-flex h-8 items-center rounded-lg bg-yellow-400 px-3 text-xs font-medium text-black transition-colors hover:bg-yellow-300'
                            : 'inline-flex h-8 items-center rounded-lg border border-[#2e2e2e] bg-[#1a1a1a] px-3 text-xs font-medium text-neutral-400 transition-colors hover:bg-[#252525] hover:text-white'
                        }
                      >
                        {preset.toFixed(1)}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="flex items-center justify-between gap-3 rounded-2xl border border-[#2e2e2e] bg-[#141414] p-4">
                  <div className="flex items-center gap-3">
                    <FlipHorizontal size={18} className="text-neutral-400" />
                    <div>
                      <span className="block text-sm text-white">镜像模式</span>
                      <span className="text-xs text-neutral-500">
                        用于分光镜反射
                      </span>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      setSettings((s) => ({
                        ...s,
                        mirrorMode: !s.mirrorMode,
                      }))
                    }
                    className={
                      settings.mirrorMode
                        ? 'inline-flex h-8 items-center rounded-lg bg-yellow-400 px-3 text-xs font-medium text-black transition-colors hover:bg-yellow-300'
                        : 'inline-flex h-8 items-center rounded-lg border border-[#2e2e2e] bg-[#1a1a1a] px-3 text-xs font-medium text-neutral-400 transition-colors hover:bg-[#252525] hover:text-white'
                    }
                  >
                    {settings.mirrorMode ? '已开启' : '已关闭'}
                  </button>
                </div>

                <div className="space-y-4 rounded-2xl border border-[#2e2e2e] bg-[#141414] p-4">
                  <div className="flex items-center justify-between gap-3 text-sm">
                    <span className="flex items-center gap-2 text-neutral-400">
                      <AlignHorizontalSpaceAround size={16} /> 左右边距
                    </span>
                    <div className="flex flex-wrap items-center justify-end gap-2">
                      <span className="font-mono text-white">
                        {settings.paddingX}%
                      </span>
                      <button
                        type="button"
                        title="重置左右边距"
                        aria-label="重置左右边距"
                        onClick={() =>
                          setResponsiveAwareSettings((s) => ({ ...s, paddingX: 5 }))
                        }
                        className="inline-flex h-8 w-8 items-center justify-center rounded-full text-neutral-500 transition-colors hover:bg-[#1a1a1a] hover:text-white"
                      >
                        <RotateCcw size={14} />
                      </button>
                    </div>
                  </div>
                    <Slider
                    min={0}
                    max={40}
                    step={1}
                    value={[settings.paddingX]}
                    onValueChange={(value) =>
                      setResponsiveAwareSettings((s) => ({
                        ...s,
                        paddingX: value[0] ?? s.paddingX,
                      }))
                    }
                  />
                  <div className="flex flex-wrap justify-start gap-2">
                    {[0, 5, 10, 15, 20].map((preset) => (
                      <button
                        key={preset}
                        type="button"
                        onClick={() =>
                          setResponsiveAwareSettings((s) => ({ ...s, paddingX: preset }))
                        }
                        className={
                          settings.paddingX === preset
                            ? 'inline-flex h-8 items-center rounded-lg bg-yellow-400 px-3 text-xs font-medium text-black transition-colors hover:bg-yellow-300'
                            : 'inline-flex h-8 items-center rounded-lg border border-[#2e2e2e] bg-[#1a1a1a] px-3 text-xs font-medium text-neutral-400 transition-colors hover:bg-[#252525] hover:text-white'
                        }
                      >
                        {preset}%
                      </button>
                    ))}
                  </div>
                </div>

                <div className="flex min-h-[320px] flex-col gap-3 rounded-2xl border border-[#2e2e2e] bg-[#141414] p-4">
                  <span className="text-sm text-neutral-400">
                    稿件内容（实时同步）
                  </span>
                  <div data-editor-container className="relative min-h-[260px] flex-1">
                    <TiptapEditor
                      value={script.content}
                      onValueChange={(value) => onUpdateScript(script.id, value)}
                      className="min-h-[260px] flex-1 rounded-xl border-[#2e2e2e] bg-[#1a1a1a] text-neutral-300 [&_.prose]:text-neutral-300"
                    >
                      <TiptapEditorContent className="min-h-[260px] flex-1 overflow-auto rounded-xl bg-[#1a1a1a] p-4 text-sm text-neutral-300 [&_.ProseMirror]:p-0 [&_.ProseMirror]:text-neutral-300 [&_.ProseMirror]:outline-none [&_.ProseMirror]:ring-0" />
                      <FloatingToolbar />
                    </TiptapEditor>
                  </div>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      <div
        className="pointer-events-none absolute z-10 border-2"
        style={{
          top: isMobile ? '30%' : '25%',
          left: `calc(${isMobile ? 16 : 64}px + ${settings.paddingX}%)`,
          width: `calc(100% - ${isMobile ? 32 : 128}px - ${settings.paddingX * 2}%)`,
          borderColor: '#fdc800',
          height: `calc(${settings.fontSize}px * ${settings.lineHeight} * 2.9)`,
        }}
      >
        <div
          className="absolute -top-3 left-4 bg-black px-2 font-mono text-[10px] uppercase tracking-widest"
          style={{ color: '#fdc800' }}
        >
          Reading Area
        </div>
      </div>

      <AnimatePresence>
        {settings.scrollMode === 'local' && localAsrLoadState.stage !== 'ready' && (
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 16 }}
              className="pointer-events-none fixed bottom-28 left-1/2 z-50 w-[92%] max-w-xl -translate-x-1/2 rounded-2xl border border-yellow-400/15 bg-black/85 px-4 py-4 shadow-2xl backdrop-blur-md sm:bottom-24 sm:w-[90%] sm:px-5"
            >
              <div className="flex items-center justify-between gap-3">
                <span className="text-[10px] font-bold uppercase tracking-widest text-yellow-300">
                  Local ASR Loading
                </span>
                <span className="text-[10px] text-white/50">
                  {SHERPA_LOAD_PROGRESS[localAsrLoadState.stage]}%
                </span>
              </div>
              <div className="mt-3 h-2 overflow-hidden rounded-full bg-white/10">
                <motion.div
                  animate={{
                    width: `${SHERPA_LOAD_PROGRESS[localAsrLoadState.stage]}%`,
                  }}
                  className="h-full rounded-full bg-yellow-400"
                />
              </div>
              <div className="mt-3 text-sm text-white">
                {localAsrLoadState.message}
              </div>
              {localAsrLoadState.error ? (
                <div className="mt-2 text-xs text-rose-300">
                  {localAsrLoadState.error}
                </div>
              ) : null}
            </motion.div>
          )}

        {lastTranscription && settings.scrollMode === speechScrollMode && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
            className="pointer-events-none fixed bottom-28 left-1/2 z-50 flex w-[92%] max-w-2xl -translate-x-1/2 items-center justify-center rounded-3xl border border-white/10 bg-black/80 px-4 py-3 shadow-2xl backdrop-blur-md sm:bottom-24 sm:w-[90%] sm:rounded-full sm:px-6"
          >
            <div className="flex w-full items-center gap-4">
              <div className="flex shrink-0 items-center gap-2">
                <div className="h-2 w-2 animate-pulse rounded-full bg-yellow-400" />
                <span className="text-[10px] font-bold uppercase tracking-widest text-white/70">
                  Live ASR:
                </span>
              </div>
              <span className="truncate text-sm font-medium text-white">
                {lastTranscription}
              </span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <TooltipProvider delayDuration={200}>
        <div className="absolute bottom-4 left-1/2 z-50 flex max-w-[calc(100vw-16px)] -translate-x-1/2 flex-wrap items-center justify-center gap-2 rounded-3xl border-[0.5px] border-white/10 bg-black/40 p-2 shadow-2xl backdrop-blur-xl sm:bottom-8 sm:max-w-none sm:gap-1 sm:rounded-full">
        <div className="flex items-center gap-1 border-r border-white/10 px-2">
            <ToolbarBtn
              tooltip="手动滚动"
              variant="ghost"
              size="icon"
              onClick={() =>
                setSettings((s) => ({
                  ...s,
                  scrollMode: 'manual',
                  isScrolling: false,
                }))
              }
              className={
                settings.scrollMode === 'manual'
                  ? 'bg-yellow-400 text-black'
                  : 'text-neutral-500 hover:text-white'
              }
            >
              <MousePointer2 size={18} />
            </ToolbarBtn>
            <ToolbarBtn
              tooltip="匀速滚动"
              variant="ghost"
              size="icon"
              onClick={() =>
                setSettings((s) => ({
                  ...s,
                  scrollMode: 'auto',
                  isScrolling: false,
                }))
              }
              className={
                settings.scrollMode === 'auto'
                  ? 'bg-yellow-400 text-black'
                  : 'text-neutral-500 hover:text-white'
              }
            >
              <Clock size={18} />
            </ToolbarBtn>
            <ToolbarBtn
              tooltip="本地跟读"
              variant="ghost"
              size="icon"
              onClick={() =>
                setSettings((s) => ({
                  ...s,
                  scrollMode: 'local',
                  isScrolling: false,
                }))
              }
              className={
                settings.scrollMode === 'local'
                  ? 'bg-yellow-400 text-black'
                  : 'text-neutral-500 hover:text-white'
              }
            >
              <Radio size={18} />
            </ToolbarBtn>
          </div>

          <div className="flex items-center gap-1 px-2">
            <ToolbarBtn tooltip="后退" variant="ghost" size="icon" onClick={() => jumpIndex(-20)}>
              <Rewind size={18} />
            </ToolbarBtn>
            <ToolbarBtn
              tooltip={settings.isScrolling ? '暂停' : '播放'}
              variant="ghost"
              size="icon"
              onClick={toggleScrolling}
              className={
                settings.isScrolling
                  ? 'bg-yellow-400/10 text-yellow-400'
                  : 'bg-yellow-400 text-black'
              }
            >
              {settings.isScrolling ? (
                <PauseCircle size={24} />
              ) : (
                <PlayCircle size={24} />
              )}
            </ToolbarBtn>
            <ToolbarBtn tooltip="快进" variant="ghost" size="icon" onClick={() => jumpIndex(20)}>
              <FastForward size={18} />
            </ToolbarBtn>
          </div>

        {settings.scrollMode === 'auto' && (
          <div className="relative border-l border-neutral-800 pl-2 pr-2">
            <button
              type="button"
              onClick={() => setShowSpeedMenu(!showSpeedMenu)}
              className="flex items-center gap-2 rounded-full bg-neutral-800/50 px-3 py-2 text-[10px] font-bold uppercase tracking-wider text-neutral-400 transition-all hover:text-white"
            >
              字速: {settings.wpn} WPM <ChevronDown size={12} />
            </button>

            <AnimatePresence>
              {showSpeedMenu && (
                <motion.div
                  initial={{ opacity: 0, y: 10, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 10, scale: 0.95 }}
                  className="absolute bottom-full left-1/2 z-[100] mb-4 w-48 -translate-x-1/2 rounded-2xl border border-neutral-800 bg-neutral-900 p-2 shadow-2xl"
                >
                  <div className="mb-1 border-b border-neutral-800 px-3 py-2 text-[8px] font-bold uppercase tracking-widest text-neutral-600">
                    预置速度
                  </div>
                  {SPEED_PRESETS.map((p) => (
                    <button
                      key={p.id}
                      type="button"
                      onClick={() => {
                        setSettings((s) => ({ ...s, wpn: p.wpn }));
                        setShowSpeedMenu(false);
                      }}
                      className={`flex w-full flex-col gap-0.5 rounded-xl p-3 text-left transition-all ${
                        settings.wpn === p.wpn
                          ? 'bg-yellow-400/10 text-yellow-400'
                          : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold">{p.name}</span>
                        <span className="text-[10px] font-mono opacity-50">
                          {p.wpn} WPM
                        </span>
                      </div>
                      <span className="text-[9px] opacity-40">
                        {p.description}
                      </span>
                    </button>
                  ))}
                  <div className="mt-2 px-3 pb-2">
                    <Slider
                      min={60}
                      max={450}
                      step={10}
                      value={[settings.wpn]}
                      onValueChange={(value) =>
                        setSettings((s) => ({
                          ...s,
                          wpn: value[0] ?? s.wpn,
                        }))
                      }
                    />
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        )}

        {settings.scrollMode === 'local' && (
          <div className="flex items-center gap-2 border-l border-neutral-800 px-4">
            <div
              className={`h-2 w-2 rounded-full ${
                settings.isScrolling
                  ? 'animate-pulse bg-yellow-400'
                  : 'bg-neutral-700'
              }`}
            />
            <span className="text-[10px] font-bold uppercase tracking-widest text-neutral-500">
              {activeAsrLabel}
            </span>
          </div>
        )}
      </div>
      </TooltipProvider>
    </div>
  );
};
