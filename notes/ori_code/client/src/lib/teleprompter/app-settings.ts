import {
  APP_SETTINGS_KEY,
  DEFAULT_APP_SETTINGS,
  type AppSettings,
} from '@/components/teleprompter/types';

function normalizeAppSettings(
  value: Partial<AppSettings> | null | undefined,
): AppSettings {
  return {
    ...DEFAULT_APP_SETTINGS,
    ...value,
  };
}

export function loadAppSettings(): AppSettings {
  if (typeof window === 'undefined') {
    return DEFAULT_APP_SETTINGS;
  }

  const rawValue = window.localStorage.getItem(APP_SETTINGS_KEY);
  if (!rawValue) {
    return DEFAULT_APP_SETTINGS;
  }

  try {
    return normalizeAppSettings(JSON.parse(rawValue) as Partial<AppSettings>);
  } catch {
    return DEFAULT_APP_SETTINGS;
  }
}

export function saveAppSettings(settings: AppSettings): AppSettings {
  const nextSettings = normalizeAppSettings(settings);

  if (typeof window !== 'undefined') {
    window.localStorage.setItem(APP_SETTINGS_KEY, JSON.stringify(nextSettings));
  }

  return nextSettings;
}
