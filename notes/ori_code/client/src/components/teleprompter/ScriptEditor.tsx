import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';

import type { Script } from './types';

interface ScriptEditorProps {
  script: Script;
  onBack: () => void;
  onSave: (id: string, title: string, content: string) => void;
}

export const ScriptEditor: React.FC<ScriptEditorProps> = ({
  script,
  onBack,
  onSave,
}) => {
  const [title, setTitle] = useState(script.title);
  const [content, setContent] = useState(script.content);

  useEffect(() => {
    setTitle(script.title);
    setContent(script.content);
  }, [script.id, script.title, script.content]);

  const handleSave = () => {
    onSave(script.id, title, content);
    onBack();
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: 20 }}
      className="min-h-screen bg-black flex flex-col font-sans text-white"
    >
      <header className="h-20 border-b border-neutral-900 flex items-center justify-between px-6 bg-black/50 backdrop-blur-xl sticky top-0 z-50">
        <div className="flex items-center gap-4">
          <Button
            variant="ghost"
            size="icon"
            onClick={onBack}
            className="rounded-full text-neutral-400 hover:text-white hover:bg-neutral-800"
          >
            <ChevronLeft size={20} />
          </Button>
          <h1 className="text-lg font-bold">编辑稿件</h1>
        </div>
        <Button
          onClick={handleSave}
          className="rounded-full bg-yellow-500 text-black hover:bg-yellow-400"
        >
          保存修改
        </Button>
      </header>

      <main className="flex-1 max-w-4xl mx-auto w-full p-6 flex flex-col gap-6">
        <div className="space-y-2">
          <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">
            稿件标题
          </label>
          <Input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="bg-neutral-900 border-neutral-800 rounded-xl p-4 h-14 text-xl font-bold text-white"
            placeholder="输入稿件标题..."
          />
        </div>

        <div className="flex-1 flex flex-col gap-2 min-h-[400px]">
          <label className="text-[10px] uppercase tracking-widest text-neutral-500 font-mono font-bold">
            正文内容
          </label>
          <Textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            className="flex-1 min-h-[400px] bg-neutral-900 border-neutral-800 rounded-xl p-6 text-lg leading-relaxed text-neutral-300 resize-none"
            placeholder="在此输入您的提词稿件内容..."
          />
        </div>
      </main>
    </motion.div>
  );
};
