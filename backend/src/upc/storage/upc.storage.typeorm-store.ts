import { EditionStore } from '@/upc/storage/upc.storage.store';
import { TMDBService } from '@/upc/tmdb.service';
import { Edition, EditionResponse } from '@/upc/types/edition';
import { POSTER_SIZES } from '@/upc/types/poster-size';
import { Title, TitleResponse } from '@/upc/types/title';
import { UnresolvedUPC } from '@/upc/types/unresolved-upc';
import { castUndefinedToNull } from '@/upc/utils/upc.utils';
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, LessThan, Repository } from 'typeorm';

@Injectable()
export class TypeORMEditionStore extends EditionStore {
  constructor(
    @InjectRepository(Edition)
    private editionRepository: Repository<Edition>,
    @InjectRepository(Title)
    private titleRepository: Repository<Title>,
    @InjectRepository(UnresolvedUPC)
    private unresolvedRepository: Repository<UnresolvedUPC>,
    private readonly dataSource: DataSource,
    private tmdbService: TMDBService,
  ) {
    super();
  }

  async findEditionByGTIN(gtin: string): Promise<EditionResponse | null> {
    const dbEdition = await this.editionRepository.findOne({
      where: { id: gtin },
      relations: { title: true },
    });
    if (!dbEdition) return null;

    const { raw, normalizerVersion, fetchedAt, title, ...editionResponse } =
      dbEdition;

    let responseTitle: TitleResponse | undefined;

    if (dbEdition.title) {
      const { raw, posterPath, editions, ...titleResponse } = dbEdition.title;

      responseTitle = {
        ...titleResponse,
        posterURL: posterPath
          ? this.tmdbService.getPosterURL(posterPath, POSTER_SIZES.W500)
          : undefined,
      };
    }

    return responseTitle
      ? {
          ...editionResponse,
          title: responseTitle,
          unmatchedTitle: false,
        }
      : {
          ...editionResponse,
          unmatchedTitle: true,
        };
  }

  async saveEdition(edition: Edition): Promise<void> {
    await this.dataSource.manager.transaction(
      async (transactionalEntityManager) => {
        if (edition.title)
          await transactionalEntityManager.upsert(Title, edition.title, {
            conflictPaths: ['tmdbId', 'kind'],
          });

        await transactionalEntityManager.delete(UnresolvedUPC, edition.id);

        await transactionalEntityManager.upsert(Edition, edition, {
          conflictPaths: ['id'],
        });
      },
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
      .leftJoinAndSelect('edition.title', 'title')
      .getOne();
  }

  async findOutOfDateEditions(version: number): Promise<Edition[]> {
    return await this.editionRepository
      .createQueryBuilder('edition')
      .where('edition.normalizerVersion < :version', {
        version,
      })
      .addSelect('edition.normalizerVersion')
      .addSelect('edition.raw')
      .getMany();
  }

  async updateEditionNormalizedFields(
    id: string,
    updatedFields: Omit<EditionResponse, 'title' | 'unmatchedTitle'>,
    version: number,
  ): Promise<boolean> {
    const { id: leftOutId, ...normalizedFields } =
      this.normalizeUndefinedFields(updatedFields);

    const numberAffected = (
      await this.editionRepository.update(
        { id, normalizerVersion: LessThan(version) },
        {
          ...normalizedFields,
          normalizerVersion: version,
        },
      )
    ).affected;

    return !!numberAffected;
  }

  private normalizeUndefinedFields(
    obj: Omit<EditionResponse, 'title' | 'unmatchedTitle'>,
  ): Omit<EditionResponse, 'title' | 'unmatchedTitle'> {
    return Object.fromEntries(
      Object.entries(obj).map(([key, value]) => {
        if (
          key === 'barcodes' ||
          key === 'packaging' ||
          key === 'editionFlags'
        ) {
          if (typeof value != 'object') return [key, null];

          return [
            key,
            Object.fromEntries(
              Object.entries(value).map(([key, value]) => {
                return [key, castUndefinedToNull(value)];
              }),
            ),
          ];
        }

        return [key, castUndefinedToNull(value)];
      }),
    ) as unknown as Omit<EditionResponse, 'title' | 'unmatchedTitle'>;
  }
}
