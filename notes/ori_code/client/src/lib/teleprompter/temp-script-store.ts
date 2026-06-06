import { nanoid } from 'nanoid';

import type { Script } from '@/components/teleprompter/types';
import { TEMP_SCRIPT_ID_PREFIX } from '@/components/teleprompter/types';

type TempScriptListener = (scripts: Script[]) => void;

let tempScripts: Script[] = [];
const listeners = new Set<TempScriptListener>();

function emitTempScripts(): void {
  const snapshot = [...tempScripts];
  listeners.forEach((listener) => listener(snapshot));
}

export function listTempScripts(): Script[] {
  return [...tempScripts];
}

export function subscribeTempScripts(listener: TempScriptListener): () => void {
  listeners.add(listener);
  listener(listTempScripts());

  return () => {
    listeners.delete(listener);
  };
}

export function createTempScript(): Script {
  const script: Script = {
    id: `${TEMP_SCRIPT_ID_PREFIX}${nanoid(10)}`,
    title: '',
    content: '',
    lastModified: Date.now(),
    isTemporary: true,
  };

  tempScripts = [script, ...tempScripts];
  emitTempScripts();

  return script;
}

export function getTempScript(scriptId: string): Script | undefined {
  return tempScripts.find((script) => script.id === scriptId);
}

export function isTemporaryScriptId(scriptId: string): boolean {
  return scriptId.startsWith(TEMP_SCRIPT_ID_PREFIX);
}

export function updateTempScript(
  scriptId: string,
  updates: Partial<Script>,
): Script | null {
  let nextScript: Script | null = null;

  tempScripts = tempScripts.map((script) => {
    if (script.id !== scriptId) {
      return script;
    }

    nextScript = {
      ...script,
      ...updates,
      id: script.id,
      isTemporary: true,
      lastModified: updates.lastModified ?? Date.now(),
    };

    return nextScript;
  });

  if (!nextScript) {
    return null;
  }

  emitTempScripts();
  return nextScript;
}

export function removeTempScript(scriptId: string): boolean {
  const hasScript = tempScripts.some((script) => script.id === scriptId);
  if (!hasScript) {
    return false;
  }

  tempScripts = tempScripts.filter((script) => script.id !== scriptId);
  emitTempScripts();
  return true;
}
