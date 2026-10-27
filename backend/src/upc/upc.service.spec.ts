import { Test, TestingModule } from '@nestjs/testing';
import { UpcService } from '@/upc/upc.service';
import { ConfigService } from '@nestjs/config';
import {
  BadGatewayException,
  BadRequestException,
  GatewayTimeoutException,
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

    expect(global.fetch).not.toHaveBeenCalled();
    await expect(service.getTitle(upc, undefined)).rejects.toThrow(
      BadRequestException,
    );
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

  it('should throw error when UPCMDB responds with error', async () => {
    const upc = '043396647640';

    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: false,
      status: 403,
      statusText: 'Generic Text',
    });

    await expect(service.getTitle(upc, undefined)).rejects.toThrow(
      new Error('UPCMDB responded with status 403 - Generic Text'),
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

  it('should normalize edition id', async () => {
    const upc = '043396647640';

    global.fetch = jest
      .fn()
      .mockResolvedValueOnce({ ok: true, status: 200, json: () => zootopia });

    const zootopiaEdition = await service.getTitle(upc, undefined);

    expect(zootopiaEdition).toBeTruthy();
    expect(zootopiaEdition.id).not.toBe(zootopia.upc);
    expect(zootopiaEdition.id).not.toBe('');
    expect(zootopiaEdition.id).toBe(zootopia.ean);
  });

  it('should normalize edition barcodes', async () => {});
  it('should normalize edition asin', async () => {});
  it('should normalize edition imdbId', async () => {});
  it('should normalize edition title', async () => {});
  it('should normalize edition enrichedTitle', async () => {});
  it('should normalize edition kind', async () => {});
  it('should normalize edition year', async () => {});
  it('should normalize edition format', async () => {});
  it('should normalize edition discContents', async () => {});
  it('should normalize edition hdr', async () => {});
  it('should normalize edition packaging', async () => {});
  it('should normalize edition editionFlags', async () => {});
  it('should normalize edition masterResolution', async () => {});
  it('should normalize edition releaseDate', async () => {});
  it('should normalize edition distributor', async () => {});
  it('should normalize edition country', async () => {});
  it('should normalize edition coverImageURL', async () => {});
  it('should normalize edition runtime', async () => {});
  it('should normalize edition audio', async () => {});
  it('should normalize edition subtitles', async () => {});
  it('should normalize edition hasDigital', async () => {});
});
