'use client';

import { useTiptapEditor } from '@/components/miaoda/tiptap-editor/hooks/use-tiptap-editor';
import { Toggle } from '@/components/ui/toggle';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { CodeXml } from 'lucide-react';

export function CodeBlockToolbarButton() {
  const { editor } = useTiptapEditor();
  if (!editor) return null;

  return (
    <TooltipProvider>
      <Tooltip delayDuration={700}>
        <TooltipTrigger asChild>
          <Toggle
            size="sm"
            pressed={editor.isActive('codeBlock')}
            onPressedChange={() =>
              editor.chain().focus().toggleCodeBlock().run()
            }
            disabled={!editor.can().toggleCodeBlock()}
            aria-label="代码块"
            className="size-6 p-0"
          >
            <CodeXml className="size-4" />
          </Toggle>
        </TooltipTrigger>
        <TooltipContent>
          <p>代码块</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}
