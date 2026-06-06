import { BadGatewayException, Injectable, Logger } from '@nestjs/common';

import type {
  FeishuProxySpeechRequest,
  FeishuProxySpeechResponse,
  FeishuProxyTokenRequest,
  FeishuProxyTokenResponse,
} from '@shared/api.interface';

interface CachedToken {
  expire: number;
  tenantAccessToken: string;
  expiresAt: number;
}

interface FeishuTokenApiResponse {
  code: number;
  msg: string;
  tenant_access_token?: string;
  expire?: number;
}

interface FeishuSpeechApiResponse {
  code: number;
  msg: string;
  data?: {
    recognition_text?: string;
  };
}

const TOKEN_REFRESH_BUFFER_MS = 300000;
const FEISHU_FETCH_TIMEOUT_MS = 15000;

@Injectable()
export class FeishuProxyService {
  private readonly logger = new Logger(FeishuProxyService.name);

  private createTimeoutSignal(): AbortSignal {
    return AbortSignal.timeout(FEISHU_FETCH_TIMEOUT_MS);
  }
  private readonly tokenCache = new Map<string, CachedToken>();
  private readonly pendingTokenRequests = new Map<
    string,
    Promise<FeishuProxyTokenResponse>
  >();

  private normalizeBaseUrl(baseUrl: string): string {
    const trimmed = baseUrl.trim();

    if (!trimmed) {
      return 'https://open.feishu.cn';
    }

    if (trimmed === '/feishu-api') {
      return 'https://open.feishu.cn';
    }

    if (trimmed === '/lark-api') {
      return 'https://open.larkoffice.com';
    }

    if (trimmed.endsWith('/open-apis')) {
      return trimmed.slice(0, -10);
    }

    return trimmed;
  }

  private getTokenCacheKey(params: FeishuProxyTokenRequest): string {
    return [params.appId, this.normalizeBaseUrl(params.baseUrl)].join('::');
  }

  private getCachedToken(
    params: FeishuProxyTokenRequest,
  ): FeishuProxyTokenResponse | null {
    const cacheKey = this.getTokenCacheKey(params);
    const cached = this.tokenCache.get(cacheKey);

    if (!cached) {
      return null;
    }

    if (Date.now() >= cached.expiresAt - TOKEN_REFRESH_BUFFER_MS) {
      this.tokenCache.delete(cacheKey);
      return null;
    }

    return {
      tenantAccessToken: cached.tenantAccessToken,
      expire: cached.expire,
    };
  }

  async getTenantAccessToken(
    params: FeishuProxyTokenRequest,
  ): Promise<FeishuProxyTokenResponse> {
    const cacheKey = this.getTokenCacheKey(params);

    if (!params.forceRefresh) {
      const cached = this.getCachedToken(params);
      if (cached) {
        this.logger.log(`Reuse cached token for appId=${params.appId}`);
        return cached;
      }

      const pendingRequest = this.pendingTokenRequests.get(cacheKey);
      if (pendingRequest) {
        this.logger.log(`Reuse pending token request for appId=${params.appId}`);
        return pendingRequest;
      }
    } else {
      this.logger.log(`Force refresh token for appId=${params.appId}`);
      this.tokenCache.delete(cacheKey);
      this.pendingTokenRequests.delete(cacheKey);
    }

    const request = this.fetchTenantAccessToken(params)
      .then((result) => {
        this.tokenCache.set(cacheKey, {
          tenantAccessToken: result.tenantAccessToken,
          expire: result.expire,
          expiresAt: Date.now() + result.expire * 1000,
        });
        this.logger.log(`Cached token for appId=${params.appId}`);
        return result;
      })
      .finally(() => {
        this.pendingTokenRequests.delete(cacheKey);
      });

    this.pendingTokenRequests.set(cacheKey, request);
    return request;
  }

  private async fetchTenantAccessToken(
    params: FeishuProxyTokenRequest,
  ): Promise<FeishuProxyTokenResponse> {
    const baseUrl = this.normalizeBaseUrl(params.baseUrl);

    try {
      const response = await fetch(
        `${baseUrl}/open-apis/auth/v3/tenant_access_token/internal`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=utf-8' },
          body: JSON.stringify({
            app_id: params.appId,
            app_secret: params.appSecret,
          }),
          signal: this.createTimeoutSignal(),
        },
      );

      if (!response.ok) {
        const errorText = await response.text();
        this.logger.error(
          `Feishu token upstream failed appId=${params.appId} baseUrl=${baseUrl} status=${response.status} body=${errorText}`,
        );
        throw new BadGatewayException({
          errorMessage: `飞书 access token 获取失败：HTTP ${response.status}`,
          upstreamStatus: response.status,
        });
      }

      const data = (await response.json()) as FeishuTokenApiResponse;

      if (data.code !== 0 || !data.tenant_access_token || !data.expire) {
        this.logger.error(
          `Feishu token upstream business failed appId=${params.appId} baseUrl=${baseUrl} code=${data.code} msg=${data.msg}`,
        );
        throw new BadGatewayException({
          errorMessage: `飞书 access token 获取失败：${data.msg}`,
        });
      }

      return {
        tenantAccessToken: data.tenant_access_token,
        expire: data.expire,
      };
    } catch (error) {
      if (error instanceof BadGatewayException) {
        throw error;
      }

      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(
        `Feishu token request exception appId=${params.appId} baseUrl=${baseUrl} message=${message}`,
      );
      throw new BadGatewayException({
        errorMessage: '飞书 access token 获取失败：网络异常或请求超时',
      });
    }
  }

  private async requestSpeechRecognition(
    params: FeishuProxySpeechRequest,
  ): Promise<FeishuSpeechApiResponse> {
    const baseUrl = this.normalizeBaseUrl(params.baseUrl);
    const token = await this.getTenantAccessToken({
      appId: params.appId,
      appSecret: params.appSecret,
      baseUrl: params.baseUrl,
    });
    const response = await fetch(
      `${baseUrl}/open-apis/speech_to_text/v1/speech/stream_recognize`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token.tenantAccessToken}`,
          'Content-Type': 'application/json; charset=utf-8',
          Connection: 'keep-alive',
        },
        body: JSON.stringify({
          speech: { speech: params.speech },
          config: {
            stream_id: params.streamId,
            sequence_id: params.sequenceId,
            action: params.action,
            format: params.format,
            engine_type: params.engineType,
          },
        }),
        signal: this.createTimeoutSignal(),
      },
    );

    if (!response.ok) {
      const errorText = await response.text();
      if (response.status === 504) {
        throw new Error(`飞书语音识别超时，请重试。HTTP 504 ${errorText}`);
      }
      throw new Error(
        `Failed to recognize Feishu speech: HTTP ${response.status} ${errorText}`,
      );
    }

    return (await response.json()) as FeishuSpeechApiResponse;
  }

  async recognizeSpeech(
    params: FeishuProxySpeechRequest,
  ): Promise<FeishuProxySpeechResponse> {
    try {
      const data = await this.requestSpeechRecognition(params);

      return {
        code: data.code,
        msg: data.msg,
        data: data.data
          ? { recognitionText: data.data.recognition_text }
          : undefined,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(
        `Speech recognition failed streamId=${params.streamId} sequenceId=${params.sequenceId} action=${params.action} message=${message}`,
      );
      throw error;
    }
  }

}
