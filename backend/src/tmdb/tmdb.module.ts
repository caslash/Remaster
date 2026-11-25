import { TmdbService } from '@/tmdb/tmdb.service';
import { Module } from '@nestjs/common';
import { TmdbController } from './tmdb.controller';

@Module({
  providers: [TmdbService],
  exports: [TmdbService],
  controllers: [TmdbController],
})
export class TmdbModule {}
