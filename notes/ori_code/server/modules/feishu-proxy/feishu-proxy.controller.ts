import { Body, Controller, Post } from '@nestjs/common';
import { NeedLogin } from '@lark-apaas/fullstack-nestjs-core';

import type {
  FeishuProxySpeechRequest,
  FeishuProxySpeechResponse,
  FeishuProxyTokenRequest,
  FeishuProxyTokenResponse,
} from '@shared/api.interface';
import { FeishuProxyService } from './feishu-proxy.service';

@Controller('api/feishu-proxy')
export class FeishuProxyController {
  constructor(private readonly feishuProxyService: FeishuProxyService) {}

  @NeedLogin()
  @Post('tenant-access-token')
  async getTenantAccessToken(
    @Body() body: FeishuProxyTokenRequest,
  ): Promise<FeishuProxyTokenResponse> {
    return this.feishuProxyService.getTenantAccessToken(body);
  }

  @NeedLogin()
  @Post('speech-recognize')
  async recognizeSpeech(
    @Body() body: FeishuProxySpeechRequest,
  ): Promise<FeishuProxySpeechResponse> {
    return this.feishuProxyService.recognizeSpeech(body);
  }
}
