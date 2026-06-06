export interface AlignmentResult {
  index: number;
  targetId: string;
  meta: {
    strategy: 'none' | 'anchor' | 'char_resync' | 'empty';
    matchedLength?: number;
    text: string;
    isFinal: boolean;
  };
}

export class TeleprompterAlignment {
  private script: string = '';
  private currentCleanIndex: number = -1;
  private matchStartCleanIndex: number = -1;
  private cleanToRawMap: number[] = [];
  private cleanScript: string = '';

  setScript(content: string) {
    this.script = content;
    this.currentCleanIndex = -1;
    this.matchStartCleanIndex = -1;
    this.cleanToRawMap = [];
    this.cleanScript = '';

    for (let i = 0; i < content.length; i++) {
      const char = content[i];
      if (/[a-zA-Z0-9\u4e00-\u9fa5]/.test(char)) {
        this.cleanScript += char;
        this.cleanToRawMap.push(i);
      }
    }
  }

  reset() {
    this.currentCleanIndex = -1;
    this.matchStartCleanIndex = -1;
  }

  setCurrentIndex(rawIndex: number) {
    if (rawIndex < 0) {
      this.currentCleanIndex = -1;
      this.matchStartCleanIndex = -1;
      return;
    }

    let cleanIdx = -1;
    for (let i = 0; i < this.cleanToRawMap.length; i++) {
      if (this.cleanToRawMap[i] >= rawIndex) {
        cleanIdx = i;
        break;
      }
    }

    if (cleanIdx === -1) {
      cleanIdx = this.cleanToRawMap.length - 1;
    }

    this.currentCleanIndex = cleanIdx;
    this.matchStartCleanIndex = cleanIdx;
  }

  private charLevelMatch(scriptSlice: string, spoken: string): number {
    let si = 0;
    let ri = 0;
    let lastGoodOrigIndex = 0;

    while (si < scriptSlice.length && ri < spoken.length) {
      const sc = scriptSlice[si];
      const rc = spoken[ri];

      if (sc === rc) {
        si++;
        ri++;
        lastGoodOrigIndex = si;
      } else {
        let found = false;

        const maxSkipR = Math.min(3, spoken.length - ri - 1);
        if (maxSkipR >= 1) {
          for (let skipR = 1; skipR <= maxSkipR; skipR++) {
            if (spoken[ri + skipR] === sc) {
              ri += skipR;
              found = true;
              break;
            }
          }
        }
        if (found) {
          continue;
        }

        const maxSkipS = Math.min(3, scriptSlice.length - si - 1);
        if (maxSkipS >= 1) {
          for (let skipS = 1; skipS <= maxSkipS; skipS++) {
            if (scriptSlice[si + skipS] === rc) {
              si += skipS;
              found = true;
              break;
            }
          }
        }
        if (found) {
          continue;
        }

        si++;
        ri++;
        lastGoodOrigIndex = si;
      }
    }
    return lastGoodOrigIndex;
  }

  consumeTranscript(text: string, isFinal: boolean): AlignmentResult {
    if (!this.script || !this.cleanScript) {
      return { index: -1, targetId: 'word_-1', meta: { strategy: 'none', text, isFinal } };
    }

    const cleanText = text.replace(/[^\u4e00-\u9fa5a-zA-Z0-9]/g, '');
    if (!cleanText) {
      if (isFinal) {
        this.matchStartCleanIndex = this.currentCleanIndex;
      }
      const rawIndex = this.currentCleanIndex >= 0 ? this.cleanToRawMap[this.currentCleanIndex] : -1;
      return {
        index: rawIndex,
        targetId: `word_${rawIndex}`,
        meta: { strategy: 'empty', text, isFinal }
      };
    }

    const searchStart = this.matchStartCleanIndex + 1;
    const remainingScript = this.cleanScript.substring(searchStart);
    const fuzzyMatchedChars = this.charLevelMatch(remainingScript, cleanText);

    let anchorMatchedChars = 0;
    let anchorSkipChars = 0;
    if (fuzzyMatchedChars === 0 || isFinal) {
      const anchorIndex = remainingScript.indexOf(cleanText);
      if (anchorIndex !== -1 && anchorIndex >= 0 && anchorIndex < 50) {
        anchorMatchedChars = cleanText.length;
        anchorSkipChars = anchorIndex;
      }
    }

    if (fuzzyMatchedChars > 0 || anchorMatchedChars > 0) {
      let newCleanIndex = this.currentCleanIndex;
      let strategy: 'char_resync' | 'anchor' = 'char_resync';
      let matchedLength = 0;

      if (anchorMatchedChars > 0 && (anchorSkipChars > 0 || fuzzyMatchedChars === 0)) {
        newCleanIndex = searchStart + anchorSkipChars + anchorMatchedChars - 1;
        strategy = 'anchor';
        matchedLength = anchorMatchedChars;
      } else {
        newCleanIndex = searchStart + fuzzyMatchedChars - 1;
        strategy = 'char_resync';
        matchedLength = fuzzyMatchedChars;
      }

      if (newCleanIndex > this.currentCleanIndex) {
        this.currentCleanIndex = Math.min(newCleanIndex, this.cleanScript.length - 1);
      }

      if (isFinal) {
        this.matchStartCleanIndex = this.currentCleanIndex;
      }

      const rawIndex = this.cleanToRawMap[this.currentCleanIndex];
      return {
        index: rawIndex,
        targetId: `word_${rawIndex}`,
        meta: {
          strategy,
          matchedLength,
          text,
          isFinal
        }
      };
    }

    if (isFinal) {
      this.matchStartCleanIndex = this.currentCleanIndex;
    }

    const rawIndex = this.currentCleanIndex >= 0 ? this.cleanToRawMap[this.currentCleanIndex] : -1;
    return {
      index: rawIndex,
      targetId: `word_${rawIndex}`,
      meta: { strategy: 'none', text, isFinal }
    };
  }
}
