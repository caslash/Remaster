import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
  RequestTimeoutException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import validbarcode = require('barcode-validator');
import { Edition } from './types/edition';

@Injectable()
export class UpcService {
  private readonly logger = new Logger(UpcService.name);
  constructor(private configService: ConfigService) {}

  public async getTitle(upc: string): Promise<Edition | undefined> {
    try {
      return this.normalizeResponse(await this.fetchUPC(upc));
    } catch (error) {
      if (error instanceof Error) {
        this.logger.error(error.message);
        if (error.name === 'TimeoutError') {
          throw new RequestTimeoutException();
        }
        throw error;
      }
    }
  }

  private async fetchUPC(upc: string): Promise<Record<any, any>> {
    if (!validbarcode(upc)) throw new BadRequestException('Invalid Barcode');

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
          throw new InternalServerErrorException(response.statusText);
        default:
          throw new Error(
            `UPCMDB responded with status ${response.status} - ${response.statusText}`,
          );
      }
    }

    return response.json();
  }

  private normalizeResponse(title: Record<any, any>): Edition {
    return {
      id: '',
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
      digital: undefined,
    };
  }
}
