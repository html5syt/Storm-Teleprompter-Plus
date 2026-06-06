export type FeishuCloudEngineType = '16k_auto' | '16k_zh' | '16k_en';
export type SpeechEngineType = FeishuCloudEngineType | 'local_browser';

export interface FeishuProxyTokenRequest {
  appId: string;
  appSecret: string;
  baseUrl: string;
  forceRefresh?: boolean;
}

export interface FeishuProxyTokenResponse {
  tenantAccessToken?: string;
  expire?: number;
  errorMessage?: string;
  upstreamStatus?: number;
}

export interface FeishuProxySpeechRequest {
  appId: string;
  appSecret: string;
  baseUrl: string;
  streamId: string;
  sequenceId: number;
  action: number;
  format: string;
  engineType: FeishuCloudEngineType;
  speech: string;
}

export interface FeishuProxySpeechResponse {
  code: number;
  msg: string;
  data?: {
    recognitionText?: string;
  };
}

export interface FeishuProxySpeechChunk {
  sequenceId: number;
  action: number;
  format: string;
  engineType: FeishuCloudEngineType;
  speech: string;
}

export interface FeishuProxyBatchSpeechRequest {
  appId: string;
  appSecret: string;
  baseUrl: string;
  streamId: string;
  chunks: FeishuProxySpeechChunk[];
}

export interface FeishuProxyBatchSpeechItemResponse {
  sequenceId: number;
  recognitionText?: string;
}

export interface FeishuProxyBatchSpeechResponse {
  code: number;
  msg: string;
  data?: FeishuProxyBatchSpeechItemResponse[];
}

export interface Article {
  id: string;
  title: string;
  content: string;
  coverImage: string;
  status: 'draft' | 'published';
  createdAt: string;
  updatedAt: string;
}

export interface UpdateArticleRequest {
  title?: string;
  content?: string;
  coverImage?: string;
  status?: 'draft' | 'published';
}

export interface DeleteArticleResponse {
  success: boolean;
}

export interface ListArticlesResponse {
  items: Article[];
}

export interface CreateArticleRequest {
  title: string;
  content: string;
  coverImage?: string;
  status?: 'draft' | 'published';
}

export interface CreateArticleResponse {
  article: Article;
}

export interface GlobalSettingsDto {
  feishuAppId: string;
  feishuAppSecret: string;
  feishuBaseUrl: string;
  feishuEngineType: SpeechEngineType;
  useTemporaryBrowserCreate: boolean;
}

export interface GetGlobalSettingsResponse {
  settings: GlobalSettingsDto;
}

export interface UpdateGlobalSettingsRequest {
  feishuAppId: string;
  feishuAppSecret: string;
  feishuBaseUrl: string;
  feishuEngineType: SpeechEngineType;
}
