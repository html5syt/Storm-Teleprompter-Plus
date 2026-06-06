/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { 
  Settings, Maximize2, Minimize2, AlertCircle, CheckCircle2, 
  XCircle, Moon, Sun, Type, AlignJustify, FlipHorizontal, 
  Plus, FileText, Play, Trash2, Edit3, ChevronLeft, Search, Clock,
  Mic, MicOff, PlayCircle, PauseCircle, MousePointer2, FastForward,
  Bug, AlertTriangle, Rewind, ChevronDown
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { FeishuASRClient } from './lib/feishu';
import { alignmentEngine } from './lib/alignment';

// --- Types ---
interface Script {
  id: string;
  title: string;
  content: string;
  lastModified: number;
}

interface GlobalSettings {
  feishuAppId: string;
  feishuAppSecret: string;
  feishuBaseUrl: string;
  feishuEngineType: string;
}

interface TeleprompterSettings {
  fontSize: number;
  lineHeight: number;
  mirrorMode: boolean;
  showSettings: boolean;
  scrollMode: 'manual' | 'auto' | 'cloud';
  wpn: number;
  isScrolling: boolean;
}

// --- Constants ---
const STORAGE_KEY = 'teleprompter_scripts';
const GLOBAL_SETTINGS_KEY = 'teleprompter_global_settings';

const SPEED_PRESETS = [
  { id: 'slow', name: '龟速', description: '适合深情朗读', wpn: 80 },
  { id: 'normal', name: '标准', description: '普通语速', wpn: 160 },
  { id: 'fast', name: '快语', description: '适合新闻播报', wpn: 240 },
  { id: 'very-fast', name: '极速', description: '适合快节奏内容', wpn: 320 },
];

const DEFAULT_GLOBAL_SETTINGS: GlobalSettings = {
  feishuAppId: '',
  feishuAppSecret: '',
  feishuBaseUrl: '/feishu-api',
  feishuEngineType: '16k_auto'
};

const DEFAULT_SCRIPTS: Script[] = [
  {
    id: 'default-1',
    title: '欢迎使用 Thin UI 提词器',
    content: '欢迎使用 Thin UI 提词器。这是一个纯视觉渲染层，支持通过飞书云 ASR 进行语音同步滚动。您可以点击右上角的设置按钮来配置飞书 API、调整字号、行距或开启镜像模式。',
    lastModified: Date.now()
  }
];

// --- Components ---

/**
 * Teleprompter View Component
 */
const TeleprompterView = ({ 
  script, 
  onBack, 
  onUpdateScript,
  feishuConfig,
  setToast
}: { 
  script: Script; 
  onBack: () => void;
  onUpdateScript: (id: string, content: string) => void;
  feishuConfig: {
    appId: string;
    appSecret: string;
    baseUrl: string;
    engineType: string;
  };
  setToast: (toast: { message: string; type: 'success' | 'error' } | null) => void;
}) => {
  const [currentIndex, setCurrentIndex] = useState<number>(-1);
  const currentIndexRef = useRef<number>(-1);
  const [lastTranscription, setLastTranscription] = useState<string>('');
  const [showSpeedMenu, setShowSpeedMenu] = useState(false);
  const [rms, setRms] = useState(0);
  const feishuClientRef = useRef<FeishuASRClient | null>(null);
  const [debugStats, setDebugStats] = useState({
    droppedCount: 0,
    strategy: 'none'
  });
  const isManualActionRef = useRef<boolean>(false);
  const [settings, setSettings] = useState<TeleprompterSettings>({
    fontSize: 64,
    lineHeight: 1.5,
    mirrorMode: false,
    showSettings: false,
    scrollMode: 'cloud',
    wpn: 160,
    isScrolling: false
  });

  const containerRef = useRef<HTMLDivElement>(null);

  const tokens = useMemo(() => {
    // Split by characters but keep track of original positions
    return script.content.split('').map((char, index) => ({
      id: `word_${index}`,
      char,
      index
    }));
  }, [script.content]);

  const updateCurrentIndex = useCallback((index: number, isRemote: boolean = false) => {
    if (isRemote) {
      console.log(`[Teleprompter] Remote update to index: ${index}`);
    }

    if (isRemote && index < currentIndexRef.current) {
      console.log(`[Teleprompter] Dropped backward jump: ${index} < ${currentIndexRef.current}`);
      setDebugStats(prev => ({ ...prev, droppedCount: prev.droppedCount + 1 }));
      return;
    }

    if (!isRemote) {
      alignmentEngine.setCurrentIndex(index);
    }
    
    const prevIndex = currentIndexRef.current;
    currentIndexRef.current = index;
    setCurrentIndex(index);

    // 1) & 7) Incremental DOM updates using CSS classes
    // Remove active from previous
    if (prevIndex !== -1) {
      const prevEl = document.getElementById(`word_${prevIndex}`);
      if (prevEl) prevEl.classList.remove('word-active');
    }

    // Add active to current and mark as read
    const currentEl = document.getElementById(`word_${index}`);
    if (currentEl) {
      currentEl.classList.add('word-active');
      currentEl.classList.remove('word-read');
    }

    // Mark range as read (incremental)
    if (index > prevIndex) {
      for (let i = Math.max(0, prevIndex); i < index; i++) {
        const el = document.getElementById(`word_${i}`);
        if (el) {
          el.classList.add('word-read');
          el.classList.remove('word-active');
        }
      }
    } else if (index < prevIndex) {
      // If jumping back manually, reset read state for the range
      for (let i = index + 1; i <= prevIndex; i++) {
        const el = document.getElementById(`word_${i}`);
        if (el) {
          el.classList.remove('word-read');
          el.classList.remove('word-active');
        }
      }
    }

    if (currentEl) {
      currentEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, []);

  // Initialize Feishu Client
  useEffect(() => {
    console.log(`[Teleprompter] Initializing Feishu Client with config:`, feishuConfig);
    console.log(`[Teleprompter] Setting script content (length: ${script.content.length})`);
    feishuClientRef.current = new FeishuASRClient(feishuConfig);
    alignmentEngine.setScript(script.content);
    currentIndexRef.current = -1;
    setCurrentIndex(-1);
    setDebugStats({ droppedCount: 0, strategy: 'none' });
  }, [feishuConfig, script.content]);

  // Cloud ASR control
  useEffect(() => {
    const shouldCloudBeOn = settings.scrollMode === 'cloud' && settings.isScrolling;
    console.log(`[Teleprompter] Cloud ASR control: shouldCloudBeOn=${shouldCloudBeOn}, mode=${settings.scrollMode}, scrolling=${settings.isScrolling}`);
    
    if (shouldCloudBeOn) {
      console.log('[Teleprompter] Starting Feishu ASR...');
      feishuClientRef.current?.start(
        (text) => {
          setLastTranscription(text);
          const result = alignmentEngine.consumeTranscript(text, false);
          updateCurrentIndex(result.index, true);
          setDebugStats(prev => ({ ...prev, strategy: result.meta.strategy }));
        },
        (text) => {
          setLastTranscription(text);
          const result = alignmentEngine.consumeTranscript(text, true);
          updateCurrentIndex(result.index, true);
          setDebugStats(prev => ({ ...prev, strategy: result.meta.strategy }));
        },
        (rmsValue) => setRms(rmsValue)
      ).catch(error => {
        console.error('ASR Start Error:', error);
        setToast({ message: error.message || '语音同步启动失败', type: 'error' });
        setSettings(s => ({ ...s, isScrolling: false }));
      });
    } else {
      feishuClientRef.current?.stop();
    }

    return () => {
      feishuClientRef.current?.stop();
    };
  }, [settings.scrollMode, settings.isScrolling, updateCurrentIndex]);

  const handleTokenClick = (index: number) => {
    isManualActionRef.current = true;
    updateCurrentIndex(index);
  };

  const jumpIndex = (delta: number) => {
    isManualActionRef.current = true;
    const newIndex = Math.max(0, Math.min(tokens.length - 1, currentIndexRef.current + delta));
    updateCurrentIndex(newIndex);
  };

  // Auto-scroll logic (WPN based character progression)
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
          
          const newIndex = Math.min(tokens.length - 1, currentIndexRef.current + charsToAdvance);
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

    return () => { if (rafId) cancelAnimationFrame(rafId); };
  }, [settings.scrollMode, settings.isScrolling, settings.wpn, updateCurrentIndex, tokens.length]);

  const toggleScrolling = () => {
    setSettings(s => ({ ...s, isScrolling: !s.isScrolling }));
  };

  const handleContentChange = (newText: string) => {
    onUpdateScript(script.id, newText);
  };

  return (
    <div className="h-screen w-screen bg-black flex flex-col overflow-hidden font-sans relative">
      {/* Debug Overlay */}
      <div className="fixed bottom-6 left-6 z-[100] flex flex-col gap-2 pointer-events-none">
        <div className="px-3 py-2 bg-black/60 backdrop-blur-md border border-white/10 rounded-lg flex flex-col gap-1">
          <div className="flex items-center gap-2 text-[10px] font-bold text-white/40 uppercase tracking-widest">
            <Bug size={10} /> Debug Monitor
          </div>
          <div className="grid grid-cols-2 gap-x-4 gap-y-1">
            <div className="flex justify-between gap-4">
              <span className="text-[10px] text-white/40">WPN:</span>
              <span className="text-[10px] font-mono text-green-400">{settings.wpn}</span>
            </div>
            <div className="flex justify-between gap-4">
              <span className="text-[10px] text-white/40">DROPPED:</span>
              <span className="text-[10px] font-mono text-yellow-400">{debugStats.droppedCount}</span>
            </div>
            <div className="flex justify-between gap-4 col-span-2">
              <span className="text-[10px] text-white/40">STRATEGY:</span>
              <span className="text-[10px] font-mono text-blue-400 uppercase">{debugStats.strategy}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Top Bar */}
      <div className="absolute top-0 left-0 right-0 z-50 p-4 flex justify-between items-center bg-gradient-to-b from-black/90 to-transparent pointer-events-none">
        <div className="flex items-center gap-4 pointer-events-auto">
          <button 
            onClick={onBack}
            className="p-2 rounded-full bg-neutral-900/50 text-neutral-400 hover:text-white hover:bg-neutral-800 transition-colors"
          >
            <ChevronLeft size={20} />
          </button>
        </div>

        <div className="flex items-center gap-2 pointer-events-auto">
          <h1 className="text-neutral-500 text-xs font-medium mr-4 truncate max-w-[200px]">{script.title}</h1>
          
          <button 
            onClick={() => setSettings(s => ({ ...s, showSettings: !s.showSettings }))}
            className="p-2 rounded-full bg-neutral-900/50 text-neutral-400 hover:text-white hover:bg-neutral-800 transition-colors"
          >
            <Settings size={20} />
          </button>
        </div>
      </div>

      {/* Prompter Content */}
      <div 
        ref={containerRef}
        className={`flex-1 overflow-y-auto px-[10%] py-[45vh] teleprompter-container ${settings.mirrorMode ? 'mirror-mode' : ''}`}
        style={{ fontSize: `${settings.fontSize}px`, lineHeight: settings.lineHeight, scrollbarWidth: 'none' }}
      >
        <div className="max-w-4xl mx-auto text-center">
          {tokens.map((token) => (
            <span 
              key={token.id} id={token.id}
              onClick={() => handleTokenClick(token.index)}
              className="word transition-colors duration-300 inline-block cursor-pointer hover:bg-white/10 rounded px-0.5 text-neutral-400"
            >
              {token.char === '\n' ? <br /> : token.char}
            </span>
          ))}
        </div>
      </div>

      {/* Settings Drawer */}
      <AnimatePresence>
        {settings.showSettings && (
          <>
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setSettings(s => ({ ...s, showSettings: false }))} className="absolute inset-0 bg-black/60 z-[60]" />
            <motion.div initial={{ x: '100%' }} animate={{ x: 0 }} exit={{ x: '100%' }} transition={{ type: 'spring', damping: 25, stiffness: 200 }} className="absolute top-0 right-0 bottom-0 w-80 bg-neutral-900 border-l border-neutral-800 z-[70] p-6 flex flex-col gap-8 shadow-2xl">
              <div className="flex justify-between items-center">
                <h2 className="text-lg font-semibold text-white flex items-center gap-2"><Settings size={20} /> 提词设置</h2>
                <button onClick={() => setSettings(s => ({ ...s, showSettings: false }))} className="text-neutral-500 hover:text-white"><Minimize2 size={20} /></button>
              </div>

              <div className="space-y-6">
                <div className="space-y-4">
                  <div className="flex justify-between text-sm"><span className="text-neutral-400 flex items-center gap-2"><Type size={16} /> 字号</span><span className="text-white font-mono">{settings.fontSize}px</span></div>
                  <input type="range" min="24" max="120" step="2" value={settings.fontSize} onChange={(e) => setSettings(s => ({ ...s, fontSize: parseInt(e.target.value) }))} className="w-full accent-yellow-500" />
                </div>
                <div className="space-y-4">
                  <div className="flex justify-between text-sm"><span className="text-neutral-400 flex items-center gap-2"><AlignJustify size={16} /> 行距</span><span className="text-white font-mono">{settings.lineHeight}</span></div>
                  <input type="range" min="1" max="2.5" step="0.1" value={settings.lineHeight} onChange={(e) => setSettings(s => ({ ...s, lineHeight: parseFloat(e.target.value) }))} className="w-full accent-yellow-500" />
                </div>
                <div className="flex items-center justify-between p-4 bg-neutral-800 rounded-xl">
                  <div className="flex items-center gap-3"><FlipHorizontal size={18} className="text-neutral-400" /><div><span className="text-sm text-white block">镜像模式</span><span className="text-[10px] text-neutral-500">用于分光镜反射</span></div></div>
                  <button onClick={() => setSettings(s => ({ ...s, mirrorMode: !s.mirrorMode }))} className={`w-12 h-6 rounded-full transition-colors relative ${settings.mirrorMode ? 'bg-yellow-500' : 'bg-neutral-700'}`}><motion.div animate={{ x: settings.mirrorMode ? 24 : 4 }} className="absolute top-1 left-0 w-4 h-4 bg-white rounded-full shadow-sm" /></button>
                </div>
              </div>

              <div className="flex-1 flex flex-col gap-3 min-h-0">
                <span className="text-sm text-neutral-400">稿件内容 (实时同步)</span>
                <textarea value={script.content} onChange={(e) => handleContentChange(e.target.value)} className="flex-1 bg-neutral-800 border border-neutral-700 rounded-xl p-4 text-sm text-neutral-300 focus:outline-none focus:border-yellow-500 resize-none font-sans" placeholder="在此输入或粘贴您的提词稿件..." />
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      <div className="absolute top-1/2 left-0 right-0 h-px bg-yellow-500/30 pointer-events-none z-10">
        <div className="absolute left-4 top-1/2 -translate-y-1/2 text-[10px] uppercase tracking-widest text-yellow-500/50 font-mono">Reading Area</div>
      </div>

      {/* Live Transcription Feedback */}
      <AnimatePresence>
        {lastTranscription && settings.scrollMode === 'cloud' && (
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
            className="fixed bottom-24 left-1/2 -translate-x-1/2 z-50 px-4 py-2 bg-black/80 backdrop-blur-md border border-white/10 rounded-full shadow-2xl pointer-events-none"
          >
            <div className="flex items-center gap-3">
              <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
              <span className="text-white/70 text-[10px] font-bold uppercase tracking-widest">Live ASR:</span>
              <span className="text-white text-sm font-medium">{lastTranscription}</span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Bottom Controller */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-50 flex items-center gap-1 p-2 bg-neutral-900/80 backdrop-blur-xl border border-neutral-800 rounded-full shadow-2xl">
        {/* Mode Selector */}
        <div className="flex items-center gap-1 px-2 border-r border-neutral-800">
          <button 
            onClick={() => setSettings(s => ({ ...s, scrollMode: 'manual', isScrolling: false }))}
            className={`p-2 rounded-full transition-all ${settings.scrollMode === 'manual' ? 'bg-yellow-500 text-black' : 'text-neutral-500 hover:text-white'}`}
            title="手动控制"
          >
            <MousePointer2 size={18} />
          </button>
          <button 
            onClick={() => setSettings(s => ({ ...s, scrollMode: 'auto', isScrolling: true }))}
            className={`p-2 rounded-full transition-all ${settings.scrollMode === 'auto' ? 'bg-yellow-500 text-black' : 'text-neutral-500 hover:text-white'}`}
            title="自动滚动"
          >
            <Clock size={18} />
          </button>
          <button 
            onClick={() => setSettings(s => ({ ...s, scrollMode: 'cloud', isScrolling: true }))}
            className={`p-2 rounded-full transition-all ${settings.scrollMode === 'cloud' ? 'bg-yellow-500 text-black' : 'text-neutral-500 hover:text-white'}`}
            title="云 ASR (飞书)"
          >
            <div className="relative">
              <Mic size={18} />
              {settings.scrollMode === 'cloud' && settings.isScrolling && (
                <motion.div 
                  animate={{ height: `${Math.min(100, rms * 500)}%` }}
                  className="absolute bottom-0 -right-1 w-1 bg-green-500 rounded-full"
                />
              )}
            </div>
          </button>
        </div>

        {/* Playback Controls */}
        <div className="flex items-center gap-1 px-2">
          <button 
            onClick={() => jumpIndex(-20)}
            className="p-2 text-neutral-500 hover:text-white transition-all"
            title="后退"
          >
            <Rewind size={18} />
          </button>

          <button 
            onClick={toggleScrolling}
            className={`p-3 rounded-full transition-all ${settings.isScrolling ? 'bg-yellow-500/10 text-yellow-500' : 'bg-yellow-500 text-black shadow-[0_0_15px_rgba(234,179,8,0.4)]'}`}
            title={settings.isScrolling ? "暂停" : "播放"}
          >
            {settings.isScrolling ? <PauseCircle size={24} /> : <PlayCircle size={24} />}
          </button>

          <button 
            onClick={() => jumpIndex(20)}
            className="p-2 text-neutral-500 hover:text-white transition-all"
            title="快进"
          >
            <FastForward size={18} />
          </button>
        </div>

        {/* Speed Selector (Only for Auto Mode) */}
        {settings.scrollMode === 'auto' && (
          <div className="relative border-l border-neutral-800 pl-2 pr-2">
            <button 
              onClick={() => setShowSpeedMenu(!showSpeedMenu)}
              className="flex items-center gap-2 px-3 py-2 rounded-full bg-neutral-800/50 text-neutral-400 hover:text-white transition-all text-[10px] font-bold uppercase tracking-wider"
            >
              字速: {settings.wpn} WPN <ChevronDown size={12} />
            </button>

            <AnimatePresence>
              {showSpeedMenu && (
                <motion.div 
                  initial={{ opacity: 0, y: 10, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 10, scale: 0.95 }}
                  className="absolute bottom-full mb-4 left-1/2 -translate-x-1/2 w-48 bg-neutral-900 border border-neutral-800 rounded-2xl p-2 shadow-2xl z-[100]"
                >
                  <div className="text-[8px] font-bold text-neutral-600 uppercase tracking-widest px-3 py-2 border-b border-neutral-800 mb-1">预置速度</div>
                  {SPEED_PRESETS.map((p) => (
                    <button 
                      key={p.id}
                      onClick={() => {
                        setSettings(s => ({ ...s, wpn: p.wpn }));
                        setShowSpeedMenu(false);
                      }}
                      className={`w-full text-left p-3 rounded-xl transition-all flex flex-col gap-0.5 ${settings.wpn === p.wpn ? 'bg-yellow-500/10 text-yellow-500' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}
                    >
                      <div className="flex justify-between items-center">
                        <span className="text-xs font-bold">{p.name}</span>
                        <span className="text-[10px] font-mono opacity-50">{p.wpn} WPN</span>
                      </div>
                      <span className="text-[9px] opacity-40">{p.description}</span>
                    </button>
                  ))}
                  <div className="mt-2 px-3 pb-2">
                    <input 
                      type="range" 
                      min="60" 
                      max="360" 
                      step="20" 
                      value={settings.wpn} 
                      onChange={(e) => setSettings(s => ({ ...s, wpn: parseInt(e.target.value) }))}
                      className="w-full accent-yellow-500 h-1"
                    />
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        )}

        {/* Cloud ASR Indicator */}
        {settings.scrollMode === 'cloud' && (
          <div className="flex items-center gap-2 px-4 border-l border-neutral-800">
            <div className={`w-2 h-2 rounded-full ${settings.isScrolling ? 'bg-green-500 animate-pulse' : 'bg-neutral-700'}`} />
            <span className="text-[10px] uppercase tracking-widest text-neutral-500 font-bold">Cloud ASR Active</span>
          </div>
        )}
      </div>
    </div>
  );
};

/**
 * Script Editor Component
 */
const ScriptEditor = ({ 
  script, 
  onBack, 
  onSave 
}: { 
  script: Script; 
  onBack: () => void;
  onSave: (id: string, title: string, content: string) => void;
}) => {
  const [title, setTitle] = useState(script.title);
  const [content, setContent] = useState(script.content);

  const handleSave = () => {
    onSave(script.id, title, content);
    onBack();
  };

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: 20 }}
      className="min-h-screen bg-black flex flex-col font-sans"
    >
      <header className="h-20 border-b border-neutral-900 flex items-center justify-between px-6 bg-black/50 backdrop-blur-xl sticky top-0 z-50">
        <div className="flex items-center gap-4">
          <button onClick={onBack} className="p-2 rounded-full hover:bg-neutral-800 text-neutral-400 hover:text-white transition-colors">
            <ChevronLeft size={20} />
          </button>
          <h1 className="text-lg font-bold">编辑稿件</h1>
        </div>
        <button 
          onClick={handleSave}
          className="bg-yellow-500 hover:bg-yellow-400 text-black px-6 py-2 rounded-full text-sm font-bold transition-all active:scale-95 shadow-[0_0_20px_rgba(234,179,8,0.2)]"
        >
          保存修改
        </button>
      </header>

      <main className="flex-1 max-w-4xl mx-auto w-full p-6 flex flex-col gap-6">
        <div className="space-y-2">
          <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">稿件标题</label>
          <input 
            type="text" 
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full bg-neutral-900 border border-neutral-800 rounded-xl p-4 text-xl font-bold text-white focus:outline-none focus:border-yellow-500/50 transition-all"
            placeholder="输入稿件标题..."
          />
        </div>

        <div className="flex-1 flex flex-col gap-2 min-h-[400px]">
          <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">正文内容</label>
          <textarea 
            value={content}
            onChange={(e) => setContent(e.target.value)}
            className="flex-1 bg-neutral-900 border border-neutral-800 rounded-xl p-6 text-lg leading-relaxed text-neutral-300 focus:outline-none focus:border-yellow-500/50 transition-all resize-none"
            placeholder="在此输入您的提词稿件内容..."
          />
        </div>
      </main>
    </motion.div>
  );
};

/**
 * Main App Shell
 */
export default function App() {
  const [view, setView] = useState<'manager' | 'prompter' | 'editor'>('manager');
  const [scripts, setScripts] = useState<Script[]>([]);
  const [activeScriptId, setActiveScriptId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [globalSettings, setGlobalSettings] = useState<GlobalSettings>(DEFAULT_GLOBAL_SETTINGS);
  const [showGlobalSettings, setShowGlobalSettings] = useState(false);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' } | null>(null);

  // Manage body overflow based on view
  useEffect(() => {
    if (view === 'prompter') {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'auto';
    }
    return () => {
      document.body.style.overflow = 'auto';
    };
  }, [view]);

  // Load scripts and settings from localStorage
  useEffect(() => {
    const savedScripts = localStorage.getItem(STORAGE_KEY);
    if (savedScripts) {
      setScripts(JSON.parse(savedScripts));
    } else {
      setScripts(DEFAULT_SCRIPTS);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(DEFAULT_SCRIPTS));
    }

    const savedSettings = localStorage.getItem(GLOBAL_SETTINGS_KEY);
    if (savedSettings) {
      try {
        const parsed = JSON.parse(savedSettings);
        // Migrate old open.feishu.cn or lark domains to proxy to bypass CORS
        if (parsed.feishuBaseUrl === 'https://open.feishu.cn') {
          parsed.feishuBaseUrl = '/feishu-api';
          localStorage.setItem(GLOBAL_SETTINGS_KEY, JSON.stringify(parsed));
        } else if (parsed.feishuBaseUrl.includes('larkoffice.com') || parsed.feishuBaseUrl.includes('larksuite.com')) {
          parsed.feishuBaseUrl = '/lark-api';
          localStorage.setItem(GLOBAL_SETTINGS_KEY, JSON.stringify(parsed));
        }
        setGlobalSettings({ ...DEFAULT_GLOBAL_SETTINGS, ...parsed });
      } catch (e) {
        console.error('Failed to parse settings', e);
      }
    }
  }, []);

  // Save scripts to localStorage
  const saveScripts = (updated: Script[]) => {
    setScripts(updated);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
  };

  // Save global settings to localStorage
  const saveGlobalSettings = (updated: GlobalSettings) => {
    setGlobalSettings(updated);
    localStorage.setItem(GLOBAL_SETTINGS_KEY, JSON.stringify(updated));
  };

  const addScript = () => {
    const newScript: Script = {
      id: crypto.randomUUID(),
      title: '未命名稿件',
      content: '',
      lastModified: Date.now()
    };
    saveScripts([newScript, ...scripts]);
    setActiveScriptId(newScript.id);
    setView('editor');
  };

  const deleteScript = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setDeleteConfirmId(id);
  };

  const confirmDelete = () => {
    if (deleteConfirmId) {
      saveScripts(scripts.filter(s => s.id !== deleteConfirmId));
      setDeleteConfirmId(null);
    }
  };

  const updateScript = (id: string, title: string, content: string) => {
    const updated = scripts.map(s => s.id === id ? { ...s, title, content, lastModified: Date.now() } : s);
    saveScripts(updated);
  };

  const updateScriptContent = (id: string, content: string) => {
    const updated = scripts.map(s => s.id === id ? { ...s, content, lastModified: Date.now() } : s);
    saveScripts(updated);
  };

  const filteredScripts = scripts.filter(s => 
    s.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
    s.content.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const activeScript = scripts.find(s => s.id === activeScriptId);

  if (view === 'prompter' && activeScript) {
    return (
      <TeleprompterView 
        script={activeScript} 
        onBack={() => setView('manager')} 
        onUpdateScript={updateScriptContent}
        feishuConfig={{
          appId: globalSettings.feishuAppId,
          appSecret: globalSettings.feishuAppSecret,
          baseUrl: globalSettings.feishuBaseUrl.includes('open.feishu.cn') 
            ? '/feishu-api' 
            : (globalSettings.feishuBaseUrl.includes('larkoffice.com') || globalSettings.feishuBaseUrl.includes('larksuite.com'))
              ? '/lark-api'
              : globalSettings.feishuBaseUrl,
          engineType: globalSettings.feishuEngineType
        }}
        setToast={setToast}
      />
    );
  }

  if (view === 'editor' && activeScript) {
    return (
      <ScriptEditor 
        script={activeScript}
        onBack={() => setView('manager')}
        onSave={updateScript}
      />
    );
  }

  return (
    <div className="min-h-screen bg-[#050505] text-white font-sans selection:bg-yellow-500/30 flex flex-col overflow-y-auto">
      {/* Manager Header */}
      <header className="border-b border-neutral-900 bg-black/50 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-6xl mx-auto px-6 h-20 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-yellow-500 rounded-xl flex items-center justify-center text-black shadow-[0_0_20px_rgba(234,179,8,0.3)]">
              <FileText size={24} />
            </div>
            <div>
              <h1 className="text-lg font-bold tracking-tight">稿件管理</h1>
              <p className="text-[10px] text-neutral-500 uppercase tracking-widest font-mono">Thin UI Teleprompter</p>
            </div>
          </div>

          <div className="flex items-center gap-4">
            <div className="relative group">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-neutral-600 group-focus-within:text-yellow-500 transition-colors" size={16} />
              <input 
                type="text" 
                placeholder="搜索稿件..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="bg-neutral-900 border border-neutral-800 rounded-full py-2 pl-10 pr-4 text-sm w-64 focus:outline-none focus:border-yellow-500/50 transition-all"
              />
            </div>
            <button 
              onClick={() => setShowGlobalSettings(true)}
              className="p-2 rounded-full bg-neutral-900 border border-neutral-800 text-neutral-400 hover:text-white hover:border-neutral-700 transition-all"
              title="系统设置"
            >
              <Settings size={20} />
            </button>
            <button 
              onClick={addScript}
              className="bg-yellow-500 hover:bg-yellow-400 text-black px-4 py-2 rounded-full text-sm font-bold flex items-center gap-2 transition-all active:scale-95 shadow-[0_0_20px_rgba(234,179,8,0.2)]"
            >
              <Plus size={18} /> 新建稿件
            </button>
          </div>
        </div>
      </header>

      {/* Manager Content */}
      <main className="max-w-6xl mx-auto px-6 py-12 pb-32">
        {filteredScripts.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-32 text-center">
            <div className="w-20 h-20 bg-neutral-900 rounded-3xl flex items-center justify-center text-neutral-700 mb-6">
              <FileText size={40} />
            </div>
            <h3 className="text-xl font-medium text-neutral-400">暂无稿件</h3>
            <p className="text-neutral-600 text-sm mt-2 max-w-xs">点击右上角的“新建稿件”按钮开始创作您的第一个提词脚本。</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredScripts.map((s) => (
              <motion.div 
                layoutId={s.id}
                key={s.id}
                onClick={() => { setActiveScriptId(s.id); setView('prompter'); }}
                className="group bg-neutral-900/40 border border-neutral-800/50 rounded-2xl p-6 hover:bg-neutral-900 hover:border-yellow-500/30 transition-all cursor-pointer relative overflow-hidden"
              >
                <div className="flex justify-between items-start mb-4">
                  <div className="p-2 bg-neutral-800 rounded-lg text-neutral-400 group-hover:text-yellow-500 transition-colors">
                    <FileText size={20} />
                  </div>
                  <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button 
                      onClick={(e) => { e.stopPropagation(); setActiveScriptId(s.id); setView('editor'); }}
                      className="p-2 hover:bg-neutral-800 rounded-lg text-neutral-400 hover:text-white"
                    >
                      <Edit3 size={16} />
                    </button>
                    <button 
                      onClick={(e) => deleteScript(s.id, e)}
                      className="p-2 hover:bg-red-500/10 rounded-lg text-neutral-400 hover:text-red-400"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>

                <h3 className="text-lg font-semibold text-white mb-2 truncate">{s.title}</h3>

                <p className="text-neutral-500 text-sm line-clamp-3 mb-6 leading-relaxed">
                  {s.content || <span className="italic text-neutral-700">无内容...</span>}
                </p>

                <div className="flex items-center justify-between pt-4 border-t border-neutral-800/50">
                  <div className="flex items-center gap-2 text-[10px] text-neutral-600 font-mono uppercase tracking-wider">
                    <Clock size={12} />
                    {new Date(s.lastModified).toLocaleDateString()}
                  </div>
                  <div className="flex items-center gap-2 text-yellow-500 text-xs font-bold opacity-0 group-hover:opacity-100 transition-all translate-x-4 group-hover:translate-x-0">
                    开始提词 <Play size={14} fill="currentColor" />
                  </div>
                </div>

                {/* Hover Glow Effect */}
                <div className="absolute -bottom-10 -right-10 w-32 h-32 bg-yellow-500/5 blur-[60px] rounded-full group-hover:bg-yellow-500/10 transition-all" />
              </motion.div>
            ))}
          </div>
        )}
      </main>

      {/* Global Settings Drawer */}
      <AnimatePresence>
        {showGlobalSettings && (
          <>
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowGlobalSettings(false)}
              className="absolute inset-0 bg-black/60 z-[60]"
            />
            <motion.div 
              initial={{ x: '100%' }}
              animate={{ x: 0 }}
              exit={{ x: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="absolute top-0 right-0 bottom-0 w-80 bg-neutral-900 border-l border-neutral-800 z-[70] p-6 flex flex-col gap-8 shadow-2xl"
            >
              <div className="flex justify-between items-center">
                <h2 className="text-lg font-semibold text-white flex items-center gap-2">
                  <Settings size={20} /> 系统设置
                </h2>
                <button onClick={() => setShowGlobalSettings(false)} className="text-neutral-500 hover:text-white">
                  <Minimize2 size={20} />
                </button>
              </div>

              <div className="space-y-6">
                <div className="space-y-4">
                  <h3 className="text-xs font-bold text-neutral-400 uppercase tracking-widest">云 ASR (飞书) 配置</h3>
                  
                  <div className="space-y-2">
                    <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">App ID</label>
                    <input 
                      type="text" 
                      value={globalSettings.feishuAppId}
                      onChange={(e) => saveGlobalSettings({ ...globalSettings, feishuAppId: e.target.value })}
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-xl p-3 text-sm text-white focus:outline-none focus:border-yellow-500/50 transition-all"
                      placeholder="cli_..."
                    />
                  </div>

                  <div className="space-y-2">
                    <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">App Secret</label>
                    <input 
                      type="password" 
                      value={globalSettings.feishuAppSecret}
                      onChange={(e) => saveGlobalSettings({ ...globalSettings, feishuAppSecret: e.target.value })}
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-xl p-3 text-sm text-white focus:outline-none focus:border-yellow-500/50 transition-all"
                      placeholder="******"
                    />
                  </div>

                  <div className="space-y-2">
                    <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">Base URL</label>
                    <input 
                      type="text" 
                      value={globalSettings.feishuBaseUrl}
                      onChange={(e) => saveGlobalSettings({ ...globalSettings, feishuBaseUrl: e.target.value })}
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-xl p-3 text-sm text-white focus:outline-none focus:border-yellow-500/50 transition-all"
                      placeholder="https://open.feishu.cn"
                    />
                  </div>

                  <div className="space-y-2">
                    <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">引擎类型</label>
                    <select 
                      value={globalSettings.feishuEngineType}
                      onChange={(e) => saveGlobalSettings({ ...globalSettings, feishuEngineType: e.target.value })}
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-xl p-3 text-sm text-white focus:outline-none focus:border-yellow-500/50 transition-all"
                    >
                      <option value="16k_auto">16k_auto</option>
                      <option value="16k_zh">16k_zh</option>
                      <option value="16k_en">16k_en</option>
                    </select>
                  </div>

                  <div className="space-y-2 pt-2 border-t border-neutral-800">
                    <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">诊断工具</label>
                    <div className="grid grid-cols-2 gap-2">
                      <button 
                        onClick={async () => {
                          const client = new FeishuASRClient({
                            appId: globalSettings.feishuAppId,
                            appSecret: globalSettings.feishuAppSecret,
                            baseUrl: globalSettings.feishuBaseUrl.includes('open.feishu.cn') ? '/feishu-api' : globalSettings.feishuBaseUrl,
                            engineType: globalSettings.feishuEngineType
                          });
                          const result = await client.testConnection();
                          setToast({ 
                            message: result.message + (result.success ? '' : ' (Note: If this is a CORS error, you may need a proxy server)'), 
                            type: result.success ? 'success' : 'error' 
                          });
                          setTimeout(() => setToast(null), 5000);
                        }}
                        className="py-2 bg-neutral-800 hover:bg-neutral-700 text-neutral-300 rounded-xl text-[10px] font-bold transition-all border border-neutral-700"
                      >
                        测试 API
                      </button>
                      <button 
                        onClick={async () => {
                          try {
                            if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
                              throw new Error('浏览器不支持麦克风访问');
                            }
                            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
                            stream.getTracks().forEach(t => t.stop());
                            setToast({ message: '麦克风正常，已获得权限', type: 'success' });
                          } catch (e: any) {
                            console.error('Mic test error:', e);
                            setToast({ message: `麦克风测试失败: ${e.message}`, type: 'error' });
                          }
                          setTimeout(() => setToast(null), 5000);
                        }}
                        className="py-2 bg-neutral-800 hover:bg-neutral-700 text-neutral-300 rounded-xl text-[10px] font-bold transition-all border border-neutral-700"
                      >
                        测试麦克风
                      </button>
                    </div>
                  </div>
                </div>

                <div className="p-4 bg-yellow-500/5 border border-yellow-500/10 rounded-xl">
                  <div className="flex items-center gap-2 text-yellow-500 text-[10px] font-bold uppercase tracking-wider mb-2">
                    <AlertCircle size={12} /> 提示
                  </div>
                  <p className="text-[10px] text-neutral-500 leading-relaxed">
                    配置飞书 App ID 和 Secret 后即可开启云 ASR 语音同步功能。
                  </p>
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Delete Confirmation Modal */}
      <AnimatePresence>
        {toast && (
          <motion.div 
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 50 }}
            className={`fixed bottom-10 left-1/2 -translate-x-1/2 z-[100] px-6 py-3 rounded-xl shadow-2xl flex items-center gap-3 border ${
              toast.type === 'success' ? 'bg-green-600 border-green-500' : 'bg-red-600 border-red-500'
            } text-white`}
          >
            {toast.type === 'success' ? <CheckCircle2 size={20} /> : <AlertTriangle size={20} />}
            <span className="text-sm font-medium">{toast.message}</span>
            <button onClick={() => setToast(null)} className="ml-4 p-1 hover:bg-white/20 rounded-full"><XCircle size={16} /></button>
          </motion.div>
        )}

        {deleteConfirmId && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setDeleteConfirmId(null)}
              className="absolute inset-0 bg-black/80 backdrop-blur-sm"
            />
            <motion.div 
              initial={{ opacity: 0, scale: 0.9, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.9, y: 20 }}
              className="relative w-full max-w-sm bg-neutral-900 border border-neutral-800 rounded-3xl p-8 shadow-2xl"
            >
              <div className="w-16 h-16 bg-red-500/10 rounded-2xl flex items-center justify-center text-red-500 mb-6">
                <Trash2 size={32} />
              </div>
              <h3 className="text-xl font-bold text-white mb-2">确认删除稿件？</h3>
              <p className="text-neutral-400 text-sm mb-8 leading-relaxed">
                此操作将永久删除该稿件，且无法撤销。请确认是否继续。
              </p>
              <div className="flex gap-3">
                <button 
                  onClick={() => setDeleteConfirmId(null)}
                  className="flex-1 px-6 py-3 rounded-xl bg-neutral-800 text-white text-sm font-bold hover:bg-neutral-700 transition-colors"
                >
                  取消
                </button>
                <button 
                  onClick={confirmDelete}
                  className="flex-1 px-6 py-3 rounded-xl bg-red-500 text-white text-sm font-bold hover:bg-red-400 transition-colors shadow-[0_0_20px_rgba(239,68,68,0.2)]"
                >
                  确认删除
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
      {/* Footer Info */}
      <footer className="fixed bottom-0 left-0 right-0 z-40 border-t border-neutral-900 bg-black/80 backdrop-blur-xl">
        <div className="max-w-6xl mx-auto px-6 h-16 flex justify-between items-center text-neutral-600 text-[10px] uppercase tracking-[0.2em] font-mono">
          <div>© 2026 Thin UI Teleprompter Engine</div>
          <div className="flex gap-6">
            <a href="#" className="hover:text-white transition-colors">Documentation</a>
            <a href="#" className="hover:text-white transition-colors">Feishu ASR API</a>
          </div>
        </div>
      </footer>
    </div>
  );
}

