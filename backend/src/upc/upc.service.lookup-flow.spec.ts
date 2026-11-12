// RMSTR-68: the cache-first lookup flow in GET /upc.
//
// These specs pin the behaviour in the ticket, not the shape of the EditionStore
// contract, which is still being designed (how a save carries its Title, and
// whether Title + Edition go through one transactional method). The store mock
// therefore creates a jest.fn for any method the service calls, and the
// assertions look at what was written rather than which method wrote it:
//
// - "nothing saved" means no store method other than a find* was called.
// - "saved with raw JSON" means some write received the raw UPCMDB body.
// - "linked to its Title" means a single write received both the edition and
//   the TMDB Title, so two unrelated saves don't count as a link.
//
// Real concurrency (two misses racing to one row) needs a live Postgres and is
// not covered here; see the SQL-level upsert specs in
// storage/upc.storage.typeorm-store.spec.ts.
//
// RMSTR-69 (response contract) assertions read the response the way a client
// does, through a JSON round trip (`body`), so they don't depend on how the
// response type is declared. Decided 2026-11-08:
//
// - `title` is the TMDB work: tmdbId, kind, name, year, imdbId, posterURL
//   (w500). It is left out of the JSON when there's no match.
// - `unmatchedTitle` is true whenever `title` is absent.
// - A TMDB failure on a miss returns the UPCMDB-only edition, unmatched and
//   unsaved, so the next scan retries both upstreams.
// - Cache hits never call TMDB, even for an unmatched edition with an IMDb ID
//   (re-matching is left to the enrichment worker). The store builds the
//   cache-hit response; the service builds the cache-miss one.
// - A UPCMDB record with no title is a 404 and is recorded as unresolved.

import { NormalizationService } from '@/upc/normalization/normalization.service';
import { EditionStore } from '@/upc/storage/upc.storage.store';
import { TMDBService } from '@/upc/tmdb.service';
import { PosterSize } from '@/upc/types/poster-size';
import { Title } from '@/upc/types/title';
import { UpcService } from '@/upc/upc.service';
import {
  BadGatewayException,
  GatewayTimeoutException,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { isDeepStrictEqual } from 'node:util';
import databaseZootopia from './mock/database-zootopia.json';
import zootopia from './mock/movie4kdv.json';
import loki from './mock/tv4kdv.json';
import wandavision from './mock/tv4khdr.json';
import spongebob from './mock/tvdvd.json';

const ZOOTOPIA_GTIN = '0043396647640';
const ZOOTOPIA_POSTER_URL = 'https://image.tmdb.org/t/p/w500/poster.jpg';

const zootopiaTitle = {
  tmdbId: '1084242',
  kind: 'movie',
  name: 'Zootopia 2',
  year: 2025,
  imdbId: 'tt26443597',
  posterPath: '/poster.jpg',
  raw: { movie_results: [{ id: 1084242 }], tv_results: [] },
  editions: [],
} as unknown as Title;

// The nested `title` a client receives for Zootopia.
const zootopiaResponseTitle = {
  tmdbId: '1084242',
  kind: 'movie',
  name: 'Zootopia 2',
  year: 2025,
  imdbId: 'tt26443597',
  posterURL: ZOOTOPIA_POSTER_URL,
};

// The same, for a Title with no poster_path: posterURL is left out.
const zootopiaResponseTitleWithoutPoster = {
  tmdbId: '1084242',
  kind: 'movie',
  name: 'Zootopia 2',
  year: 2025,
  imdbId: 'tt26443597',
};

// What findEditionByGTIN returns on a cache hit: the store maps the stored
// Title to the response shape itself (see upc.storage.typeorm-store.spec.ts),
// so the service passes it through.
const storedZootopia = {
  ...databaseZootopia,
  title: zootopiaResponseTitle,
  unmatchedTitle: false,
};
const storedUnmatchedZootopia = {
  ...databaseZootopia,
  unmatchedTitle: true,
};

// What a client receives over HTTP: undefined properties dropped.
const body = (edition: unknown): Record<string, unknown> =>
  JSON.parse(JSON.stringify(edition)) as Record<string, unknown>;

// Names a Nest container, Jest or `await` may probe on a provider object. The
// proxy must not invent a jest.fn for these, or e.g. `then` would make the
// store look like a promise.
const isProbe = (prop: string) =>
  prop === 'then' ||
  prop === 'constructor' ||
  prop === 'toJSON' ||
  prop === 'asymmetricMatch' ||
  prop.startsWith('on') ||
  prop.startsWith('before') ||
  prop.startsWith('$$');

type AutoMockStore = Record<string, jest.Mock>;

const createAutoMockStore = (): {
  store: AutoMockStore;
  calls: Record<string, jest.Mock>;
} => {
  const calls: Record<string, jest.Mock> = {};
  const store = new Proxy(calls, {
    get(target, prop) {
      if (typeof prop !== 'string' || isProbe(prop)) return undefined;
      if (!(prop in target)) target[prop] = jest.fn();
      return target[prop];
    },
  });
  return { store, calls };
};

const contains = (
  value: unknown,
  predicate: (candidate: unknown) => boolean,
  seen = new Set<unknown>(),
): boolean => {
  if (predicate(value)) return true;
  if (value === null || typeof value !== 'object' || seen.has(value))
    return false;
  seen.add(value);
  return Object.values(value).some((child) => contains(child, predicate, seen));
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object';

const isTitleRef = (title: Title) => (candidate: unknown) =>
  isRecord(candidate) &&
  candidate.tmdbId === title.tmdbId &&
  candidate.kind === title.kind;

const isEditionWithId = (id: string) => (candidate: unknown) =>
  isRecord(candidate) && candidate.id === id && 'barcodes' in candidate;

const isDeepEqualTo = (expected: unknown) => (candidate: unknown) =>
  isDeepStrictEqual(candidate, expected);

describe('UpcService lookup flow (RMSTR-68)', () => {
  let service: UpcService;
  let calls: Record<string, jest.Mock>;

  const mockTMDBService = { getTitle: jest.fn(), getPosterURL: jest.fn() };

  // A plain function, not jest.fn, so resetAllMocks doesn't wipe it.
  const mockConfigService = {
    getOrThrow: (key: string) => {
      const env: Record<string, string> = {
        UPCMDB_LOOKUP_URL: 'https://test.com/',
        UPCMDB_API_KEY: 'test-key',
      };
      if (!(key in env)) throw new Error(`Missing config key: ${key}`);
      return env[key];
    },
  };

  // Every store call that isn't a read, as [method, args].
  const writes = (): [string, unknown[]][] =>
    Object.entries(calls)
      .filter(([name]) => !name.startsWith('find'))
      .flatMap(([name, fn]) =>
        fn.mock.calls.map((args: unknown[]): [string, unknown[]] => [
          name,
          args,
        ]),
      );

  const mockUPCMDB = (fixture: Record<string, unknown>) => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: () => Promise.resolve(JSON.stringify(fixture)),
    });
  };

  const mockUPCMDBStatus = (status: number) => {
    global.fetch = jest
      .fn()
      .mockResolvedValue({ ok: false, status, statusText: 'Error' });
  };

  beforeEach(async () => {
    const auto = createAutoMockStore();
    calls = auto.calls;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UpcService,
        NormalizationService,
        { provide: TMDBService, useValue: mockTMDBService },
        { provide: ConfigService, useValue: mockConfigService },
        { provide: EditionStore, useValue: auto.store },
      ],
    }).compile();

    service = module.get<UpcService>(UpcService);
    // Reading the proxy creates the mock; a miss is the default.
    auto.store.findEditionByGTIN.mockResolvedValue(null);
    // The real URL builder (it doesn't touch `this`), set here because
    // resetAllMocks wipes implementations.
    mockTMDBService.getPosterURL.mockImplementation(
      (path: string, size: PosterSize) =>
        TMDBService.prototype.getPosterURL.call(undefined, path, size),
    );
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  describe('cache hit', () => {
    it.each([
      ['UPC-A', zootopia.upc],
      ['EAN-13', zootopia.ean],
    ] as const)(
      'should serve a %s scan from the database without calling UPCMDB or TMDB',
      async (shape, code) => {
        calls.findEditionByGTIN.mockResolvedValue(storedZootopia);
        global.fetch = jest.fn();

        const edition = await service.getEdition(code, shape);

        expect(calls.findEditionByGTIN).toHaveBeenCalledWith(ZOOTOPIA_GTIN);
        expect(body(edition)).toStrictEqual(storedZootopia);
        expect(global.fetch).not.toHaveBeenCalled();
        expect(mockTMDBService.getTitle).not.toHaveBeenCalled();
        expect(writes()).toEqual([]);
      },
    );

    it('should look up UPC-A and EAN-13 scans of the same disc by the same GTIN', async () => {
      calls.findEditionByGTIN.mockResolvedValue(storedZootopia);
      global.fetch = jest.fn();

      await service.getEdition(zootopia.upc, 'UPC-A');
      await service.getEdition(zootopia.ean, 'EAN-13');

      expect(calls.findEditionByGTIN.mock.calls).toEqual([
        [ZOOTOPIA_GTIN],
        [ZOOTOPIA_GTIN],
      ]);
    });
  });

  describe('cache miss', () => {
    it('should send UPCMDB the scanned form, not the canonical GTIN', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

      await service.getEdition(zootopia.upc, 'UPC-A');

      expect(global.fetch).toHaveBeenCalledWith(
        `https://test.com/${zootopia.upc}`,
        expect.anything(),
      );
    });

    it('should look up the TMDB title by IMDb ID with the movie kind hint', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

      await service.getEdition(zootopia.upc, undefined);

      expect(mockTMDBService.getTitle).toHaveBeenCalledTimes(1);
      expect(mockTMDBService.getTitle).toHaveBeenCalledWith(
        'tt26443597',
        'movie',
      );
    });

    it('should look up the TMDB title by IMDb ID with the tv kind hint', async () => {
      mockUPCMDB(wandavision);
      mockTMDBService.getTitle.mockResolvedValue(undefined);

      await service.getEdition(wandavision.upc, undefined);

      expect(mockTMDBService.getTitle).toHaveBeenCalledWith('tt9140560', 'tv');
    });

    it('should save the edition with the raw UPCMDB body and return it', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

      const edition = await service.getEdition(zootopia.upc, undefined);

      expect(edition.id).toBe(ZOOTOPIA_GTIN);
      expect(edition).not.toHaveProperty('raw');
      const rawWrites = writes().filter(([, args]) =>
        contains(args, isDeepEqualTo(zootopia)),
      );
      expect(rawWrites).toHaveLength(1);
      expect(contains(rawWrites[0][1], isEditionWithId(ZOOTOPIA_GTIN))).toBe(
        true,
      );
    });

    // Only proves the full Title (with raw) reaches the store. Whether the store
    // then writes a titles row is covered in upc.storage.typeorm-store.spec.ts.
    it('should hand the full TMDB title, with its raw response, to the store', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

      await service.getEdition(zootopia.upc, undefined);

      const titleWrites = writes().filter(([, args]) =>
        contains(
          args,
          (candidate) =>
            isTitleRef(zootopiaTitle)(candidate) &&
            isRecord(candidate) &&
            candidate.name === zootopiaTitle.name &&
            isDeepStrictEqual(candidate.raw, zootopiaTitle.raw),
        ),
      );
      expect(titleWrites.length).toBeGreaterThan(0);
    });

    it('should link the edition to its title in a single write', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

      await service.getEdition(zootopia.upc, undefined);

      const linked = writes().some(
        ([, args]) =>
          contains(args, isEditionWithId(ZOOTOPIA_GTIN)) &&
          contains(args, isTitleRef(zootopiaTitle)),
      );
      expect(linked).toBe(true);
    });

    it('should skip TMDB and still save when the record has no IMDb ID', async () => {
      mockUPCMDB(loki);

      const edition = await service.getEdition(loki.upc, undefined);

      expect(mockTMDBService.getTitle).not.toHaveBeenCalled();
      expect(edition.id).toBe(loki.ean);
      expect(
        writes().some(([, args]) => contains(args, isDeepEqualTo(loki))),
      ).toBe(true);
    });

    it('should save the edition without a title when TMDB has no match', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle.mockResolvedValue(undefined);

      const edition = await service.getEdition(zootopia.upc, undefined);

      expect(edition.id).toBe(ZOOTOPIA_GTIN);
      expect(
        writes().some(([, args]) => contains(args, isDeepEqualTo(zootopia))),
      ).toBe(true);
      expect(
        writes().some(([, args]) =>
          contains(
            args,
            (candidate) => isRecord(candidate) && 'tmdbId' in candidate,
          ),
        ),
      ).toBe(false);
    });

    // RMSTR-69, decided 2026-11-08: a TMDB failure isn't a "no match". The
    // collector still gets the UPCMDB edition, but nothing is saved, or the
    // cached edition would stay unmatched after TMDB recovers.
    it.each([
      ['BadGateway', new BadGatewayException('TMDB returned an error')],
      ['GatewayTimeout', new GatewayTimeoutException('TMDB request timed out')],
    ])(
      'should return the edition unmatched and save nothing when TMDB fails with %s',
      async (_name, tmdbError) => {
        mockUPCMDB(zootopia);
        mockTMDBService.getTitle.mockRejectedValue(tmdbError);

        const edition = await service.getEdition(zootopia.upc, undefined);

        const response = body(edition);
        expect(response.id).toBe(ZOOTOPIA_GTIN);
        expect(response.upcTitle).toBe(zootopia.title);
        expect(response.format).toBe('4K UHD');
        expect(response.unmatchedTitle).toBe(true);
        expect(response).not.toHaveProperty('title');
        expect(writes()).toEqual([]);
      },
    );

    it('should call UPCMDB and TMDB again on the next scan after a TMDB failure', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle
        .mockRejectedValueOnce(
          new GatewayTimeoutException('TMDB request timed out'),
        )
        .mockResolvedValueOnce(zootopiaTitle);

      const first = await service.getEdition(zootopia.upc, undefined);
      const second = await service.getEdition(zootopia.upc, undefined);

      expect(global.fetch).toHaveBeenCalledTimes(2);
      expect(mockTMDBService.getTitle).toHaveBeenCalledTimes(2);
      expect(body(first).unmatchedTitle).toBe(true);
      expect(body(second).unmatchedTitle).toBe(false);
      expect(body(second).title).toStrictEqual(zootopiaResponseTitle);
    });

    it('should let two concurrent misses for one UPC both succeed', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

      const [first, second] = await Promise.all([
        service.getEdition(zootopia.upc, 'UPC-A'),
        service.getEdition(zootopia.ean, 'EAN-13'),
      ]);

      expect(first.id).toBe(ZOOTOPIA_GTIN);
      expect(second).toStrictEqual(first);
    });
  });

  describe('UPCMDB failures', () => {
    it.each([
      ['UPC-A', zootopia.upc],
      ['EAN-13', zootopia.ean],
    ] as const)(
      'should record a %s 404 as unresolved under the canonical GTIN and return 404',
      async (shape, code) => {
        mockUPCMDBStatus(404);

        await expect(service.getEdition(code, shape)).rejects.toThrow(
          NotFoundException,
        );

        expect(calls.recordUnresolvedGTIN).toHaveBeenCalledWith(ZOOTOPIA_GTIN);
        expect(writes()).toEqual([['recordUnresolvedGTIN', [ZOOTOPIA_GTIN]]]);
        expect(mockTMDBService.getTitle).not.toHaveBeenCalled();
      },
    );

    it('should retry upstream on the next scan of an unresolved UPC', async () => {
      mockUPCMDBStatus(404);

      await expect(service.getEdition(zootopia.upc, undefined)).rejects.toThrow(
        NotFoundException,
      );
      await expect(service.getEdition(zootopia.upc, undefined)).rejects.toThrow(
        NotFoundException,
      );

      expect(global.fetch).toHaveBeenCalledTimes(2);
    });

    it.each([
      ['500', () => mockUPCMDBStatus(500), BadGatewayException],
      ['403', () => mockUPCMDBStatus(403), BadGatewayException],
      [
        'timeout',
        () => {
          global.fetch = jest
            .fn()
            .mockRejectedValue(new DOMException(undefined, 'TimeoutError'));
        },
        GatewayTimeoutException,
      ],
    ])(
      'should save nothing and skip TMDB when UPCMDB fails with %s',
      async (_name, arrange, expected) => {
        arrange();

        await expect(
          service.getEdition(zootopia.upc, undefined),
        ).rejects.toThrow(expected);
        expect(writes()).toEqual([]);
        expect(mockTMDBService.getTitle).not.toHaveBeenCalled();
      },
    );

    // RMSTR-69, decided 2026-11-08: no retail title means "not found", not a
    // partial match, and the code joins the unresolved (wanted) list.
    it.each([
      ['missing', { ...zootopia, title: undefined }],
      ['the string "null"', { ...zootopia, title: 'null' }],
      ['blank', { ...zootopia, title: '  ' }],
    ])(
      'should return 404, record the GTIN as unresolved and skip TMDB when the UPCMDB title is %s',
      async (_case, fixture) => {
        mockUPCMDB(fixture);

        await expect(
          service.getEdition(zootopia.upc, undefined),
        ).rejects.toThrow(NotFoundException);

        expect(writes()).toEqual([['recordUnresolvedGTIN', [ZOOTOPIA_GTIN]]]);
        expect(mockTMDBService.getTitle).not.toHaveBeenCalled();
      },
    );
  });

  describe('response contract (RMSTR-69)', () => {
    describe('cache miss', () => {
      it('should return the TMDB title with a w500 poster URL when TMDB matches', async () => {
        mockUPCMDB(zootopia);
        mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

        const edition = await service.getEdition(zootopia.upc, undefined);

        const response = body(edition);
        expect(response.title).toStrictEqual(zootopiaResponseTitle);
        expect(response.unmatchedTitle).toBe(false);
        expect(mockTMDBService.getPosterURL).toHaveBeenCalledWith(
          '/poster.jpg',
          PosterSize.W500,
        );
      });

      it('should keep the retail title as upcTitle alongside the TMDB title', async () => {
        mockUPCMDB(zootopia);
        mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

        const edition = await service.getEdition(zootopia.upc, undefined);

        expect(body(edition).upcTitle).toBe(zootopia.title);
      });

      it('should leave posterURL out when the TMDB title has no poster', async () => {
        mockUPCMDB(zootopia);
        mockTMDBService.getTitle.mockResolvedValue({
          ...zootopiaTitle,
          posterPath: undefined,
        });

        const edition = await service.getEdition(zootopia.upc, undefined);

        const response = body(edition);
        expect(response.title).toStrictEqual(
          zootopiaResponseTitleWithoutPoster,
        );
        expect(response.unmatchedTitle).toBe(false);
        expect(mockTMDBService.getPosterURL).not.toHaveBeenCalled();
      });

      it('should not expose posterPath, raw or editions in the nested title', async () => {
        mockUPCMDB(zootopia);
        mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

        const edition = await service.getEdition(zootopia.upc, undefined);

        const title = body(edition).title as Record<string, unknown>;
        expect(title).not.toHaveProperty('posterPath');
        expect(title).not.toHaveProperty('raw');
        expect(title).not.toHaveProperty('editions');
      });

      it.each([
        ['Loki S2', loki, '4K UHD'],
        ['SpongeBob', spongebob, 'DVD'],
      ] as const)(
        'should return %s unmatched, with the UPCMDB title and format, when it has no IMDb ID',
        async (_name, fixture, format) => {
          mockUPCMDB(fixture);

          const edition = await service.getEdition(fixture.upc, undefined);

          const response = body(edition);
          expect(response.upcTitle).toBe(fixture.title);
          expect(response.format).toBe(format);
          expect(response.unmatchedTitle).toBe(true);
          expect(response).not.toHaveProperty('title');
        },
      );

      it('should return the edition unmatched, with the UPCMDB title and format, when TMDB has no match', async () => {
        mockUPCMDB(zootopia);
        mockTMDBService.getTitle.mockResolvedValue(undefined);

        const edition = await service.getEdition(zootopia.upc, undefined);

        const response = body(edition);
        expect(response.upcTitle).toBe(zootopia.title);
        expect(response.format).toBe('4K UHD');
        expect(response.unmatchedTitle).toBe(true);
        expect(response).not.toHaveProperty('title');
      });

      it('should not write the response-only fields to the store', async () => {
        mockUPCMDB(zootopia);
        mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);

        await service.getEdition(zootopia.upc, undefined);

        const hasResponseField = (candidate: unknown) =>
          isRecord(candidate) &&
          ('unmatchedTitle' in candidate || 'posterURL' in candidate);
        expect(
          writes().some(([, args]) => contains(args, hasResponseField)),
        ).toBe(false);
      });
    });

    // The store builds the cache-hit response; the mapping itself is tested
    // in upc.storage.typeorm-store.spec.ts. Here: the service returns it
    // unchanged and calls nothing upstream.
    describe('cache hit', () => {
      it.each([
        ['matched', storedZootopia],
        ['unmatched', storedUnmatchedZootopia],
      ])(
        'should return the stored %s edition unchanged without calling TMDB',
        async (_case, stored) => {
          calls.findEditionByGTIN.mockResolvedValue(stored);
          global.fetch = jest.fn();

          const edition = await service.getEdition(zootopia.upc, undefined);

          expect(body(edition)).toStrictEqual(stored);
          expect(mockTMDBService.getTitle).not.toHaveBeenCalled();
          expect(global.fetch).not.toHaveBeenCalled();
          expect(writes()).toEqual([]);
        },
      );

      // Decided 2026-11-08: re-matching is left to the enrichment worker.
      it('should not retry TMDB for an unmatched edition that has an IMDb ID', async () => {
        calls.findEditionByGTIN.mockResolvedValue(storedUnmatchedZootopia);
        global.fetch = jest.fn();

        await service.getEdition(zootopia.upc, undefined);

        expect(storedUnmatchedZootopia.imdbId).toBeDefined();
        expect(mockTMDBService.getTitle).not.toHaveBeenCalled();
        expect(global.fetch).not.toHaveBeenCalled();
        expect(writes()).toEqual([]);
      });
    });

    // A miss is built by the service and a hit by the store; the client must
    // see the same shape either way.
    it('should return the same title and flag for a disc on its first and repeat scans', async () => {
      mockUPCMDB(zootopia);
      mockTMDBService.getTitle.mockResolvedValue(zootopiaTitle);
      const miss = body(await service.getEdition(zootopia.upc, undefined));

      calls.findEditionByGTIN.mockResolvedValue(storedZootopia);
      const hit = body(await service.getEdition(zootopia.upc, undefined));

      expect(hit.title).toStrictEqual(miss.title);
      expect(hit.unmatchedTitle).toBe(miss.unmatchedTitle);
    });
  });
});
