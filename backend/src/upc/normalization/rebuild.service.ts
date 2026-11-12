import { NormalizationService } from '@/upc/normalization/normalization.service';
import { EditionStore } from '@/upc/storage/upc.storage.store';
import { EditionResponse } from '@/upc/types/edition';
import { RebuildSummary } from '@/upc/types/rebuild-summary';
import { isRecord, NORMALIZER_VERSION } from '@/upc/utils/upc.utils';
import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class RebuildService {
  private readonly logger = new Logger(RebuildService.name);
  constructor(
    private editionStore: EditionStore,
    private normalizationService: NormalizationService,
  ) {}

  public async rebuildEditions(
    version: number = NORMALIZER_VERSION,
  ): Promise<RebuildSummary> {
    const editions = await this.editionStore.findOutOfDateEditions(version);

    const summary: RebuildSummary = {
      targetVersion: version,
      foundEditions: editions.length,
      rebuilt: 0,
      changedMeanwhile: 0,
      failedIds: [],
      mismatchedIds: [],
    };

    for (const edition of editions) {
      if (!isRecord(edition.raw)) {
        this.logger.warn(
          `Edition ${edition.id} failed as its raw field is not a record`,
        );
        summary.failedIds.push(edition.id);
        continue;
      }

      let normalizedEdition: Omit<EditionResponse, 'title' | 'unmatchedTitle'>;

      try {
        normalizedEdition = this.normalizationService.normalizeUpcResponse(
          edition.id,
          edition.raw,
        );
      } catch (error) {
        if (error instanceof Error) {
          this.logger.warn(
            `Edition ${edition.id} failed with: ${error.message}`,
          );
        } else {
          this.logger.warn(
            `Edition ${edition.id} failed with: ${String(error)}`,
          );
        }
        summary.failedIds.push(edition.id);
        continue;
      }

      const oldImdbId = edition.imdbId ?? 'none';
      const newImdbId = normalizedEdition.imdbId ?? 'none';

      const updated = await this.editionStore.updateEditionNormalizedFields(
        edition.id,
        normalizedEdition,
        version,
      );

      if (updated) {
        summary.rebuilt += 1;

        if (oldImdbId !== newImdbId) {
          this.logger.warn(
            `Edition ${edition.id} returned a mismatched imdbId - old: ${oldImdbId}, new: ${newImdbId}`,
          );
          summary.mismatchedIds.push(edition.id);
        }
      } else {
        summary.changedMeanwhile += 1;
      }
    }

    return summary;
  }
}
