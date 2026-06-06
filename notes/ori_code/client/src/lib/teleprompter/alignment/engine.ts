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

interface MatchResult {
  matchedLength: number;
  scriptAdvance: number;
  transcriptAdvance: number;
}

interface WindowedMatchResult {
  match: MatchResult;
  offset: number;
}

const CLEAN_CHAR_REGEX = /[a-zA-Z0-9\u4e00-\u9fa5]/u;
const RESYNC_LOOKAHEAD_WINDOW = 24;

export class TeleprompterAlignment {
  private script: string = '';
  private cleanScript: string = '';
  private indexMap: number[] = [];
  private anchorIndex: number = -1;
  private currentIndex: number = -1;

  setScript(content: string) {
    this.script = content;
    this.cleanScript = '';
    this.indexMap = [];
    this.anchorIndex = -1;
    this.currentIndex = -1;

    for (let i = 0; i < content.length; i += 1) {
      const char = content[i];
      if (CLEAN_CHAR_REGEX.test(char)) {
        this.cleanScript += char;
        this.indexMap.push(i);
      }
    }
  }

  reset() {
    this.anchorIndex = -1;
    this.currentIndex = -1;
  }

  setCurrentIndex(rawIndex: number) {
    if (rawIndex < 0) {
      this.anchorIndex = -1;
      this.currentIndex = -1;
      return;
    }

    let cleanIndex = -1;
    for (let i = 0; i < this.indexMap.length; i += 1) {
      if (this.indexMap[i] >= rawIndex) {
        cleanIndex = i;
        break;
      }
    }

    if (cleanIndex === -1) {
      cleanIndex = this.indexMap.length - 1;
    }

    this.anchorIndex = cleanIndex;
    this.currentIndex = cleanIndex;
  }

  private toRawIndex(cleanIndex: number): number {
    if (cleanIndex < 0 || cleanIndex >= this.indexMap.length) {
      return -1;
    }

    return this.indexMap[cleanIndex];
  }

  private normalizeTranscript(text: string): string {
    return text
      .split('')
      .filter((char) => CLEAN_CHAR_REGEX.test(char))
      .join('');
  }

  private charLevelMatch(scriptStart: number, transcript: string): MatchResult {
    let scriptIndex = scriptStart;
    let transcriptIndex = 0;
    let lastMatchedScriptIndex = scriptStart - 1;
    let matchedLength = 0;

    while (
      scriptIndex < this.cleanScript.length &&
      transcriptIndex < transcript.length
    ) {
      const scriptChar = this.cleanScript[scriptIndex];
      const transcriptChar = transcript[transcriptIndex];

      if (scriptChar === transcriptChar) {
        lastMatchedScriptIndex = scriptIndex;
        matchedLength += 1;
        scriptIndex += 1;
        transcriptIndex += 1;
        continue;
      }

      let aligned = false;

      for (let skipScript = 1; skipScript <= 3; skipScript += 1) {
        if (scriptIndex + skipScript >= this.cleanScript.length) {
          break;
        }
        if (this.cleanScript[scriptIndex + skipScript] === transcriptChar) {
          scriptIndex += skipScript;
          aligned = true;
          break;
        }
      }
      if (aligned) {
        continue;
      }

      for (let skipTranscript = 1; skipTranscript <= 3; skipTranscript += 1) {
        if (transcriptIndex + skipTranscript >= transcript.length) {
          break;
        }
        if (scriptChar === transcript[transcriptIndex + skipTranscript]) {
          transcriptIndex += skipTranscript;
          aligned = true;
          break;
        }
      }
      if (aligned) {
        continue;
      }

      scriptIndex += 1;
      transcriptIndex += 1;
    }

    return {
      matchedLength,
      scriptAdvance: Math.max(0, lastMatchedScriptIndex - scriptStart + 1),
      transcriptAdvance: transcriptIndex,
    };
  }

  private findBestMatch(
    scriptStart: number,
    transcript: string,
  ): WindowedMatchResult {
    let bestMatch = this.charLevelMatch(scriptStart, transcript);
    let bestOffset = 0;

    if (bestMatch.matchedLength > 0) {
      return { match: bestMatch, offset: bestOffset };
    }

    const maxOffset = Math.min(
      RESYNC_LOOKAHEAD_WINDOW,
      Math.max(0, this.cleanScript.length - scriptStart - 1),
    );

    for (let offset = 1; offset <= maxOffset; offset += 1) {
      const candidateMatch = this.charLevelMatch(scriptStart + offset, transcript);
      if (candidateMatch.matchedLength > bestMatch.matchedLength) {
        bestMatch = candidateMatch;
        bestOffset = offset;
      }

      if (bestMatch.matchedLength >= Math.min(6, transcript.length)) {
        break;
      }
    }

    return { match: bestMatch, offset: bestOffset };
  }

  consumeTranscript(text: string, isFinal: boolean): AlignmentResult {
    if (!this.script || !this.cleanScript) {
      return {
        index: -1,
        targetId: 'word_-1',
        meta: { strategy: 'none', text, isFinal },
      };
    }

    const cleanText = this.normalizeTranscript(text);
    if (!cleanText) {
      const rawIndex = this.toRawIndex(this.currentIndex);
      if (isFinal) {
        this.anchorIndex = this.currentIndex;
      }
      return {
        index: rawIndex,
        targetId: `word_${rawIndex}`,
        meta: { strategy: 'empty', text, isFinal },
      };
    }

    const anchorStart = Math.max(0, this.anchorIndex + 1);
    const { match: anchorMatch, offset: anchorOffset } = this.findBestMatch(
      anchorStart,
      cleanText,
    );

    if (anchorMatch.matchedLength === 0) {
      const rawIndex = this.toRawIndex(this.currentIndex);
      if (isFinal) {
        this.anchorIndex = this.currentIndex;
      }
      return {
        index: rawIndex,
        targetId: `word_${rawIndex}`,
        meta: { strategy: 'none', text, isFinal },
      };
    }

    const resolvedAnchorStart = anchorStart + anchorOffset;
    const nextCurrentIndex = Math.min(
      resolvedAnchorStart + anchorMatch.scriptAdvance - 1,
      this.cleanScript.length - 1,
    );

    this.currentIndex = Math.max(this.currentIndex, nextCurrentIndex);
    if (isFinal) {
      this.anchorIndex = this.currentIndex;
    }

    const rawIndex = this.toRawIndex(this.currentIndex);
    const strategy =
      anchorStart === 0 && anchorOffset === 0 ? 'anchor' : 'char_resync';

    return {
      index: rawIndex,
      targetId: `word_${rawIndex}`,
      meta: {
        strategy,
        matchedLength: anchorMatch.matchedLength,
        text,
        isFinal,
      },
    };
  }
}
