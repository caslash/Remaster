import { BarcodeShape } from '@/upc/types/barcode-shape';
import {
  DiscFormat,
  Edition,
  HDRFormat,
  isHDRFormat,
} from '@/upc/types/edition';
import {
  getBoolean,
  isNotRetailProductReason,
  isRecord,
  isValidString,
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
import dayjs from 'dayjs';
import customParseFormat from 'dayjs/plugin/customParseFormat';
dayjs.extend(customParseFormat);

@Injectable()
export class UpcService {
  private readonly logger = new Logger(UpcService.name);
  constructor(private configService: ConfigService) {}

  public async getTitle(
    upc: string,
    shape: BarcodeShape | undefined,
  ): Promise<Edition> {
    const normalUPC = normalizeUPC(upc, shape);
    const notRetailReason = isNotRetailProductReason(normalUPC);
    if (notRetailReason)
      throw new BadRequestException(
        `Invalid scanned barcode - ${notRetailReason}`,
      );
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

    const body = await response.text();
    try {
      return JSON.parse(body);
    } catch {
      this.logger.warn(`UPCMDB response is not JSON:\n${body}`);
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

    const discFormat = this.normalizeFormat(response);

    return {
      id: upc,
      barcodes: {
        upc: isValidString(response.upc) ? response.upc : undefined,
        ean: isValidString(response.ean) ? response.ean : undefined,
      },
      asin: isValidString(response.asin) ? response.asin : undefined,
      imdbId: isValidString(response.imdbID) ? response.imdbID : undefined,
      title: this.normalizeTitle(upc, response),
      enrichedTitle: isValidString(response.enrichedTitle)
        ? response.enrichedTitle
        : undefined,
      kind: this.normalizeKind(response),
      year: this.normalizeYear(response),
      format: discFormat,
      discContents: undefined,
      hdr: this.normalizeHDR(response, discFormat),
      packaging: this.normalizePackaging(response),
      editionFlags: {
        limited: getBoolean(response.limited_edition),
        collector: getBoolean(response.collectors_edition),
        special: getBoolean(response.special_edition),
        anniversary: getBoolean(response.anniversary_edition),
        boxset: getBoolean(response.boxset),
      },
      masterResolution: this.normalizeResolution(response),
      releaseDate: this.normalizeReleaseDate(response),
      distributor: isValidString(response.publisher)
        ? response.publisher
        : undefined,
      country: isValidString(response.country) ? response.country : undefined,
      coverImageURL: isValidString(response.productImageUrl)
        ? response.productImageUrl
        : undefined,
      runtime: this.normalizeRuntime(response),
      audio: isValidString(response.audio) ? response.audio : undefined,
      subtitles: isValidString(response.subtitles)
        ? response.subtitles
            .split(',')
            .map((sub) => sub.trim())
            .filter((sub) => sub)
        : undefined,
      hasDigital: getBoolean(response.has_digital_copy),
    };
  }

  private normalizeTitle(
    upc: string,
    response: Record<string, unknown>,
  ): string {
    if (isValidString(response.title)) return response.title;

    throw new NotFoundException(`Title for UPC ${upc} could not be found`);
  }

  private normalizeKind(
    response: Record<string, unknown>,
  ): 'movie' | 'tv' | undefined {
    if (response.type === 'movie' || response.omdbType === 'movie')
      return 'movie';
    if (
      response.type === 'series' ||
      response.type === 'tv' ||
      response.omdbType === 'series' ||
      response.omdbType === 'tv' ||
      response.seriesInfo === 'series' ||
      response.seriesInfo === 'tv'
    )
      return 'tv';

    return;
  }

  private normalizeYear(response: Record<string, unknown>): number | undefined {
    const numberYear = Number(response.year);
    if (
      (isValidString(response.year) && Number.isInteger(numberYear)) ||
      (typeof response.year === 'number' && Number.isInteger(response.year))
    )
      return numberYear;

    const numberOMDBYear = Number(response.omdbYear);
    if (
      (isValidString(response.omdbYear) && Number.isInteger(numberOMDBYear)) ||
      (typeof response.omdbYear === 'number' &&
        Number.isInteger(response.omdbYear))
    )
      return numberOMDBYear;

    if (isValidString(response.altYear)) {
      const numberAltYear = Number(`${response.altYear}`.slice(0, 4));

      if (Number.isInteger(numberAltYear)) return numberAltYear;
    }

    if (
      typeof response.altYear === 'number' &&
      Number.isInteger(response.altYear)
    )
      return response.altYear;

    return;
  }

  private normalizeFormat(
    response: Record<string, unknown>,
  ): DiscFormat | undefined {
    if (!isValidString(response.format)) return;

    switch (response.format) {
      case 'DVD':
        return 'DVD';
      case 'BLURAY':
        return 'Blu-ray';
      case '4KUHD':
      case 'UHD4K':
        return '4K UHD';
      default:
        this.logger.warn(`Unknown disc format - ${response.format}`);
        return undefined;
    }
  }

  private normalizeHDR(
    response: Record<string, unknown>,
    discFormat: DiscFormat | undefined,
  ): HDRFormat[] | undefined {
    if (discFormat === 'DVD' || discFormat === 'Blu-ray') return [];
    if (!isValidString(response.hdr)) return undefined;

    const formats: HDRFormat[] = Array.from(
      new Set(
        response.hdr
          .split(',')
          .map((format) => format.trim())
          .filter((format) => format)
          .filter((format): format is HDRFormat => {
            if (isHDRFormat(format)) return true;
            this.logger.warn(`Unknown HDR format - ${format}`);
            return false;
          }),
      ),
    );

    return formats.length > 0 ? formats : undefined;
  }

  private normalizePackaging(response: Record<string, unknown>): {
    steelbook: boolean | undefined;
    slipcover: boolean | undefined;
    memorabilia: boolean | undefined;
  } {
    const packagingText = isValidString(response.packaging)
      ? response.packaging.toLowerCase()
      : undefined;

    return {
      steelbook:
        getBoolean(response.steelbook) ??
        (!!packagingText && packagingText.includes('steelbook')),
      slipcover:
        getBoolean(response.slipcover) || isValidString(response.slipcover),
      memorabilia: packagingText
        ? packagingText.includes('figure/replica/props/memorabilia included')
        : undefined,
    };
  }

  private normalizeResolution(
    response: Record<string, unknown>,
  ): 'native' | 'upscaled' | undefined {
    if (!isValidString(response.resolution)) return;

    return response.resolution.toLowerCase().includes('upscaled')
      ? 'upscaled'
      : response.resolution.toLowerCase().includes('native')
        ? 'native'
        : undefined;
  }

  private normalizeReleaseDate(
    response: Record<string, unknown>,
  ): string | undefined {
    if (!isValidString(response.releaseDate)) return;

    const parsedDate = dayjs(response.releaseDate, 'MMM DD, YYYY', true);

    if (parsedDate.isValid()) return parsedDate.format('YYYY-MM-DD');

    this.logger.warn(`Unknown releaseDate format - ${response.releaseDate}`);
  }

  private normalizeRuntime(
    response: Record<string, unknown>,
  ): number | undefined {
    if (!isValidString(response.runtime)) return;

    const numberString = response.runtime.match(/\d+/)?.[0];

    return numberString ? Number(numberString) : undefined;
  }
}
