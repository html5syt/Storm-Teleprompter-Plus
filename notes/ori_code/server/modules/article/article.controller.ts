import { Body, Controller, Delete, Get, Param, Patch, Post, Req } from '@nestjs/common';
import { NeedLogin } from '@lark-apaas/fullstack-nestjs-core';
import type { Request } from 'express';


import type {
  Article,
  CreateArticleRequest,
  CreateArticleResponse,
  DeleteArticleResponse,
  ListArticlesResponse,
  UpdateArticleRequest,
} from '@shared/api.interface';
import { ArticleService } from './article.service';

@Controller('api/articles')
export class ArticleController {
  constructor(private readonly articleService: ArticleService) {}

  @Get()
  async listArticles(): Promise<ListArticlesResponse> {
    const items = await this.articleService.listArticles();
    return { items };
  }

  @NeedLogin()
  @Post()
  async createArticle(
    @Req() req: Request,
    @Body() payload: CreateArticleRequest,
  ): Promise<CreateArticleResponse> {
    const article = await this.articleService.createArticle(
      req.userContext.userId,
      payload,
    );
    return { article };
  }

  @NeedLogin()
  @Patch(':id')
  async updateArticle(
    @Param('id') id: string,
    @Body() payload: UpdateArticleRequest,
  ): Promise<Article> {
    return this.articleService.updateArticle(id, payload);
  }

  @NeedLogin()
  @Delete(':id')
  async deleteArticle(
    @Param('id') id: string,
  ): Promise<DeleteArticleResponse> {
    return this.articleService.deleteArticle(id);
  }
}
