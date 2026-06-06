import { capabilityClient } from '@lark-apaas/client-toolkit';
import { logger } from '@lark-apaas/client-toolkit/logger';
import { axiosForBackend } from '@lark-apaas/client-toolkit/utils/getAxiosForBackend';

import type {
  Article,
  CreateArticleRequest,
  CreateArticleResponse,
  DeleteArticleResponse,
  FeishuProxyTokenRequest,
  FeishuProxyTokenResponse,
  GetGlobalSettingsResponse,
  GlobalSettingsDto,
  ListArticlesResponse,
  UpdateArticleRequest,
} from '@shared/api.interface';
import type {
  ManuscriptTextOptimization1Input,
  ManuscriptTextOptimization1Output,
} from '@shared/plugin-types';

// TODO(delete-after-acceptance): 保留遗留飞书 ASR API 标记，当前运行主链不再调用。
export async function getFeishuTenantAccessToken(
  payload: FeishuProxyTokenRequest,
): Promise<FeishuProxyTokenResponse> {
  try {
    const response = await axiosForBackend.post<FeishuProxyTokenResponse>(
      '/api/feishu-proxy/tenant-access-token',
      payload,
    );
    return response.data;
  } catch (error) {
    logger.error('遗留飞书 access token 接口调用失败', error);
    throw error;
  }
}

export async function getGlobalSettings(): Promise<GlobalSettingsDto> {
  try {
    const response = await axiosForBackend.get<GetGlobalSettingsResponse>(
      '/api/system-settings/global',
    );
    return response.data.settings;
  } catch (error) {
    logger.error('获取系统设置失败', error);
    throw error;
  }
}

export async function listArticles(): Promise<ListArticlesResponse> {
  try {
    const response = await axiosForBackend.get<ListArticlesResponse>(
      '/api/articles',
    );
    return response.data;
  } catch (error) {
    logger.error('获取稿件列表失败', error);
    throw error;
  }
}

export async function createArticle(
  payload: CreateArticleRequest,
): Promise<CreateArticleResponse> {
  try {
    const response = await axiosForBackend.post<CreateArticleResponse>(
      '/api/articles',
      payload,
    );
    if (!response.data || !response.data.article) {
      logger.error('创建稿件返回异常', response.data);
      throw new Error('创建稿件返回数据异常');
    }
    return response.data;
  } catch (error) {
    logger.error('创建稿件失败', error);
    throw error;
  }
}

export async function updateArticle(
  articleId: string,
  payload: UpdateArticleRequest,
): Promise<Article> {
  try {
    const response = await axiosForBackend.patch<Article>(
      `/api/articles/${articleId}`,
      payload,
    );
    return response.data;
  } catch (error) {
    logger.error('更新稿件失败', error);
    throw error;
  }
}

export async function deleteArticle(
  articleId: string,
): Promise<DeleteArticleResponse> {
  try {
    const response = await axiosForBackend.request<DeleteArticleResponse>({
      url: `/api/articles/${articleId}`,
      method: 'DELETE',
    });
    return response.data;
  } catch (error) {
    logger.error('删除稿件失败', error);
    throw error;
  }
}

export async function* optimizeTextWithAI(
  originalText: string,
): AsyncGenerator<string> {
  try {
    const plugin = capabilityClient.load('manuscript_text_optimization_1');
    const typedInput: ManuscriptTextOptimization1Input = {
      original_text: originalText,
    };
    const input: Record<string, unknown> = {
      original_text: typedInput.original_text,
    };
    const stream = await plugin.callStream('textGenerate', input);
    for await (const chunk of stream) {
      const data = chunk as ManuscriptTextOptimization1Output;
      if (data.content) {
        yield data.content;
      }
    }
  } catch (error) {
    logger.error('AI 文本优化失败', error);
    throw error;
  }
}
