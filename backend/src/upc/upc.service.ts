import { Env } from '@/app.module';
import { UpcTitleNotFoundException } from '@/upc/normalization/normalization.error';
import { NormalizationService } from '@/upc/normalization/normalization.service';
import { EditionStore } from '@/upc/storage/upc.storage.store';
import { TMDBService } from '@/upc/tmdb.service';
import { BarcodeShape } from '@/upc/types/barcode-shape';
import { EditionResponse } from '@/upc/types/edition';
import { POSTER_SIZES } from '@/upc/types/poster-size';
import { Title } from '@/upc/types/title';
import {
  isNotRetailProductReason,
  isRecord,
  NORMALIZER_VERSION,
  normalizeUPC,
} from '@/upc/utils/upc.utils';
import {
  BadGatewayException,
  BadRequestException,
  GatewayTimeoutException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class UpcService {
  private readonly logger = new Logger(UpcService.name);
  constructor(
    private tmdbService: TMDBService,
    private configService: ConfigService<Env, true>,
    private editionStore: EditionStore,
    private normalizationService: NormalizationService,
  ) {}

  public async getEdition(
    upc: string,
    shape: BarcodeShape | undefined,
  ): Promise<EditionResponse> {
    const normalUPC = normalizeUPC(upc, shape);
    const notRetailReason = isNotRetailProductReason(normalUPC);
    if (notRetailReason)
      throw new BadRequestException(
        `Invalid scanned barcode - ${notRetailReason}`,
      );
    try {
      const existingEdition =
        await this.editionStore.findEditionByGTIN(normalUPC);
      if (existingEdition) {
        this.logger.log(
          `Found existing Edition for ${upc}, skipping UPCMDB request`,
        );
        return existingEdition;
      }

      const response: Record<string, unknown> = await this.fetchUPC(
        upc,
        normalUPC,
      );

      if (typeof response.ean === 'string' && response.ean !== normalUPC)
        this.logger.warn(
          `UPCMDB EAN ${response.ean} differs from normalized code ${normalUPC} (scanned ${upc})`,
        );

      const responseEdition = this.normalizationService.normalizeUpcResponse(
        normalUPC,
        response,
      );

      let title: Title | undefined;

      try {
        title = responseEdition.imdbId
          ? await this.tmdbService.getTitle(
              responseEdition.imdbId,
              responseEdition.kind,
            )
          : undefined;
      } catch (error) {
        if (
          error instanceof BadGatewayException ||
          error instanceof GatewayTimeoutException
        ) {
          return {
            ...responseEdition,
            unmatchedTitle: true,
          };
        }

        throw error;
      }

      await this.editionStore.saveEdition({
        ...responseEdition,
        raw: response,
        fetchedAt: new Date(),
        normalizerVersion: NORMALIZER_VERSION,
        title: title,
      });

      return title
        ? {
            ...responseEdition,
            title: {
              tmdbId: title.tmdbId,
              kind: title.kind,
              name: title.name,
              year: title.year,
              imdbId: title.imdbId,
              posterURL: title.posterPath
                ? this.tmdbService.getPosterURL(
                    title.posterPath,
                    POSTER_SIZES.W500,
                  )
                : undefined,
            },
            unmatchedTitle: false,
          }
        : { ...responseEdition, unmatchedTitle: true };
    } catch (error) {
      if (error instanceof UpcTitleNotFoundException) {
        await this.editionStore.recordUnresolvedGTIN(normalUPC);
        throw new NotFoundException();
      }
      if (error instanceof DOMException) {
        if (error.name === 'TimeoutError') {
          this.logger.error(error.message);
          throw new GatewayTimeoutException('UPCMDB request timed out for UPC');
        }
        this.logger.error(error.message);
        throw error;
      }
      if (error instanceof Error) {
        if (error instanceof NotFoundException) throw error;
        this.logger.error(error.message);
      }
      throw error;
    }
  }

  private async fetchUPC(
    upc: string,
    normalUPC: string,
  ): Promise<Record<string, unknown>> {
    const upcmdbURL =
      this.configService.getOrThrow<string>('UPCMDB_LOOKUP_URL');
    const upcmdbKey = this.configService.getOrThrow<string>('UPCMDB_API_KEY');

    const response = await fetch(`${upcmdbURL}${upc}`, {
      method: 'GET',
      headers: { 'x-api-key': upcmdbKey },
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      switch (response.status) {
        case 404:
          await this.editionStore.recordUnresolvedGTIN(normalUPC);
          throw new NotFoundException(response.statusText);
        case 500:
          throw new BadGatewayException(response.statusText);
        default:
          throw new BadGatewayException(
            `UPCMDB responded with status ${response.status} - ${response.statusText}`,
          );
      }
    }

    const body = await response.text();
    try {
      const json: unknown = JSON.parse(body);
      if (isRecord(json)) return json;
      throw new NotFoundException();
    } catch (error) {
      if (error instanceof SyntaxError) {
        this.logger.warn(`UPCMDB response is not JSON:\n${body}`);
        throw new NotFoundException();
      }
      throw error;
    }
  }
}
