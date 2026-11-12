import { NormalizationService } from '@/upc/normalization/normalization.service';
import { RebuildService } from '@/upc/normalization/rebuild.service';
import { EditionStore } from '@/upc/storage/upc.storage.store';
import { TypeORMEditionStore } from '@/upc/storage/upc.storage.typeorm-store';
import { TMDBService } from '@/upc/tmdb.service';
import { Edition } from '@/upc/types/edition';
import { Title } from '@/upc/types/title';
import { UnresolvedUPC } from '@/upc/types/unresolved-upc';
import { UpcController } from '@/upc/upc.controller';
import { UpcService } from '@/upc/upc.service';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

@Module({
  imports: [TypeOrmModule.forFeature([Edition, Title, UnresolvedUPC])],
  controllers: [UpcController],
  providers: [
    UpcService,
    TMDBService,
    { provide: EditionStore, useClass: TypeORMEditionStore },
    NormalizationService,
    RebuildService,
  ],
})
export class UpcModule {}
