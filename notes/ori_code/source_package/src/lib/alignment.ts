import { TeleprompterAlignment } from './alignment/engine'

const engine = new TeleprompterAlignment()

export const alignmentEngine = {
  setScript(content: string) {
    engine.setScript(content)
  },
  setCurrentIndex(index: number) {
    engine.setCurrentIndex(index)
  },
  consumeTranscript(text: string, isFinal: boolean) {
    return engine.consumeTranscript(text, isFinal)
  },
  reset() {
    engine.reset()
  },
}
