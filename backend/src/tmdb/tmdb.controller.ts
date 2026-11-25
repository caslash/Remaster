import { TmdbService } from '@/tmdb/tmdb.service';
import { TitleResponse } from '@/upc/types/title';
import { Controller, Get, Param } from '@nestjs/common';

@Controller('tmdb')
export class TmdbController {
  public constructor(private tmdbService: TmdbService) {}

  @Get('search/:searchText')
  async searchTitle(
    @Param('searchText') searchText: string,
  ): Promise<TitleResponse[]> {
    return await this.tmdbService.searchTitle(searchText);
  }
}
