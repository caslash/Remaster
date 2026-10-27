import { Test, TestingModule } from '@nestjs/testing';
import { UpcService } from '@/upc/upc.service';
import { ConfigService } from '@nestjs/config';
import {
  BadGatewayException,
  BadRequestException,
  GatewayTimeoutException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import zootopia from './mock/movie4kdv.json';
import { StoreRangeReason } from './utils/upc.utils';

describe('UpcService', () => {
  let service: UpcService;

  const mockConfigServiceGet = jest.fn();
  const mockConfigService = {
    get: mockConfigServiceGet,
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
    const upc = '043396647640';

    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      text: () => Promise.resolve(JSON.stringify(zootopia)),
    });

    const zootopiaEdition = await service.getTitle(upc, undefined);

    expect(zootopiaEdition).toBeTruthy();
    expect(zootopiaEdition.id).not.toBe(zootopia.upc);
    expect(zootopiaEdition.id).not.toBe('');
    expect(zootopiaEdition.id).toBe(zootopia.ean);
  });

  it.todo('should normalize edition barcodes');
  it.todo('should normalize edition asin');
  it.todo('should normalize edition imdbId');
  it.todo('should normalize edition title');
  it.todo('should normalize edition enrichedTitle');
  it.todo('should normalize edition kind');
  it.todo('should normalize edition year');
  it.todo('should normalize edition format');
  it.todo('should normalize edition discContents');
  it.todo('should normalize edition hdr');
  it.todo('should normalize edition packaging');
  it.todo('should normalize edition editionFlags');
  it.todo('should normalize edition masterResolution');
  it.todo('should normalize edition releaseDate');
  it.todo('should normalize edition distributor');
  it.todo('should normalize edition country');
  it.todo('should normalize edition coverImageURL');
  it.todo('should normalize edition runtime');
  it.todo('should normalize edition audio');
  it.todo('should normalize edition subtitles');
  it.todo('should normalize edition hasDigital');
});
