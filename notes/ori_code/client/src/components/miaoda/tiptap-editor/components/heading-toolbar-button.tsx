'use client';

import { useTiptapEditor } from '@/components/miaoda/tiptap-editor/hooks/use-tiptap-editor';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Check,
  ChevronDown,
  Heading1,
  Heading2,
  Heading3,
  Heading4,
  Heading5,
  Heading6,
  Type,
} from 'lucide-react';

const HEADING_OPTIONS = [
  { level: 0, label: '正文', icon: Type },
] as const;

export function HeadingToolbarButton() {
  const { editor } = useTiptapEditor();

  if (!editor) return null;

  const handleSelect = (level: number) => {
    if (level === 0) {
      editor.chain().focus().setParagraph().run();
    } else {
      editor
        .chain()
        .focus()
        .toggleHeading({ level: level as 1 | 2 | 3 | 4 | 5 | 6 })
        .run();
    }
  };

  const isActive = (level: number) => {
    if (level === 0) return editor.isActive('paragraph');
    return editor.isActive('heading', { level });
  };

  const activeOption =
    HEADING_OPTIONS.find((option) => isActive(option.level)) ||
    HEADING_OPTIONS[0];
  const ActiveIcon = activeOption.icon;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="sm" className="h-6 gap-0.5 px-2">
          <ActiveIcon className="size-4" />
          <ChevronDown className="size-3.5 text-muted-foreground" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-50">
        {HEADING_OPTIONS.map((option) => {
          const Icon = option.icon;
          const active = isActive(option.level);
          const disabled =
            option.level === 0
              ? !editor.can().setParagraph()
              : !editor.can().toggleHeading({
                  level: option.level as 1 | 2 | 3 | 4 | 5 | 6,
                });

          return (
            <DropdownMenuItem
              key={option.level}
              onClick={() => handleSelect(option.level)}
              disabled={disabled}
              className={cn('justify-between', active && 'bg-accent')}
            >
              <span className="flex items-center gap-2">
                <Icon className="size-4" />
                {option.label}
              </span>
              {active && <Check className="size-4" />}
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
