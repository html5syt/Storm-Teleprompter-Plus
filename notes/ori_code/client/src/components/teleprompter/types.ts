export interface Script {
  id: string;
  title: string;
  content: string;
  lastModified: number;
  coverImage?: string;
  isTemporary?: boolean;
}

export interface AppSettings {
  useTemporaryBrowserCreate: boolean;
}

export interface TeleprompterSettings {
  fontSize: number;
  lineHeight: number;
  mirrorMode: boolean;
  showSettings: boolean;
  useResponsivePreset?: boolean;
  scrollMode: 'manual' | 'auto' | 'cloud' | 'local';
  wpn: number;
  isScrolling: boolean;
  paddingX: number;
}

export interface ToastState {
  message: string;
  type: 'success' | 'error';
}

export const APP_SETTINGS_KEY = 'teleprompter_app_settings';
export const TEMP_SCRIPT_ID_PREFIX = 'temp-script-';
export const CREATE_TEMPLATE_URL =
  'https://miaoda.feishu.cn/home?templateID=1863321057085483&mode=preview?open_from=official_website';
export const GUIDE_URL =
  'https://bytedance.larkoffice.com/docx/BLJCdabRFoO0bhxx2OqcS0khnLh';

export const SPEED_PRESETS = [
  { id: 'slow', name: '慢速', description: '适合深情朗读', wpn: 80 },
  { id: 'normal', name: '标准', description: '普通语速', wpn: 160 },
  { id: 'fast', name: '快语', description: '适合新闻播报', wpn: 240 },
  {
    id: 'very-fast',
    name: '极速',
    description: '适合快节奏内容',
    wpn: 320,
  },
  {
    id: 'oo',
    name: '直播模式',
    description: '实时互动带节奏',
    wpn: 345,
  },
  {
    id: 'tim',
    name: '自媒体博主模式',
    description: '打造爆款引关注',
    wpn: 325,
  },
  {
    id: 'siwei',
    name: '演讲模式',
    description: '自信从容控全场',
    wpn: 310,
  },
  {
    id: 'huaigu',
    name: '答辩模式',
    description: '严谨专业应评审',
    wpn: 290,
  }
] as const;

export const DEFAULT_APP_SETTINGS: AppSettings = {
  useTemporaryBrowserCreate: true,
};
