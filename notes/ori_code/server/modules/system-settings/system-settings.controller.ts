import { Body, Controller, Get, Put } from '@nestjs/common';
import { NeedLogin } from '@lark-apaas/fullstack-nestjs-core';

import type {
  GetGlobalSettingsResponse,
  GlobalSettingsDto,
  UpdateGlobalSettingsRequest,
} from '@shared/api.interface';
import { SystemSettingsService } from './system-settings.service';

@Controller('api/system-settings')
export class SystemSettingsController {
  constructor(
    private readonly systemSettingsService: SystemSettingsService,
  ) {}

  @Get('global')
  async getGlobalSettings(): Promise<GetGlobalSettingsResponse> {
    const settings = await this.systemSettingsService.getGlobalSettings();
    return { settings };
  }

  @NeedLogin()
  @Put('global')
  async updateGlobalSettings(
    @Body() payload: UpdateGlobalSettingsRequest,
  ): Promise<GlobalSettingsDto> {
    return this.systemSettingsService.updateGlobalSettings(payload);
  }
}
