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
import blackPanther from './mock/movie4khdr.json';
import barnyard from './mock/moviebr.json';
import austinPowers from './mock/moviedvd.json';
import loki from './mock/tv4kdv.json';
import wandavision from './mock/tv4khdr.json';
import rickAndMorty from './mock/tvbr.json';
import spongebob from './mock/tvdvd.json';

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
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.id).not.toBe(zootopia.upc);
    expect(zootopiaEdition.id).not.toBe('');
    expect(zootopiaEdition.id).toBe(zootopia.ean);
    expect(blackPantherEdition.id).toBe(blackPanther.ean);
    expect(lokiEdition.id).toBe(loki.ean);
    expect(wandaVisionEdition.id).toBe(wandavision.ean);
    expect(barnyardEdition.id).toBe(barnyard.ean);
    expect(rickAndMortyEdition.id).toBe(rickAndMorty.ean);
    expect(austinPowersEdition.id).toBe(austinPowers.ean);
    expect(spongebobEdition.id).toBe(spongebob.ean);
  });

  it('should normalize edition barcodes', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.barcodes).toStrictEqual({
      upc: '043396647640',
      ean: '0043396647640',
    });
    expect(blackPantherEdition.barcodes).toStrictEqual({
      upc: '786936893601',
      ean: '0786936893601',
    });
    expect(lokiEdition.barcodes).toStrictEqual({
      upc: '043396640559',
      ean: '0043396640559',
    });
    expect(wandaVisionEdition.barcodes).toStrictEqual({
      upc: '786936900378',
      ean: '0786936900378',
    });
    expect(barnyardEdition.barcodes).toStrictEqual({
      upc: '191329211991',
      ean: '0191329211991',
    });
    expect(rickAndMortyEdition.barcodes).toStrictEqual({
      upc: '883929374342',
      ean: '0883929374342',
    });
    expect(austinPowersEdition.barcodes).toStrictEqual({
      upc: '794043602825',
      ean: '0794043602825',
    });
    expect(spongebobEdition.barcodes).toStrictEqual({
      upc: '032429342829',
      ean: '0032429342829',
    });
  });

  it('should normalize edition asin', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.asin).toBe('B0GKTVSN8N');
    expect(blackPantherEdition.asin).toBe('B0BRYB43MG');
    expect(lokiEdition.asin).toBe('B0DL78H7CG');
    expect(wandaVisionEdition.asin).toBe('B0CG6J1JLT');
    expect(barnyardEdition.asin).toBe('B09KNGJVQ9');
    expect(rickAndMortyEdition.asin).toBe('B00LOWJ6JY');
    expect(austinPowersEdition.asin).toBe('B00006WUWN');
    expect(spongebobEdition.asin).toBe('B086PNWN9F');
  });

  it('should normalize edition imdbId', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.imdbId).toBe('tt26443597');
    expect(blackPantherEdition.imdbId).toBe('tt9114286');
    expect(lokiEdition.imdbId).toBe(undefined);
    expect(wandaVisionEdition.imdbId).toBe('tt9140560');
    expect(barnyardEdition.imdbId).toBe('tt0414853');
    expect(rickAndMortyEdition.imdbId).toBe('tt2861424');
    expect(austinPowersEdition.imdbId).toBe('tt0295178');
    expect(spongebobEdition.imdbId).toBe(undefined);
  });

  it('should normalize edition title', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.title).toBe('Zootopia 2');
    expect(blackPantherEdition.title).toBe('Black Panther: Wakanda Forever');
    expect(lokiEdition.title).toBe('Loki: The Complete Second Season');
    expect(wandaVisionEdition.title).toBe('WandaVision: The Complete Series');
    expect(barnyardEdition.title).toBe('Barnyard');
    expect(rickAndMortyEdition.title).toBe('Rick and Morty: Season 1');
    expect(austinPowersEdition.title).toBe('Austin Powers in Goldmember');
    expect(spongebobEdition.title).toBe(
      'SpongeBob SquarePants: The First 100 Episodes',
    );
  });

  it('should normalize edition enrichedTitle', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.enrichedTitle).toBe('Zootopia 2');
    expect(blackPantherEdition.enrichedTitle).toBe(
      'Black Panther: Wakanda Forever',
    );
    expect(lokiEdition.enrichedTitle).toBe(undefined);
    expect(wandaVisionEdition.enrichedTitle).toBe('WandaVision');
    expect(barnyardEdition.enrichedTitle).toBe(undefined);
    expect(rickAndMortyEdition.enrichedTitle).toBe(undefined);
    expect(austinPowersEdition.enrichedTitle).toBe(undefined);
    expect(spongebobEdition.enrichedTitle).toBe(undefined);
  });

  it('should normalize edition kind', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.kind).toBe('movie');
    expect(blackPantherEdition.kind).toBe('movie');
    expect(lokiEdition.kind).toBe(undefined);
    expect(wandaVisionEdition.kind).toBe('tv');
    expect(barnyardEdition.kind).toBe('movie');
    expect(rickAndMortyEdition.kind).toBe('tv');
    expect(austinPowersEdition.kind).toBe('movie');
    expect(spongebobEdition.kind).toBe(undefined);
  });

  it('should normalize edition year', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);
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
    expect(blackPantherEdition.year).toBe(2022);
    expect(lokiEdition.year).toBe(2023);
    expect(wandaVisionEdition.year).toBe(2021);
    expect(barnyardEdition.year).toBe(2006);
    expect(rickAndMortyEdition.year).toBe(2013);
    expect(austinPowersEdition.year).toBe(2002);
    expect(spongebobEdition.year).toBe(undefined);
    expect(omdbYearEdition.year).toBe(2021);
    expect(altYearEdition.year).toBe(2013);
    expect(junkYearEdition.year).toBe(undefined);
  });

  it('should normalize edition format', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.format).toBe('4K UHD');
    expect(blackPantherEdition.format).toBe('4K UHD');
    expect(lokiEdition.format).toBe('4K UHD');
    expect(wandaVisionEdition.format).toBe('4K UHD');
    expect(barnyardEdition.format).toBe('Blu-ray');
    expect(rickAndMortyEdition.format).toBe('Blu-ray');
    expect(austinPowersEdition.format).toBe('DVD');
    expect(spongebobEdition.format).toBe('DVD');
  });

  it('should normalize edition discContents', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.discContents?.length).toBe(2);
    expect(zootopiaEdition.discContents).toStrictEqual([
      { format: '4K UHD', region: 'Region free' },
      { format: 'Blu-ray', region: ['A', 'B'] },
    ]);
    expect(blackPantherEdition.discContents?.length).toBe(2);
    expect(blackPantherEdition.discContents).toStrictEqual([
      { format: '4K UHD', region: 'Region free' },
      { format: 'Blu-ray', region: 'Region free' },
    ]);
    expect(lokiEdition.discContents?.length).toBe(2);
    expect(lokiEdition.discContents).toStrictEqual([
      { format: '4K UHD', region: 'Region free' },
      { format: '4K UHD', region: 'Region free' },
    ]);
    expect(wandaVisionEdition.discContents?.length).toBe(2);
    expect(wandaVisionEdition.discContents).toStrictEqual([
      { format: '4K UHD', region: 'Region free' },
      { format: '4K UHD', region: 'Region free' },
    ]);
    expect(barnyardEdition.discContents?.length).toBe(undefined);
    expect(rickAndMortyEdition.discContents?.length).toBe(undefined);
    expect(austinPowersEdition.discContents?.length).toBe(undefined);
    expect(spongebobEdition.discContents?.length).toBe(14);
    expect(spongebobEdition.discContents).toStrictEqual(
      expect.arrayContaining([{ format: 'DVD', region: ['1'] }]),
    );
  });

  it('should handle disc edge cases', async () => {
    const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation();

    const bonusDiscEdition = await fetchFixture(zootopia.upc, {
      ...zootopia,
      discs: '4K Ultra HD | Blu-ray Disc | Three-disc set (1 BD-66, 2 BD-50)',
    });
    expect(bonusDiscEdition.discContents).toStrictEqual([
      { format: '4K UHD', region: 'Region free' },
      { format: 'Blu-ray', region: ['A', 'B'] },
      { format: 'Blu-ray', region: ['A', 'B'] },
    ]);

    const noBreakdownEdition = await fetchFixture(zootopia.upc, {
      ...zootopia,
      discs: '4K Ultra HD | Blu-ray Disc | Two-disc set',
    });
    expect(noBreakdownEdition.discContents).toBeUndefined();
    expect(warn).toHaveBeenCalledWith(
      expect.stringContaining('Unknown disc count'),
    );

    const unknownLabelEdition = await fetchFixture(zootopia.upc, {
      ...zootopia,
      playback: '4K Blu-ray: Region free | 3D Blu-ray: Region A',
    });
    expect(unknownLabelEdition.discContents).toBeUndefined();
    expect(warn).toHaveBeenCalledWith(
      expect.stringContaining('Unknown disc format for UPC'),
    );

    const partialCountEdition = await fetchFixture(zootopia.upc, {
      ...zootopia,
      discs: '4K Ultra HD | Blu-ray Disc | Two-disc set (1 BD-66, BD-50)',
    });
    expect(partialCountEdition.discContents).toBeUndefined();

    const capitalisedFreeEdition = await fetchFixture(zootopia.upc, {
      ...zootopia,
      playback: '4K Blu-ray: Region Free | 2K Blu-ray: Region Free',
    });
    expect(capitalisedFreeEdition.discContents).toStrictEqual([
      { format: '4K UHD', region: 'Region free' },
      { format: 'Blu-ray', region: 'Region free' },
    ]);

    const unlabelledBluRayEdition = await fetchFixture(barnyard.upc, {
      ...barnyard,
      discs: 'Blu-ray Disc | Single disc (1 BD-50)',
      playback: 'Region A',
    });
    expect(unlabelledBluRayEdition.discContents).toStrictEqual([
      { format: 'Blu-ray', region: ['A'] },
    ]);
  });

  it('should normalize edition hdr', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.hdr).toStrictEqual(
      expect.arrayContaining(['Dolby Vision', 'HDR10']),
    );
    expect(blackPantherEdition.hdr).toStrictEqual(['HDR10']);
    expect(lokiEdition.hdr).toStrictEqual(
      expect.arrayContaining(['Dolby Vision', 'HDR10']),
    );
    expect(wandaVisionEdition.hdr).toStrictEqual(['HDR10']);
    expect(barnyardEdition.hdr).toStrictEqual([]);
    expect(rickAndMortyEdition.hdr).toStrictEqual([]);
    expect(austinPowersEdition.hdr).toStrictEqual([]);
    expect(spongebobEdition.hdr).toStrictEqual([]);
  });

  it('should normalize edition packaging', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.packaging).toStrictEqual({
      steelbook: true,
      slipcover: undefined,
      memorabilia: undefined,
    });
    expect(blackPantherEdition.packaging).toStrictEqual({
      steelbook: false,
      slipcover: true,
      memorabilia: undefined,
    });
    expect(lokiEdition.packaging).toStrictEqual({
      steelbook: true,
      slipcover: undefined,
      memorabilia: true,
    });
    expect(wandaVisionEdition.packaging).toStrictEqual({
      steelbook: true,
      slipcover: undefined,
      memorabilia: true,
    });
    expect(barnyardEdition.packaging).toStrictEqual({
      steelbook: undefined,
      slipcover: undefined,
      memorabilia: undefined,
    });
    expect(rickAndMortyEdition.packaging).toStrictEqual({
      steelbook: undefined,
      slipcover: undefined,
      memorabilia: undefined,
    });
    expect(austinPowersEdition.packaging).toStrictEqual({
      steelbook: undefined,
      slipcover: undefined,
      memorabilia: undefined,
    });
    expect(spongebobEdition.packaging).toStrictEqual({
      steelbook: undefined,
      slipcover: true,
      memorabilia: undefined,
    });
  });

  it('should handle other packaging responses', async () => {
    const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation();
    const falseSteelbookEdition = await fetchFixture('043396647640', {
      title: 'falseSteelbook',
      steelbook: false,
      packaging: 'Steelbook',
    });
    const falseSlipcoverEdition = await fetchFixture('043396647640', {
      title: 'falseSlipcover',
      slipcover: 'false',
    });
    const slipcoverEdition = await fetchFixture('043396647640', {
      title: 'slipcover',
      slipcover: 'false',
      packaging: 'Slipcover',
    });
    const specialFeaturesEdition = await fetchFixture('043396647640', {
      title: 'specialFeatures',
      special_features: 'Steelbook',
    });
    const originalSlipcoverEdition = await fetchFixture('043396647640', {
      title: 'originalSlipcover',
      slipcover: 'Slipcover in original pressing',
    });

    expect(falseSteelbookEdition.packaging.steelbook).toBe(true);
    expect(falseSlipcoverEdition.packaging.slipcover).toBe(false);
    expect(slipcoverEdition.packaging.slipcover).toBe(true);
    expect(specialFeaturesEdition.packaging.steelbook).toBe(true);
    expect(originalSlipcoverEdition.packaging.slipcover).toBe(true);
    expect(warn).toHaveBeenCalledWith(
      expect.stringContaining('steelbook flag is false'),
    );
    expect(warn).toHaveBeenCalledWith(
      expect.stringContaining('slipcover flag is false'),
    );
  });

  it('should normalize edition editionFlags', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);
    const unknownFlags = {
      limited: undefined,
      collector: undefined,
      special: undefined,
      anniversary: undefined,
      boxset: undefined,
    };
    const falseFlags = {
      limited: false,
      collector: false,
      special: false,
      anniversary: false,
      boxset: false,
    };

    expect(zootopiaEdition.editionFlags).toStrictEqual(unknownFlags);
    expect(blackPantherEdition.editionFlags).toStrictEqual(falseFlags);
    expect(lokiEdition.editionFlags).toStrictEqual(falseFlags);
    expect(wandaVisionEdition.editionFlags).toStrictEqual({
      limited: false,
      collector: true,
      special: false,
      anniversary: false,
      boxset: false,
    });
    expect(barnyardEdition.editionFlags).toStrictEqual(unknownFlags);
    expect(rickAndMortyEdition.editionFlags).toStrictEqual(unknownFlags);
    expect(austinPowersEdition.editionFlags).toStrictEqual(unknownFlags);
    expect(spongebobEdition.editionFlags).toStrictEqual(unknownFlags);
  });

  it('should normalize edition masterResolution', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.masterResolution).toBe('upscaled');
    expect(blackPantherEdition.masterResolution).toBe('native');
    expect(lokiEdition.masterResolution).toBe('native');
    expect(wandaVisionEdition.masterResolution).toBe('native');
    expect(barnyardEdition.masterResolution).toBe(undefined);
    expect(rickAndMortyEdition.masterResolution).toBe(undefined);
    expect(austinPowersEdition.masterResolution).toBe(undefined);
    expect(spongebobEdition.masterResolution).toBe(undefined);
  });

  it('should normalize edition releaseDate', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);
    const junkDateEdition = await fetchFixture('043396647640', {
      title: 'junk',
      releaseDate: '2026/03/03 junk',
    });

    expect(zootopiaEdition.releaseDate).toBe('2026-03-03');
    expect(blackPantherEdition.releaseDate).toBe('2023-02-07');
    expect(lokiEdition.releaseDate).toBe('2024-12-03');
    expect(wandaVisionEdition.releaseDate).toBe('2023-11-28');
    expect(barnyardEdition.releaseDate).toBe(undefined);
    expect(rickAndMortyEdition.releaseDate).toBe(undefined);
    expect(austinPowersEdition.releaseDate).toBe(undefined);
    expect(spongebobEdition.releaseDate).toBe(undefined);
    expect(junkDateEdition.releaseDate).toBe(undefined);
  });

  it('should normalize edition distributor', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.distributor).toBe('Disney / Buena Vista');
    expect(blackPantherEdition.distributor).toBe('Disney / Buena Vista');
    expect(lokiEdition.distributor).toBe('Disney / Buena Vista');
    expect(wandaVisionEdition.distributor).toBe('Disney / Buena Vista');
    expect(barnyardEdition.distributor).toBe('Paramount');
    expect(rickAndMortyEdition.distributor).toBe('Cartoon Network');
    expect(austinPowersEdition.distributor).toBe('Warner Bros.');
    expect(spongebobEdition.distributor).toBe(undefined);
  });

  it('should normalize edition country', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.country).toBe('United States');
    expect(blackPantherEdition.country).toBe('United States');
    expect(lokiEdition.country).toBe('United States');
    expect(wandaVisionEdition.country).toBe('United States');
    expect(barnyardEdition.country).toBe(undefined);
    expect(rickAndMortyEdition.country).toBe(undefined);
    expect(austinPowersEdition.country).toBe(undefined);
    expect(spongebobEdition.country).toBe('United States');
  });

  it('should normalize edition coverImageURL', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.coverImageURL).toBe(
      'https://imagestorage.org/043396647640.jpg',
    );
    expect(blackPantherEdition.coverImageURL).toBe(
      'https://imagestorage.org/786936893601.jpg',
    );
    expect(lokiEdition.coverImageURL).toBe(
      'https://imagestorage.org/043396640559.jpg',
    );
    expect(wandaVisionEdition.coverImageURL).toBe(
      'https://imagestorage.org/786936900378.jpg',
    );
    expect(barnyardEdition.coverImageURL).toBe(
      'https://imagestorage.org/191329211991.jpg',
    );
    expect(rickAndMortyEdition.coverImageURL).toBe(
      'https://imagestorage.org/883929374342.jpg',
    );
    expect(austinPowersEdition.coverImageURL).toBe(
      'https://imagestorage.org/794043602825.jpg',
    );
    expect(spongebobEdition.coverImageURL).toBe(
      'https://imagestorage.org/032429342829.jpg',
    );
  });

  it('should normalize edition runtime', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.runtime).toBe(108);
    expect(blackPantherEdition.runtime).toBe(161);
    expect(lokiEdition.runtime).toBe(297);
    expect(wandaVisionEdition.runtime).toBe(321);
    expect(barnyardEdition.runtime).toBe(90);
    expect(rickAndMortyEdition.runtime).toBe(23);
    expect(austinPowersEdition.runtime).toBe(94);
    expect(spongebobEdition.runtime).toBe(undefined);
  });

  it('should normalize edition audio', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.audio).toBe(
      'English: Dolby Atmos English: Dolby TrueHD 7.1 (48kHz, 24-bit) French: Dolby Digital Plus 7.1 Spanish: Dolby Digital Plus 7.1 Japanese: Dolby Digital Plus 7.1 | Audio descriptive',
    );
    expect(blackPantherEdition.audio).toBe(
      'English: Dolby Atmos English: Dolby TrueHD 7.1 (48kHz, 24-bit) Spanish: Dolby Digital Plus 7.1 | Audio descriptive',
    );
    expect(lokiEdition.audio).toBe(
      'English: Dolby Atmos English: Dolby TrueHD 7.1 (48kHz, 24-bit) French: Dolby Digital 5.1 (640 kbps) Spanish: Dolby Digital 5.1 (640 kbps) | Audio descriptive',
    );
    expect(wandaVisionEdition.audio).toBe(
      'English: Dolby Atmos English: Dolby TrueHD 7.1 (48kHz, 24-bit) French (Canada): Dolby Digital 5.1 Spanish: Dolby Digital 5.1 (640 kbps) | Audio descriptive',
    );
    expect(barnyardEdition.audio).toBe(undefined);
    expect(rickAndMortyEdition.audio).toBe(undefined);
    expect(austinPowersEdition.audio).toBe(undefined);
    expect(spongebobEdition.audio).toBe(
      'English: Dolby Digital 2.0 (192 kbps)',
    );
  });

  it('should normalize edition subtitles', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.subtitles).toStrictEqual([
      'English SDH',
      'French',
      'Japanese',
      'Spanish',
    ]);
    expect(blackPantherEdition.subtitles).toStrictEqual([
      'English SDH',
      'Spanish',
    ]);
    expect(lokiEdition.subtitles).toStrictEqual([
      'English SDH',
      'French',
      'Spanish',
    ]);
    expect(wandaVisionEdition.subtitles).toStrictEqual([
      'English SDH',
      'French',
      'Spanish',
    ]);
    expect(barnyardEdition.subtitles).toBe(undefined);
    expect(rickAndMortyEdition.subtitles).toBe(undefined);
    expect(austinPowersEdition.subtitles).toBe(undefined);
    expect(spongebobEdition.subtitles).toStrictEqual(['English SDH']);
  });

  it('should normalize edition hasDigital', async () => {
    const zootopiaEdition = await fetchFixture(zootopia.upc, zootopia);
    const blackPantherEdition = await fetchFixture(
      blackPanther.upc,
      blackPanther,
    );
    const lokiEdition = await fetchFixture(loki.upc, loki);
    const wandaVisionEdition = await fetchFixture(wandavision.upc, wandavision);
    const barnyardEdition = await fetchFixture(barnyard.upc, barnyard);
    const rickAndMortyEdition = await fetchFixture(
      rickAndMorty.upc,
      rickAndMorty,
    );
    const austinPowersEdition = await fetchFixture(
      austinPowers.upc,
      austinPowers,
    );
    const spongebobEdition = await fetchFixture(spongebob.upc, spongebob);

    expect(zootopiaEdition.hasDigital).toBe(true);
    expect(blackPantherEdition.hasDigital).toBe(true);
    expect(lokiEdition.hasDigital).toBe(false);
    expect(wandaVisionEdition.hasDigital).toBe(false);
    expect(barnyardEdition.hasDigital).toBe(undefined);
    expect(rickAndMortyEdition.hasDigital).toBe(undefined);
    expect(austinPowersEdition.hasDigital).toBe(undefined);
    expect(spongebobEdition.hasDigital).toBe(undefined);
  });
});
