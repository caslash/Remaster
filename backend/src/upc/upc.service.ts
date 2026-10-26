import {
  BadGatewayException,
  GatewayTimeoutException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Edition } from '@/upc/types/edition';
import { BarcodeShape } from '@/upc/types/barcode-shape';
import { isRecord, normalizeUPC } from '@/upc/utils/upc.utils';

@Injectable()
export class UpcService {
  private readonly logger = new Logger(UpcService.name);
  constructor(private configService: ConfigService) {}

  public async getTitle(
    upc: string,
    shape: BarcodeShape | undefined,
  ): Promise<Edition> {
    const normalUPC = normalizeUPC(upc, shape);
    try {
      return this.normalizeResponse(normalUPC, await this.fetchUPC(normalUPC));
    } catch (error) {
      if (error instanceof DOMException) {
        if (error.name === 'TimeoutError') {
          this.logger.error(error.message);
          throw new GatewayTimeoutException();
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

  private async fetchUPC(upc: string): Promise<unknown> {
    const upcmdbURL = this.configService.get<string>('UPCMDB_LOOKUP_URL') ?? '';
    const upcmdbKey = this.configService.get<string>('UPCMDB_API_KEY') ?? '';

    const response = await fetch(`${upcmdbURL}${upc}`, {
      method: 'GET',
      headers: { 'x-api-key': upcmdbKey },
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      switch (response.status) {
        case 404:
          throw new NotFoundException(response.statusText);
        case 500:
          throw new BadGatewayException(response.statusText);
        default:
          throw new BadGatewayException(
            `UPCMDB responded with status ${response.status} - ${response.statusText}`,
          );
      }
    }

    try {
      return response.json();
    } catch {
      this.logger.warn(
        `UPCMDB response is not an object:\n${JSON.stringify(response)}`,
      );
      throw new NotFoundException();
    }
  }

  private normalizeResponse(upc: string, response: unknown): Edition {
    if (!isRecord(response)) {
      this.logger.warn(
        `UPCMDB response is not an object:\n${JSON.stringify(response)}`,
      );
      throw new NotFoundException();
    }

    if (typeof response.ean === 'string' && response.ean !== upc)
      this.logger.warn(
        `EAN ${response.ean} does not match the normalized UPC ${upc}`,
      );

    return {
      id: upc,
      barcodes: {
        upc: undefined,
        ean: undefined,
      },
      asin: undefined,
      imdbId: undefined,
      title: '',
      enrichedTitle: undefined,
      kind: undefined,
      year: undefined,
      format: undefined,
      discContents: undefined,
      hdr: undefined,
      packaging: {
        steelbook: undefined,
        slipcover: undefined,
        memorabilia: undefined,
      },
      editionFlags: {
        limited: undefined,
        collector: undefined,
        special: undefined,
        anniversary: undefined,
        boxset: undefined,
      },
      masterResolution: undefined,
      releaseDate: undefined,
      distributor: undefined,
      country: undefined,
      coverImageURL: undefined,
      runtime: undefined,
      audio: undefined,
      subtitles: undefined,
      hasDigital: undefined,
    };
  }
}
