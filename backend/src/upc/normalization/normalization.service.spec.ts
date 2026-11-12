import { UpcTitleNotFoundException } from '@/upc/normalization/normalization.error';
import { NormalizationService } from '@/upc/normalization/normalization.service';
import { Logger } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { isDeepStrictEqual } from 'node:util';
import zootopia from '../mock/movie4kdv.json';
import blackPanther from '../mock/movie4khdr.json';
import barnyard from '../mock/moviebr.json';
import austinPowers from '../mock/moviedvd.json';
import loki from '../mock/tv4kdv.json';
import wandavision from '../mock/tv4khdr.json';
import rickAndMorty from '../mock/tvbr.json';
import spongebob from '../mock/tvdvd.json';

// RMSTR-70: the normalizer runs on stored raw JSON as well as fresh UPCMDB
// responses, so it has to stand on its own: synchronous, no side effects,
// the same output for the same input, and it never changes the raw record.
// Field-by-field mapping is covered through the lookup in upc.service.spec.ts;
// this file covers what the rebuild relies on.

const fixtures: [string, Record<string, unknown>][] = [
  ['Zootopia 2 (4K, Dolby Vision)', zootopia],
  ['Black Panther: Wakanda Forever (4K, HDR10)', blackPanther],
  ['Barnyard (Blu-ray, thin)', barnyard],
  ['Austin Powers in Goldmember (DVD)', austinPowers],
  ['Loki season 2 (4K, no imdbID or type)', loki],
  ['WandaVision (4K)', wandavision],
  ['Rick and Morty season 1 (Blu-ray)', rickAndMorty],
  ['SpongeBob first 100 episodes (DVD)', spongebob],
];

const gtin = (record: Record<string, unknown>): string => record.ean as string;

describe('NormalizationService', () => {
  let service: NormalizationService;

  beforeEach(async () => {
    // Built through Nest so a constructor dependency Nest can't resolve fails here.
    const module: TestingModule = await Test.createTestingModule({
      providers: [NormalizationService],
    }).compile();

    service = module.get<NormalizationService>(NormalizationService);
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should be resolvable by Nest with no other providers', () => {
    expect(service).toBeDefined();
  });

  describe.each(fixtures)('%s', (_name, record) => {
    it('should normalize synchronously', () => {
      const edition = service.normalizeUpcResponse(gtin(record), record);

      expect(edition).not.toBeInstanceOf(Promise);
      expect(edition.upcTitle).toBe(record.title);
    });

    it('should give the same output for the same input', () => {
      const first = service.normalizeUpcResponse(gtin(record), record);
      const second = service.normalizeUpcResponse(gtin(record), record);

      expect(isDeepStrictEqual(first, second)).toBe(true);
    });

    it('should not change the raw record', () => {
      const before = structuredClone(record);

      service.normalizeUpcResponse(gtin(record), record);

      expect(record).toStrictEqual(before);
    });
  });

  it('should use the code it is given as the edition id, not the record’s own codes', () => {
    const edition = service.normalizeUpcResponse('0000000000000', zootopia);

    expect(edition.id).toBe('0000000000000');
    expect(edition.barcodes).toEqual({
      upc: zootopia.upc,
      ean: zootopia.ean,
    });
  });

  // The strict 'MMM DD, YYYY' parse needs dayjs's customParseFormat plugin.
  // Only the normalizer is loaded in this file, so this fails if the plugin is
  // registered anywhere else.
  it('should parse release dates without the lookup service loaded', () => {
    expect(
      service.normalizeUpcResponse(gtin(zootopia), zootopia).releaseDate,
    ).toBe('2026-03-03');
    expect(service.normalizeUpcResponse(gtin(loki), loki).releaseDate).toBe(
      '2024-12-03',
    );
  });

  describe('when the record has no usable title', () => {
    const noTitle: [string, Record<string, unknown>][] = [
      ['missing', (({ title: _title, ...rest }) => rest)(zootopia)],
      ['the string "null"', { ...zootopia, title: 'null' }],
      ['blank', { ...zootopia, title: '   ' }],
    ];

    it.each(noTitle)(
      'should throw UpcTitleNotFoundException when it is %s',
      (_name, record) => {
        expect(() =>
          service.normalizeUpcResponse(gtin(zootopia), record),
        ).toThrow(UpcTitleNotFoundException);
      },
    );

    it('should name the code it was given in the error', () => {
      expect(() =>
        service.normalizeUpcResponse('0043396647640', {
          ...zootopia,
          title: 'null',
        }),
      ).toThrow('0043396647640');
    });
  });
});
