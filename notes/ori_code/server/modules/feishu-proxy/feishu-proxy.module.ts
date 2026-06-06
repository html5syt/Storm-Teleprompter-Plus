import { Module } from '@nestjs/common';

import { FeishuProxyController } from './feishu-proxy.controller';
import { FeishuProxyService } from './feishu-proxy.service';

@Module({
  controllers: [FeishuProxyController],
  providers: [FeishuProxyService],
})
export class FeishuProxyModule {}
