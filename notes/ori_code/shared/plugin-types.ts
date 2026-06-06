// ---- plugin:manuscript_text_optimization_1 ----
// ============================================================
// 插件 manuscript_text_optimization_1 (稿件正文文本优化) 的类型定义
// 由 get_plugin_ai_json 自动生成
// ============================================================

export interface ManuscriptTextOptimization1Input {
  /** 待优化的原始口语化/不规范文本 */
  original_text: string;
}

export interface ManuscriptTextOptimization1Output {
  /** 生成的增量文本内容 */
  content: string;
  /** (已弃用,请使用 content)生成的文本内容 */
  response?: string;
}
// ---- end:manuscript_text_optimization_1 ----

// ---- plugin:ai_text_rewrite_3 ----
// ============================================================
// 插件 ai_text_rewrite_3 (AI文本改写) 的类型定义
// 由 get_plugin_ai_json 自动生成
// ============================================================

export interface AiTextRewriteThreeInput {
  /** 改写指令，例如：扩写、缩写、调整为更口语的语气、总结成3个要点等 */
  rewrite_instruction: string;
  /** 需要改写的原文本 */
  original_text: string;
}

/**
 * capabilityClient.load('ai_text_rewrite_3').call<AiTextRewriteThreeOutput>('textGenerate', input)
 * 直接返回此类型，无 .data 包装，直接解构使用：
 * const { content, response } = result;
 */
export interface AiTextRewriteThreeOutput {
  /** 生成的增量文本内容 */
  content: string;
  /** (已弃用,请使用 content)生成的文本内容 */
  response?: string;
}
// ---- end:ai_text_rewrite_3 ----