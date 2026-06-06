import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

interface ArticleDeleteDialogProps {
  open: boolean;
  pending: boolean;
  title: string;
  onOpenChange: (open: boolean) => void;
  onConfirm: () => Promise<void>;
}

export const ArticleDeleteDialog: React.FC<ArticleDeleteDialogProps> = ({
  open,
  pending,
  title,
  onOpenChange,
  onConfirm,
}) => {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm rounded-3xl border-neutral-800 bg-neutral-950 text-white">
        <DialogHeader>
          <DialogTitle className="text-xl">确认删除稿件？</DialogTitle>
          <DialogDescription className="text-neutral-400 leading-relaxed">
            稿件“{title}”删除后无法恢复，请确认是否继续。
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button
            variant="secondary"
            onClick={() => onOpenChange(false)}
            disabled={pending}
          >
            取消
          </Button>
          <Button variant="destructive" onClick={onConfirm} disabled={pending}>
            {pending ? '删除中...' : '确认删除'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
