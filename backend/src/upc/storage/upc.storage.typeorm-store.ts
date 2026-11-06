import { EditionStore } from '@/upc/storage/upc.storage.store';
import { Edition, EditionResponse } from '@/upc/types/edition';
import { Title } from '@/upc/types/title';
import { UnresolvedUPC } from '@/upc/types/unresolved-upc';
import { NORMALIZER_VERSION } from '@/upc/utils/upc.utils';
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

@Injectable()
export class TypeORMEditionStore extends EditionStore {
  constructor(
    @InjectRepository(Edition)
    private editionRepository: Repository<Edition>,
    @InjectRepository(Title)
    private titleRepository: Repository<Title>,
    @InjectRepository(UnresolvedUPC)
    private unresolvedRepository: Repository<UnresolvedUPC>,
  ) {
    super();
  }

  async findEditionByGTIN(gtin: string): Promise<EditionResponse | null> {
    return await this.editionRepository.findOne({ where: { id: gtin } });
  }

  async saveEdition(edition: EditionResponse, raw: object): Promise<void> {
    await this.editionRepository.upsert(
      {
        ...edition,
        raw,
        fetchedAt: new Date(),
        normalizerVersion: NORMALIZER_VERSION,
      },
      { conflictPaths: ['id'] },
    );
  }

  async saveTitle(title: Title): Promise<void> {
    await this.titleRepository.upsert(title, {
      conflictPaths: ['tmdbId', 'kind'],
    });
  }

  async recordUnresolvedGTIN(gtin: string): Promise<void> {
    await this.unresolvedRepository.upsert(
      { gtin, lastSeenAt: new Date() },
      { conflictPaths: ['gtin'] },
    );
  }

  async findFullEditionByGTIN(gtin: string): Promise<Edition | null> {
    return await this.editionRepository
      .createQueryBuilder('edition')
      .where('edition.id = :id', { id: gtin })
      .addSelect('edition.raw')
      .addSelect('edition.fetchedAt')
      .addSelect('edition.normalizerVersion')
      .leftJoinAndSelect('edition.work', 'work')
      .getOne();
  }
}
