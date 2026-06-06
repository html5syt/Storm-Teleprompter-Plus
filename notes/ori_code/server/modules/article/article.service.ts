import { ForbiddenException, Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  DRIZZLE_DATABASE,
  type PostgresJsDatabase,
} from '@lark-apaas/fullstack-nestjs-core';
import { desc, eq } from 'drizzle-orm';

import type {
  Article,
  CreateArticleRequest,
  DeleteArticleResponse,
  UpdateArticleRequest,
} from '@shared/api.interface';
import { articleTable } from '@server/database/schema';

const ARTICLE_MANAGEMENT_ENABLED = 1;

@Injectable()
export class ArticleService {
  private readonly logger = new Logger(ArticleService.name);

  constructor(
    @Inject(DRIZZLE_DATABASE)
    private readonly db: PostgresJsDatabase,
  ) {}

  async listArticles(): Promise<Article[]> {
    const records = await this.db
      .select()
      .from(articleTable)
      .orderBy(desc(articleTable.updatedAt));

    return records.map((record) => this.toArticle(record));
  }

  async createArticle(
    userId: string,
    payload: CreateArticleRequest,
  ): Promise<Article> {
    if (!ARTICLE_MANAGEMENT_ENABLED) {
      throw new ForbiddenException('稿件管理功能已关闭');
    }
    const [created] = await this.db
      .insert(articleTable)
      .values({
        title: payload.title,
        content: payload.content,
        coverImage: payload.coverImage ?? '',
        status: payload.status ?? 'draft',
        userId,
      })
      .returning();

    return this.toArticle(created);
  }

  async updateArticle(
    id: string,
    payload: UpdateArticleRequest,
  ): Promise<Article> {
    if (!ARTICLE_MANAGEMENT_ENABLED) {
      throw new ForbiddenException('稿件管理功能已关闭');
    }
    const values: UpdateArticleRequest = {};

    if (payload.title !== undefined) {
      values.title = payload.title;
    }
    if (payload.content !== undefined) {
      values.content = payload.content;
    }
    if (payload.coverImage !== undefined) {
      values.coverImage = payload.coverImage;
    }
    if (payload.status !== undefined) {
      values.status = payload.status;
    }

    const updated = await this.db
      .update(articleTable)
      .set(values)
      .where(eq(articleTable.id, id))
      .returning();

    if (updated.length === 0) {
      this.logger.error(`更新稿件失败: ${id}`);
      throw new NotFoundException('稿件不存在');
    }

    return this.toArticle(updated[0]);
  }

  async deleteArticle(
    id: string,
  ): Promise<DeleteArticleResponse> {
    if (!ARTICLE_MANAGEMENT_ENABLED) {
      throw new ForbiddenException('稿件管理功能已关闭');
    }
    const deleted = await this.db
      .delete(articleTable)
      .where(eq(articleTable.id, id))
      .returning({ id: articleTable.id });

    if (deleted.length === 0) {
      throw new NotFoundException('稿件不存在');
    }

    return { success: true };
  }

  private toArticle(record: typeof articleTable.$inferSelect): Article {
    return {
      id: record.id,
      title: record.title,
      content: record.content,
      coverImage: record.coverImage,
      status: record.status as 'draft' | 'published',
      createdAt: record.createdAt.toISOString(),
      updatedAt: record.updatedAt.toISOString(),
    };
  }
}
