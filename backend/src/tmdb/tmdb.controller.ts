import { SearchQueryDto } from '@/tmdb/dto/search-query.dto';
import { TmdbService } from '@/tmdb/tmdb.service';
import { TitleResponse } from '@/upc/types/title';
import { Controller, Get, Query, ValidationPipe } from '@nestjs/common';

@Controller()
export class TmdbController {
  public constructor(private tmdbService: TmdbService) {}

  @Get('search')
  async searchTitle(
    @Query(new ValidationPipe({ transform: true })) query: SearchQueryDto,
  ): Promise<TitleResponse[]> {
    return await this.tmdbService.searchTitle(query.q);
  }
}
