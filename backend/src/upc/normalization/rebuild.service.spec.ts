import { NormalizationService } from '@/upc/normalization/normalization.service';
import { RebuildService } from '@/upc/normalization/rebuild.service';
import { EditionStore } from '@/upc/storage/upc.storage.store';
import { Edition } from '@/upc/types/edition';
import { NORMALIZER_VERSION } from '@/upc/utils/upc.utils';
import { Logger } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import zootopia from '../mock/movie4kdv.json';
import barnyard from '../mock/moviebr.json';
import loki from '../mock/tv4kdv.json';

// RMSTR-70: rebuild stored editions from their raw UPCMDB JSON, with no
// upstream call. Decisions (Jira RMSTR-70, 2026-11-11):
// - A record that fails to normalize is skipped, logged with its ID and left
//   at its old version; the run carries on.
// - A changed imdbId is logged and listed, and the edition is still updated;
//   its Title link is the store's job to keep (see the store spec).
// - A store error stops the run.
// - An update that matches no row (the race guard) is "changed meanwhile".

const OLD_VERSION = 1;
const NEW_VERSION = NORMALIZER_VERSION + 1;

// A stored edition as findOutOfDateEditions returns it. Postgres gives null,
// not undefined, for an empty column, so a missing imdbId is stored as null.
const stored = (
  raw: Record<string, unknown>,
  overrides: Partial<Record<keyof Edition, unknown>> = {},
): Edition =>
  ({
    id: raw.ean as string,
    imdbId: typeof raw.imdbID === 'string' ? raw.imdbID : null,
    upcTitle: raw.title,
    raw,
    normalizerVersion: OLD_VERSION,
    ...overrides,
  }) as unknown as Edition;

const mockEditionStore = {
  findEditionByGTIN: jest.fn(),
  saveEdition: jest.fn(),
  saveTitle: jest.fn(),
  recordUnresolvedGTIN: jest.fn(),
  findFullEditionByGTIN: jest.fn(),
  findOutOfDateEditions: jest.fn(),
  updateEditionNormalizedFields: jest.fn(),
};

describe('RebuildService', () => {
  let service: RebuildService;
  let normalizer: NormalizationService;
  let warn: jest.SpyInstance;
  let fetchSpy: jest.SpyInstance;

  // Warnings that name an edition. The normalizer's own record-level
  // warnings (unknown format and so on) are left out.
  const warningsAbout = (id: string): string[] =>
    warn.mock.calls
      .map(([message]) => String(message))
      .filter((message) => message.includes(id));

  const updatedIds = (): string[] =>
    mockEditionStore.updateEditionNormalizedFields.mock.calls.map(
      ([id]) => id as string,
    );

  beforeEach(async () => {
    // Only the store and the normalizer: if the rebuild needed TMDBService,
    // ConfigService or UpcService, this module wouldn't compile.
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RebuildService,
        NormalizationService,
        { provide: EditionStore, useValue: mockEditionStore },
      ],
    }).compile();

    service = module.get(RebuildService);
    normalizer = module.get(NormalizationService);

    warn = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => undefined);
    fetchSpy = jest
      .spyOn(global, 'fetch')
      .mockRejectedValue(new Error('the rebuild must not call fetch'));
    mockEditionStore.findOutOfDateEditions.mockResolvedValue([]);
    mockEditionStore.updateEditionNormalizedFields.mockResolvedValue(true);
  });

  afterEach(() => {
    jest.resetAllMocks();
    jest.restoreAllMocks();
  });

  describe('rebuilding from raw JSON', () => {
    it('should rebuild every out-of-date edition from its stored raw JSON', async () => {
      const editions = [stored(zootopia), stored(barnyard), stored(loki)];
      mockEditionStore.findOutOfDateEditions.mockResolvedValue(editions);

      await service.rebuildEditions(NEW_VERSION);

      expect(
        mockEditionStore.updateEditionNormalizedFields,
      ).toHaveBeenCalledTimes(3);
      for (const [index, edition] of editions.entries()) {
        const [id, fields, version] = mockEditionStore
          .updateEditionNormalizedFields.mock.calls[index] as [
          string,
          unknown,
          number,
        ];
        expect(id).toBe(edition.id);
        expect(version).toBe(NEW_VERSION);
        expect(fields).toStrictEqual(
          normalizer.normalizeUpcResponse(
            edition.id,
            edition.raw as Record<string, unknown>,
          ),
        );
      }
    });

    it('should normalize with the stored edition ID, not the raw record’s own codes', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia, { id: '0000000000000' }),
      ]);

      await service.rebuildEditions(NEW_VERSION);

      const [[id, fields]] = mockEditionStore.updateEditionNormalizedFields.mock
        .calls as [[string, { id: string }]];
      expect(id).toBe('0000000000000');
      expect(fields.id).toBe('0000000000000');
    });

    it('should make no UPCMDB or TMDB call', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
        stored(loki),
      ]);

      await service.rebuildEditions(NEW_VERSION);

      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('should never touch the unresolved list or save titles', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
        stored({ ...barnyard, title: 'null' }),
      ]);

      await service.rebuildEditions(NEW_VERSION);

      expect(mockEditionStore.recordUnresolvedGTIN).not.toHaveBeenCalled();
      expect(mockEditionStore.saveEdition).not.toHaveBeenCalled();
      expect(mockEditionStore.saveTitle).not.toHaveBeenCalled();
    });
  });

  describe('versions', () => {
    it('should load and stamp the version it is given', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
      ]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(mockEditionStore.findOutOfDateEditions).toHaveBeenCalledWith(
        NEW_VERSION,
      );
      const [[, , version]] = mockEditionStore.updateEditionNormalizedFields
        .mock.calls as [[string, unknown, number]];
      expect(version).toBe(NEW_VERSION);
      expect(summary.targetVersion).toBe(NEW_VERSION);
    });

    it('should default to the current normalizer version', async () => {
      const summary = await service.rebuildEditions();

      expect(mockEditionStore.findOutOfDateEditions).toHaveBeenCalledWith(
        NORMALIZER_VERSION,
      );
      expect(summary.targetVersion).toBe(NORMALIZER_VERSION);
    });

    // Up-to-date editions are filtered out by the store's query, so the
    // rebuild only ever sees what it's handed.
    it('should do nothing when no edition is out of date', async () => {
      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(
        mockEditionStore.updateEditionNormalizedFields,
      ).not.toHaveBeenCalled();
      expect(summary).toStrictEqual({
        targetVersion: NEW_VERSION,
        foundEditions: 0,
        rebuilt: 0,
        changedMeanwhile: 0,
        failedIds: [],
        mismatchedIds: [],
      });
    });
  });

  describe('records that fail to normalize', () => {
    const noTitle = stored({ ...barnyard, title: 'null' });
    const notARecord = stored(loki, { raw: ['not', 'a', 'record'] });

    it.each([
      ['has no usable title', noTitle],
      ['has raw JSON that is not an object', notARecord],
      ['has no raw JSON', stored(loki, { raw: null })],
    ])(
      'should skip, list and not update a record that %s',
      async (_name, edition) => {
        mockEditionStore.findOutOfDateEditions.mockResolvedValue([edition]);

        const summary = await service.rebuildEditions(NEW_VERSION);

        expect(
          mockEditionStore.updateEditionNormalizedFields,
        ).not.toHaveBeenCalled();
        expect(summary.failedIds).toEqual([edition.id]);
        expect(summary.rebuilt).toBe(0);
      },
    );

    it('should carry on with the next records after a failure', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
        noTitle,
        notARecord,
        stored(barnyard),
      ]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(updatedIds()).toEqual([zootopia.ean, barnyard.ean]);
      expect(summary.failedIds).toEqual([noTitle.id, notARecord.id]);
      expect(summary.rebuilt).toBe(2);
    });

    it('should log a failure with the edition ID and the reason', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored({ ...barnyard, title: 'null', ean: '0191329211991' }),
      ]);

      await service.rebuildEditions(NEW_VERSION);

      const [message] = warningsAbout('0191329211991');
      expect(message).toBeDefined();
      expect(message).toMatch(/could not be found/);
    });

    it('should treat any error from the normalizer as a failed record, and name the edition', async () => {
      jest
        .spyOn(normalizer, 'normalizeUpcResponse')
        .mockImplementationOnce(() => {
          throw new TypeError('mapping bug');
        });
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
        stored(barnyard),
      ]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.failedIds).toEqual([zootopia.ean]);
      expect(updatedIds()).toEqual([barnyard.ean]);
      expect(warningsAbout(zootopia.ean).join('\n')).toMatch(/mapping bug/);
    });

    it('should name the edition and the reason when the normalizer throws something that is not an Error', async () => {
      jest
        .spyOn(normalizer, 'normalizeUpcResponse')
        .mockImplementationOnce(() => {
          // JavaScript can throw any value; this checks the rebuild copes.
          // eslint-disable-next-line @typescript-eslint/only-throw-error
          throw 'not an error object';
        });
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
      ]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.failedIds).toEqual([zootopia.ean]);
      expect(warningsAbout(zootopia.ean).join('\n')).toMatch(
        /not an error object/,
      );
    });
  });

  describe('imdbId changes', () => {
    it('should list an edition whose imdbId changed, and still update it', async () => {
      const edition = stored(zootopia, { imdbId: 'tt0000001' });
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([edition]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.mismatchedIds).toEqual([edition.id]);
      expect(updatedIds()).toEqual([edition.id]);
      expect(summary.rebuilt).toBe(1);
    });

    it('should log the old and new imdbId', async () => {
      const edition = stored(zootopia, { imdbId: 'tt0000001' });
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([edition]);

      await service.rebuildEditions(NEW_VERSION);

      const logged = warningsAbout(edition.id).join('\n');
      expect(logged).toContain('tt0000001');
      expect(logged).toContain(zootopia.imdbID);
    });

    it('should list an edition that gains an imdbId', async () => {
      const edition = stored(zootopia, { imdbId: null });
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([edition]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.mismatchedIds).toEqual([edition.id]);
    });

    it('should list an edition that loses its imdbId', async () => {
      const edition = stored(loki, { imdbId: 'tt0000001' });
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([edition]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.mismatchedIds).toEqual([edition.id]);
    });

    // Loki S2 has no imdbID: stored as null, normalized as undefined.
    it('should not treat a stored null and a missing imdbId as a change', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([stored(loki)]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.mismatchedIds).toEqual([]);
      expect(warningsAbout(loki.ean)).toEqual([]);
    });

    it('should not list an unchanged imdbId', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
      ]);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.mismatchedIds).toEqual([]);
    });

    // The mismatch list overlaps with rebuilt (Jira RMSTR-70): a record that
    // was changed meanwhile wasn't written, so it has no mismatch to report.
    it('should not list a mismatch for an edition that was changed meanwhile', async () => {
      const edition = stored(zootopia, { imdbId: 'tt0000001' });
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([edition]);
      mockEditionStore.updateEditionNormalizedFields.mockResolvedValue(false);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.changedMeanwhile).toBe(1);
      expect(summary.mismatchedIds).toEqual([]);
    });
  });

  describe('changed meanwhile', () => {
    it('should count an update that matched no row as changed meanwhile, not rebuilt', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
        stored(barnyard),
      ]);
      mockEditionStore.updateEditionNormalizedFields
        .mockResolvedValueOnce(false)
        .mockResolvedValueOnce(true);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.changedMeanwhile).toBe(1);
      expect(summary.rebuilt).toBe(1);
    });
  });

  describe('summary', () => {
    it('should account for every edition it found exactly once', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
        stored({ ...barnyard, title: '' }),
        stored(loki),
        stored(barnyard, { raw: 'not json' }),
      ]);
      mockEditionStore.updateEditionNormalizedFields
        .mockResolvedValueOnce(true)
        .mockResolvedValueOnce(false);

      const summary = await service.rebuildEditions(NEW_VERSION);

      expect(summary.foundEditions).toBe(4);
      expect(summary.rebuilt).toBe(1);
      expect(summary.changedMeanwhile).toBe(1);
      expect(summary.failedIds).toHaveLength(2);
      expect(
        summary.rebuilt + summary.changedMeanwhile + summary.failedIds.length,
      ).toBe(summary.foundEditions);
    });
  });

  describe('store errors', () => {
    it('should reject when loading the editions fails', async () => {
      mockEditionStore.findOutOfDateEditions.mockRejectedValue(
        new Error('connection refused'),
      );

      await expect(service.rebuildEditions(NEW_VERSION)).rejects.toThrow(
        'connection refused',
      );
    });

    it('should stop at the first update that fails, and not try the rest', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
        stored(barnyard),
        stored(loki),
      ]);
      mockEditionStore.updateEditionNormalizedFields
        .mockResolvedValueOnce(true)
        .mockRejectedValueOnce(new Error('connection lost'));

      await expect(service.rebuildEditions(NEW_VERSION)).rejects.toThrow(
        'connection lost',
      );
      expect(updatedIds()).toEqual([zootopia.ean, barnyard.ean]);
    });

    it('should not record a store failure as a failed record', async () => {
      mockEditionStore.findOutOfDateEditions.mockResolvedValue([
        stored(zootopia),
      ]);
      mockEditionStore.updateEditionNormalizedFields.mockRejectedValue(
        new Error('connection lost'),
      );

      await expect(service.rebuildEditions(NEW_VERSION)).rejects.toThrow();
      expect(warningsAbout(zootopia.ean)).toEqual([]);
    });
  });
});
