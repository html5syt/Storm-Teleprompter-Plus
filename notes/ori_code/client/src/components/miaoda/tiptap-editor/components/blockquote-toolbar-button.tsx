'use client';

import { useTiptapEditor } from '@/components/miaoda/tiptap-editor/hooks/use-tiptap-editor';
import { Toggle } from '@/components/ui/toggle';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip';
import { Quote } from 'lucide-react';

export function BlockquoteToolbarButton() {
  const { editor } = useTiptapEditor();
  if (!editor) return null;

  return (
    <TooltipProvider>
      <Tooltip delayDuration={700}>
        <TooltipTrigger asChild>
          <Toggle
            size="sm"
            pressed={editor.isActive('blockquote')}
            onPressedChange={() =>
              editor.chain().focus().toggleBlockquote().run()
            }
            disabled={!editor.can().toggleBlockquote()}
            aria-label="引用"
            className="size-6 p-0"
          >
            <Quote className="size-4" />
          </Toggle>
        </TooltipTrigger>
        <TooltipContent>
          <p>引用(⌘+Shift+&gt;)</p>
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}
