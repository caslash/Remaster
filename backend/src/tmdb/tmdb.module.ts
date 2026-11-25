import { TmdbService } from '@/tmdb/tmdb.service';
import { Module } from '@nestjs/common';

@Module({
  providers: [TmdbService],
  exports: [TmdbService],
})
export class TmdbModule {}
