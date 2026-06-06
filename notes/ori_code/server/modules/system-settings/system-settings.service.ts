import { Inject, Injectable } from '@nestjs/common';
import {
  DRIZZLE_DATABASE,
  type PostgresJsDatabase,
} from '@lark-apaas/fullstack-nestjs-core';
import { eq } from 'drizzle-orm';

import type {
  GlobalSettingsDto,
  UpdateGlobalSettingsRequest,
} from '@shared/api.interface';
import { systemSettingTable } from '@server/database/schema';

const GLOBAL_SETTINGS_KEY = 'global';
const USE_TEMPORARY_BROWSER_CREATE = 1;

@Injectable()
export class SystemSettingsService {
  constructor(
    @Inject(DRIZZLE_DATABASE)
    private readonly db: PostgresJsDatabase,
  ) {}

  async getGlobalSettings(): Promise<GlobalSettingsDto> {
    const existing = await this.db
      .select()
      .from(systemSettingTable)
      .where(eq(systemSettingTable.settingsKey, GLOBAL_SETTINGS_KEY))
      .limit(1);

    if (existing.length === 0) {
      const [created] = await this.db
        .insert(systemSettingTable)
        .values({ settingsKey: GLOBAL_SETTINGS_KEY })
        .returning();

      return this.toGlobalSettings(created);
    }

    return this.toGlobalSettings(existing[0]);
  }

  async updateGlobalSettings(
    payload: UpdateGlobalSettingsRequest,
  ): Promise<GlobalSettingsDto> {
    const existing = await this.db
      .select()
      .from(systemSettingTable)
      .where(eq(systemSettingTable.settingsKey, GLOBAL_SETTINGS_KEY))
      .limit(1);

    if (existing.length === 0) {
      const [created] = await this.db
        .insert(systemSettingTable)
        .values({
          settingsKey: GLOBAL_SETTINGS_KEY,
          feishuAppId: payload.feishuAppId,
          feishuAppSecret: payload.feishuAppSecret,
          feishuBaseUrl: payload.feishuBaseUrl,
          feishuEngineType: payload.feishuEngineType,
        })
        .returning();

      return this.toGlobalSettings(created);
    }

    const [updated] = await this.db
      .update(systemSettingTable)
      .set({
        feishuAppId: payload.feishuAppId,
        feishuAppSecret: payload.feishuAppSecret,
        feishuBaseUrl: payload.feishuBaseUrl,
        feishuEngineType: payload.feishuEngineType,
      })
      .where(eq(systemSettingTable.settingsKey, GLOBAL_SETTINGS_KEY))
      .returning();

    return this.toGlobalSettings(updated);
  }

  private toGlobalSettings(
    record: typeof systemSettingTable.$inferSelect,
  ): GlobalSettingsDto {
    return {
      feishuAppId: record.feishuAppId,
      feishuAppSecret: record.feishuAppSecret,
      feishuBaseUrl: record.feishuBaseUrl,
      feishuEngineType:
        record.feishuEngineType as GlobalSettingsDto['feishuEngineType'],
      useTemporaryBrowserCreate: USE_TEMPORARY_BROWSER_CREATE === 1,
    };
  }
}
