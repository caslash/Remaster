import { UpcService } from '@/upc/upc.service';
import {
  BadGatewayException,
  BadRequestException,
  GatewayTimeoutException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { Edition } from './types/edition';
import { StoreRangeReason } from './utils/upc.utils';

import zootopia from './mock/movie4kdv.json';
import wandavision from './mock/tv4khdr.json';

describe('UpcService', () => {
  let service: UpcService;

  const mockConfigServiceGet = jest.fn();
  const mockConfigService = {
    get: mockConfigServiceGet,
  };

  const fetchFixture = async (
    upc: string,
    fixture: Record<string, unknown>,
  ): Promise<Edition> => {
    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: () => Promise.resolve(JSON.stringify(fixture)),
    });

    return await service.getTitle(upc, undefined);
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UpcService,
        { provide: ConfigService, useValue: mockConfigService },
      ],
    }).compile();

    service = module.get<UpcService>(UpcService);

    mockConfigServiceGet.mockReturnValue('Test');
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should deny invalid UPC value', async () => {
    const upc = '1234';

    global.fetch = jest.fn();

    await expect(service.getTitle(upc, undefined)).rejects.toThrow(
      BadRequestException,
    );
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('should deny coupon UPCs', async () => {
    const upc = '9811234567891';

    global.fetch = jest.fn();

    const result = service.getTitle(upc, undefined);

    await expect(result).rejects.toThrow(BadRequestException);
    await expect(result).rejects.toThrow(StoreRangeReason.COUPON);
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('should throw NotFound when UPC is not found', async () => {
    const upc = '043396647640';

    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: false,
      status: 404,
    });

    await expect(service.getTitle(upc, undefined)).rejects.toThrow(
      NotFoundException,
    );
  });

  it('should throw BadGateway when UPCMDB responds with 500', async () => {
    const upc = '043396647640';

    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: false,
      status: 500,
    });

    await expect(service.getTitle(upc, undefined)).rejects.toThrow(
      BadGatewayException,
    );
  });

  it('should throw BadGateway when UPCMDB responds with other error', async () => {
    const upc = '043396647640';

    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: false,
      status: 403,
      statusText: 'Generic Text',
    });

    const result = service.getTitle(upc, undefined);

    await expect(result).rejects.toThrow(BadGatewayException);
    await expect(result).rejects.toThrow(
      'UPCMDB responded with status 403 - Generic Text',
    );
  });

  it('should GatewayTimeout when UPCMDB request times out', async () => {
    const upc = '043396647640';

    global.fetch = jest
      .fn()
      .mockRejectedValueOnce(new DOMException(undefined, 'TimeoutError'));

    await expect(service.getTitle(upc, undefined)).rejects.toThrow(
      GatewayTimeoutException,
    );
  });

  it('should throw NotFound and log the body when UPCMDB responds with non-JSON', async () => {
    const upc = '043396647640';
    const body = '<html><body><h1>503 Service Unavailable</h1></body></html>';
    const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation();

    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: () => Promise.resolve(body),
    });

    await expect(service.getTitle(upc, undefined)).rejects.toThrow(
      NotFoundException,
    );
    expect(warn).toHaveBeenCalledWith(expect.stringContaining(body));
  });

  it('should normalize edition id', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.id).not.toBe(zootopia.upc);
    expect(zootopiaEdition.id).not.toBe('');
    expect(zootopiaEdition.id).toBe(zootopia.ean);
  });

  it('should normalize edition barcodes', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.barcodes).toStrictEqual({
      upc: '043396647640',
      ean: '0043396647640',
    });
  });

  it('should normalize edition asin', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.asin).toBe('B0GKTVSN8N');
  });

  it('should normalize edition imdbId', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.imdbId).toBe('tt26443597');
  });

  it('should normalize edition title', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.title).toBe('Zootopia 2');
  });

  it('should normalize edition enrichedTitle', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.enrichedTitle).toBe('Zootopia 2');
  });

  it('should normalize edition kind', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.kind).toBe('movie');
  });

  it('should normalize edition year', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const omdbYearEdition = await fetchFixture('043396647640', {
      title: 'omdbYear',
      year: 'N/A',
      omdbYear: '2021',
    });
    const altYearEdition = await fetchFixture('043396647640', {
      title: 'altYear',
      year: 'N/A',
      omdbYear: 'N/A',
      altYear: '2013–',
    });
    const junkYearEdition = await fetchFixture('043396647640', {
      title: 'junkYear',
      year: 2025.5,
      omdbYear: 'N/A',
      altYear: 'N/A',
    });

    expect(zootopiaEdition.year).toBe(2025);
    expect(omdbYearEdition.year).toBe(2021);
    expect(altYearEdition.year).toBe(2013);
    expect(junkYearEdition.year).toBe(undefined);
  });

  it('should normalize edition format', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.format).toBe('4K UHD');
  });

  // it('should normalize edition discContents', async () => {
  //   const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

  //   expect(zootopiaEdition.discContents).toStrictEqual([]);
  // });

  it('should normalize edition hdr', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.hdr).toStrictEqual(
      expect.arrayContaining(['Dolby Vision', 'HDR10']),
    );
  });

  it('should normalize edition packaging', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.packaging).toStrictEqual({
      steelbook: true,
      slipcover: false,
      memorabilia: false,
    });
  });

  it('should normalize edition editionFlags', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);

    expect(zootopiaEdition.editionFlags).toStrictEqual({
      limited: undefined,
      collector: undefined,
      special: undefined,
      anniversary: undefined,
      boxset: undefined,
    });
    expect(wandaVisionEdition.editionFlags).toStrictEqual({
      limited: false,
      collector: true,
      special: false,
      anniversary: false,
      boxset: false,
    });
  });

  it('should normalize edition masterResolution', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.masterResolution).toBe('upscaled');
  });

  it('should normalize edition releaseDate', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const junkDateEdition = await fetchFixture('043396647640', {
      title: 'junk',
      releaseDate: '2026/03/03 junk',
    });

    expect(zootopiaEdition.releaseDate).toBe('2026-03-03');
    expect(junkDateEdition.releaseDate).toBe(undefined);
  });

  it('should normalize edition distributor', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.distributor).toBe('Disney / Buena Vista');
  });

  it('should normalize edition country', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.country).toBe('United States');
  });

  it('should normalize edition coverImageURL', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.coverImageURL).toBe(
      'https://imagestorage.org/043396647640.jpg',
    );
  });

  it('should normalize edition runtime', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.runtime).toBe(108);
  });

  it('should normalize edition audio', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.audio).toBe(
      'English: Dolby Atmos English: Dolby TrueHD 7.1 (48kHz, 24-bit) French: Dolby Digital Plus 7.1 Spanish: Dolby Digital Plus 7.1 Japanese: Dolby Digital Plus 7.1 | Audio descriptive',
    );
  });

  it('should normalize edition subtitles', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.subtitles).toStrictEqual([
      'English SDH',
      'French',
      'Japanese',
      'Spanish',
    ]);
  });

  it('should normalize edition hasDigital', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);

    expect(zootopiaEdition.hasDigital).toBe(true);
  });
});
