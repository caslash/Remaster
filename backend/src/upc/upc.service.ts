import { Env } from '@/app.module';
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
  mergeDiscTypes,
  normalizeUPC,
  parseDiscCounts,
  parsePlayback,
  parseYear,
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
  constructor(private configService: ConfigService<Env, true>) {}

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
      return this.normalizeResponse(normalUPC, await this.fetchUPC(upc));
    } catch (error) {
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

  private async fetchUPC(upc: string): Promise<unknown> {
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
      discContents: this.normalizeDiscContents(upc, response, discFormat),
      hdr: this.normalizeHDR(response, discFormat),
      packaging: this.normalizePackaging(upc, response),
      editionFlags: {
        limited: getBoolean(response.limited_edition),
        collector: getBoolean(response.collectors_edition),
        special: getBoolean(response.special_edition),
        anniversary: getBoolean(response.anniversary_edition),
        boxset: getBoolean(response.boxset),
      },
      masterResolution: this.normalizeResolution(response, discFormat),
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
    const year = parseYear(response.year);
    const omdbYear = parseYear(response.omdbYear);
    const altYear = parseYear(response.altYear);

    return year ? year : omdbYear ? omdbYear : altYear;
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

  private normalizeDiscContents(
    upc: string,
    response: Record<string, unknown>,
    discFormat: DiscFormat | undefined,
  ): Edition['discContents'] {
    if (!isValidString(response.discs) || !isValidString(response.playback))
      return;

    const discCounts = parseDiscCounts(response.discs);
    if (!discCounts) {
      this.logger.warn(`Unknown disc count for UPC ${upc} - ${response.discs}`);
      return;
    }
    const totalDiscs = discCounts.reduce((acc, curr) => acc + curr.count, 0);

    const playback = parsePlayback(response.playback, discFormat);
    if (!playback.ok) {
      this.logger.warn(
        playback.reason === 'unknown-format'
          ? `Unknown disc format for UPC ${upc} - ${playback.segment}`
          : `Unlabelled playback segment with unknown edition format for UPC ${upc} - ${playback.segment}`,
      );
      return;
    }
    for (const region of playback.unknownRegions)
      this.logger.warn(`Unknown disc region for UPC ${upc} - ${region}`);
    const discTypes = mergeDiscTypes(playback.discTypes);

    if (discTypes.length === 0) {
      this.logger.warn(
        `No disc types in playback for UPC ${upc} - ${response.playback}`,
      );
      return;
    }

    discTypes.sort(
      (a, b) => Number(b.format === '4K UHD') - Number(a.format === '4K UHD'),
    );

    if (discTypes.length === 1)
      return Array.from({ length: totalDiscs }, () => ({ ...discTypes[0] }));

    const [fourKType, bluRayType] = discTypes;
    if (
      discTypes.length === 2 &&
      fourKType.format === '4K UHD' &&
      bluRayType.format === 'Blu-ray'
    ) {
      const fourKDiscs = Math.max(
        discCounts
          .filter(
            (item) => item.capacity === 'BD-66' || item.capacity === 'BD-100',
          )
          .reduce((acc, curr) => acc + curr.count, 0),
        1,
      );
      const bluRayDiscs = Math.max(totalDiscs - fourKDiscs, 1);

      if (fourKDiscs + bluRayDiscs === totalDiscs)
        return [
          ...Array.from({ length: fourKDiscs }, () => ({ ...fourKType })),
          ...Array.from({ length: bluRayDiscs }, () => ({ ...bluRayType })),
        ];
    }

    this.logger.warn(
      `Unable to split discs between types for UPC ${upc} - discs: ${response.discs}, playback: ${response.playback}`,
    );
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

  private normalizePackaging(
    upc: string,
    response: Record<string, unknown>,
  ): {
    steelbook: boolean | undefined;
    slipcover: boolean | undefined;
    memorabilia: boolean | undefined;
  } {
    const packagingText = isValidString(response.packaging)
      ? response.packaging.toLowerCase()
      : undefined;
    const specialFeaturesText = isValidString(response.special_features)
      ? response.special_features.toLowerCase()
      : undefined;

    const getSteelbook = (): boolean | undefined => {
      const bool = getBoolean(response.steelbook);
      const textMatch =
        !!packagingText?.includes('steelbook') ||
        !!specialFeaturesText?.includes('steelbook');

      if (!textMatch) return bool;
      if (bool === false) {
        this.logger.warn(
          `UPCMDB steelbook flag is false but text says steelbook for UPC ${upc} - packaging: ${String(response.packaging)}, special_features: ${String(response.special_features)}`,
        );
      }
      return true;
    };

    const getSlipcover = (): boolean | undefined => {
      const bool = getBoolean(response.slipcover);
      const textMatch =
        !!packagingText?.includes('slipcover') ||
        (isValidString(response.slipcover) &&
          response.slipcover.toLowerCase().includes('slipcover'));

      if (!textMatch) return bool;
      if (bool === false) {
        this.logger.warn(
          `UPCMDB slipcover flag is false but text says slipcover for UPC ${upc} - packaging: ${String(response.packaging)}, slipcover: ${String(response.slipcover)}`,
        );
      }
      return true;
    };

    const extrasText: string[] = [
      'figure',
      'replica',
      'props',
      'memorabilia',
      "collector's box",
    ];

    return {
      steelbook: getSteelbook(),
      slipcover: getSlipcover(),
      memorabilia:
        packagingText &&
        extrasText.some((extra) => packagingText.includes(extra))
          ? true
          : undefined,
    };
  }

  private normalizeResolution(
    response: Record<string, unknown>,
    discFormat: DiscFormat | undefined,
  ): 'native' | 'upscaled' | undefined {
    if (discFormat !== '4K UHD') return;
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

    const parsedDate = dayjs(
      response.releaseDate,
      ['MMM DD, YYYY', 'MMM D, YYYY'],
      true,
    );

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
