import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { AlertCircle, Minimize2, Settings } from 'lucide-react';
import { logger } from '@lark-apaas/client-toolkit/logger';

import { Button } from '@/components/ui/button';
import type { ToastState } from './types';

interface GlobalSettingsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  setToast: (toast: ToastState | null) => void;
}

export const GlobalSettingsDialog: React.FC<GlobalSettingsDialogProps> = ({
  open,
  onOpenChange,
  setToast,
}) => {
  const handleTestMic = async () => {
    try {
      if (window.isSecureContext === false) {
        throw new Error('测试麦克风需要在 HTTPS 或 localhost 环境下运行');
      }
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('浏览器不支持麦克风访问');
      }
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      stream.getTracks().forEach((t) => t.stop());
      setToast({ message: '麦克风正常，已获得权限', type: 'success' });
    } catch (error) {
      logger.error('Mic test error:', error);
      const message =
        error instanceof Error ? error.message : '未知错误，请检查浏览器麦克风权限';
      setToast({ message: `麦克风测试失败: ${message}`, type: 'error' });
    }
    setTimeout(() => setToast(null), 5000);
  };

  const handleClose = () => {
    onOpenChange(false);
  };

  if (!open) return null;

  return (
    <>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        onClick={handleClose}
        className="fixed inset-0 z-[60] bg-black/60"
      />
      <motion.div
        initial={{ x: '100%' }}
        animate={{ x: 0 }}
        exit={{ x: '100%' }}
        transition={{ type: 'spring', damping: 25, stiffness: 200 }}
        className="fixed top-0 right-0 bottom-0 z-[70] flex w-full flex-col border-l border-white/5 bg-[#0a0a0a] shadow-2xl sm:w-96"
      >
        <div className="flex items-center justify-between border-b border-white/5 px-6 py-4">
          <h2 className="flex items-center gap-2 text-base font-semibold text-white">
            <Settings size={18} /> 系统设置
          </h2>
          <button
            type="button"
            title="关闭系统设置"
            aria-label="关闭系统设置"
            onClick={handleClose}
            className="text-neutral-500 transition-colors hover:text-white"
          >
            <Minimize2 size={18} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          <div className="space-y-4 rounded-2xl border border-[#2e2e2e] bg-[#141414] p-4">
            <h3 className="text-xs font-semibold text-neutral-400 uppercase tracking-wider">
              识别方式
            </h3>

            <div className="rounded-xl border border-yellow-500/15 bg-yellow-500/5 p-4">
              <div className="text-xs font-semibold text-yellow-300">
                当前固定为浏览器本地识别
              </div>
              <p className="mt-2 text-xs leading-relaxed text-neutral-400">
                飞书云端识别链路已停用，提词页面统一使用前端本地 wasm + onnx 模型，不再依赖飞书 App 配置。
              </p>
            </div>

            <div className="space-y-2 pt-2 border-t border-[#2e2e2e]">
              <label className="text-xs font-medium text-neutral-500">
                诊断工具
              </label>
              <div className="grid grid-cols-1 gap-2">
                <Button
                  variant="outline"
                  onClick={handleTestMic}
                  className="h-9 bg-[#1a1a1a] border-[#2e2e2e] text-neutral-300 rounded-xl text-xs font-medium hover:bg-[#252525] hover:text-white"
                >
                  测试麦克风
                </Button>
              </div>
            </div>
          </div>

          <div className="rounded-xl border border-yellow-500/15 bg-yellow-500/5 p-4">
            <div className="flex items-center gap-2 text-yellow-400 text-xs font-semibold mb-2">
              <AlertCircle size={14} /> 提示
            </div>
            <p className="text-xs text-neutral-500 leading-relaxed">
              顶部“右上角一键获取同款”会跳转到正式模板。创建方式已由后端控制，页面内不再暴露相关开关；若需长期使用，建议先创建同款再继续编辑。
            </p>
          </div>
        </div>
      </motion.div>
    </>
  );
};
