import { EditionStore } from '@/upc/storage/upc.storage.store';
import { TypeORMEditionStore } from '@/upc/storage/upc.storage.typeorm-store';
import { Edition, EditionResponse } from '@/upc/types/edition';
import { Title } from '@/upc/types/title';
import { UnresolvedUPC } from '@/upc/types/unresolved-upc';
import { NORMALIZER_VERSION } from '@/upc/utils/upc.utils';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource, InsertQueryBuilder, SelectQueryBuilder } from 'typeorm';
import databaseZootopia from '../mock/database-zootopia.json';
import zootopia from '../mock/movie4kdv.json';

const mockEditionRepository = {
  findOne: jest.fn(),
  upsert: jest.fn(),
};

const mockTitleRepository = {
  upsert: jest.fn(),
};

const mockUnresolvedRepository = {
  upsert: jest.fn(),
};

describe('TypeORMEditionStore', () => {
  let store: EditionStore;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        { provide: EditionStore, useClass: TypeORMEditionStore },
        {
          provide: getRepositoryToken(Edition),
          useValue: mockEditionRepository,
        },
        { provide: getRepositoryToken(Title), useValue: mockTitleRepository },
        {
          provide: getRepositoryToken(UnresolvedUPC),
          useValue: mockUnresolvedRepository,
        },
      ],
    }).compile();

    store = module.get<EditionStore>(EditionStore);
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should be provided as an EditionStore', () => {
    expect(store).toBeInstanceOf(TypeORMEditionStore);
  });

  it('should find an edition by GTIN', async () => {
    mockEditionRepository.findOne.mockResolvedValue(databaseZootopia);

    const edition = await store.findEditionByGTIN(databaseZootopia.id);

    expect(mockEditionRepository.findOne).toHaveBeenCalledWith({
      where: { id: databaseZootopia.id },
    });
    expect(edition).toStrictEqual(databaseZootopia);
  });

  it('should return null when the GTIN is not stored', async () => {
    mockEditionRepository.findOne.mockResolvedValue(null);

    await expect(store.findEditionByGTIN('0000000000000')).resolves.toBeNull();
  });

  it('should upsert an edition with its raw response, fetch time and normalizer version', async () => {
    const edition = databaseZootopia as unknown as EditionResponse;
    const before = new Date();

    await store.saveEdition(edition, zootopia);

    expect(mockEditionRepository.upsert).toHaveBeenCalledTimes(1);
    const [[saved, options]] = mockEditionRepository.upsert.mock.calls as [
      [Record<string, unknown> & { fetchedAt: unknown }, unknown],
    ];
    const { fetchedAt, ...rest } = saved;

    expect(rest).toStrictEqual({
      ...edition,
      raw: zootopia,
      normalizerVersion: NORMALIZER_VERSION,
    });
    expect(options).toStrictEqual({ conflictPaths: ['id'] });
    expect(fetchedAt).toBeInstanceOf(Date);
    expect((fetchedAt as Date).getTime()).toBeGreaterThanOrEqual(
      before.getTime(),
    );
    expect((fetchedAt as Date).getTime()).toBeLessThanOrEqual(Date.now());
  });

  it('should upsert a title on its composite key', async () => {
    const title = {
      tmdbId: '1084242',
      kind: 'movie',
      name: 'Zootopia 2',
      year: 2025,
      imdbId: 'tt26443597',
      posterPath: '/poster.jpg',
      raw: { id: 1084242 },
    } as unknown as Title;

    await store.saveTitle(title);

    expect(mockTitleRepository.upsert).toHaveBeenCalledWith(title, {
      conflictPaths: ['tmdbId', 'kind'],
    });
  });

  it('should upsert an unresolved GTIN with a fresh last-seen time and no first-seen time', async () => {
    const before = new Date();

    await store.recordUnresolvedGTIN('0043396647640');

    expect(mockUnresolvedRepository.upsert).toHaveBeenCalledTimes(1);
    const [[row, options]] = mockUnresolvedRepository.upsert.mock.calls as [
      [Record<string, unknown> & { lastSeenAt: unknown }, unknown],
    ];

    expect(options).toStrictEqual({ conflictPaths: ['gtin'] });
    expect(row.gtin).toBe('0043396647640');
    expect(row).not.toHaveProperty('firstSeenAt');
    expect(row.lastSeenAt).toBeInstanceOf(Date);
    expect((row.lastSeenAt as Date).getTime()).toBeGreaterThanOrEqual(
      before.getTime(),
    );
    expect((row.lastSeenAt as Date).getTime()).toBeLessThanOrEqual(Date.now());
  });
});

// Builds the SQL TypeORM would send, from the real entity metadata, without a
// database connection. Catches property-vs-column mistakes, wrong conflict
// targets and hidden columns, which the repository mocks above can't.
describe('TypeORMEditionStore SQL', () => {
  let store: TypeORMEditionStore;
  let queries: string[];

  const normalize = (sql: string) => sql.replace(/\s+/g, ' ').trim();

  beforeAll(async () => {
    const dataSource = new DataSource({
      type: 'postgres',
      entities: [Edition, Title, UnresolvedUPC],
    });
    await (
      dataSource as unknown as { buildMetadatas(): Promise<void> }
    ).buildMetadatas();

    store = new TypeORMEditionStore(
      dataSource.getRepository(Edition),
      dataSource.getRepository(Title),
      dataSource.getRepository(UnresolvedUPC),
    );
  });

  beforeEach(() => {
    queries = [];
    jest
      .spyOn(SelectQueryBuilder.prototype, 'getOne')
      .mockImplementation(function (this: SelectQueryBuilder<object>) {
        queries.push(normalize(this.getQuery()));
        return Promise.resolve(null);
      });
    jest
      .spyOn(InsertQueryBuilder.prototype, 'execute')
      .mockImplementation(function (this: InsertQueryBuilder<object>) {
        queries.push(normalize(this.getQuery()));
        return Promise.resolve({ identifiers: [], generatedMaps: [], raw: [] });
      });
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should leave raw, fetch time and normalizer version out of the response lookup', async () => {
    await store.findEditionByGTIN('0043396647640');

    const [sql] = queries;
    expect(sql).toContain('FROM "editions" "Edition"');
    expect(sql).toContain('"Edition"."edition_id"');
    expect(sql).not.toContain('"raw"');
    expect(sql).not.toContain('"fetched_at"');
    expect(sql).not.toContain('"normalizer_version"');
    expect(sql).not.toContain('JOIN');
  });

  it('should load raw, fetch time, normalizer version and the linked title in the full lookup', async () => {
    await store.findFullEditionByGTIN('0043396647640');

    const [sql] = queries;
    expect(sql).toContain('"edition"."raw"');
    expect(sql).toContain('"edition"."fetched_at"');
    expect(sql).toContain('"edition"."normalizer_version"');
    expect(sql).toContain('"edition"."title"');
    expect(sql).toContain('"edition"."steelbook"');
    expect(sql).toContain(
      'LEFT JOIN "titles" "work" ON "work"."tmdb_id"="edition"."title_tmdb_id" AND "work"."kind"="edition"."title_kind"',
    );
    expect(sql).toContain('"work"."name"');
    expect(sql).toContain('WHERE "edition"."edition_id" = :id');
  });

  it('should upsert editions on the GTIN primary key', async () => {
    await store.saveEdition(
      databaseZootopia as unknown as EditionResponse,
      zootopia,
    );

    const [sql] = queries;
    expect(sql).toContain('INSERT INTO "editions"');
    expect(sql).toMatch(/ON CONFLICT \( ?"edition_id" ?\) DO UPDATE SET/);
    expect(sql).toContain('"raw" = EXCLUDED."raw"');
    expect(sql).toContain('"fetched_at" = EXCLUDED."fetched_at"');
    expect(sql).toContain(
      '"normalizer_version" = EXCLUDED."normalizer_version"',
    );
  });

  it('should upsert titles on both columns of the composite key', async () => {
    await store.saveTitle({
      tmdbId: '1084242',
      kind: 'movie',
      name: 'Zootopia 2',
      year: 2025,
      imdbId: 'tt26443597',
      posterPath: '/poster.jpg',
      raw: { id: 1084242 },
    } as unknown as Title);

    const [sql] = queries;
    expect(sql).toContain('INSERT INTO "titles"');
    expect(sql).toMatch(/ON CONFLICT \( ?"tmdb_id", ?"kind" ?\) DO UPDATE SET/);
  });

  it('should upsert unresolved GTINs, updating last seen but never first seen', async () => {
    await store.recordUnresolvedGTIN('0043396647640');

    const [sql] = queries;
    expect(sql).toContain('INSERT INTO "unresolved_upcs"');
    expect(sql).toMatch(/ON CONFLICT \( ?"gtin" ?\) DO UPDATE SET/);
    const updateSet = sql.slice(sql.indexOf('DO UPDATE SET'));
    expect(updateSet).toContain('"last_seen_at" = EXCLUDED."last_seen_at"');
    expect(updateSet).not.toContain('"first_seen_at"');
  });
});
