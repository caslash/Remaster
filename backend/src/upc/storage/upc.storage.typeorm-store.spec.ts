import { EditionStore } from '@/upc/storage/upc.storage.store';
import { TypeORMEditionStore } from '@/upc/storage/upc.storage.typeorm-store';
import { Edition, EditionResponse } from '@/upc/types/edition';
import { Title } from '@/upc/types/title';
import { UnresolvedUPC } from '@/upc/types/unresolved-upc';
import { NORMALIZER_VERSION } from '@/upc/utils/upc.utils';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  DataSource,
  DeleteQueryBuilder,
  InsertQueryBuilder,
  SelectQueryBuilder,
} from 'typeorm';
import databaseZootopia from '../mock/database-zootopia.json';
import zootopia from '../mock/movie4kdv.json';

const zootopiaTitle = {
  tmdbId: '1084242',
  kind: 'movie',
  name: 'Zootopia 2',
  year: 2025,
  imdbId: 'tt26443597',
  posterPath: '/poster.jpg',
  raw: { id: 1084242 },
  editions: [],
} as unknown as Title;

const mockEditionRepository = {
  findOne: jest.fn(),
  upsert: jest.fn(),
};

const mockTitleRepository = {
  upsert: jest.fn(),
};

const mockUnresolvedRepository = {
  upsert: jest.fn(),
  // Only here so a delete that bypasses the transaction is caught.
  delete: (...args: unknown[]): unknown =>
    mockUnresolvedRepositoryDelete(...args),
};

// Stands in for the transaction's EntityManager.
const mockManager = {
  upsert: jest.fn(),
  delete: jest.fn(),
};

const mockUnresolvedRepositoryDelete = jest.fn();

// Stands in for the app's injected DataSource. transaction() hands the
// callback mockManager, like TypeORM hands it the transactional manager.
const mockDataSource = {
  manager: {
    transaction: jest.fn(),
  },
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
        { provide: DataSource, useValue: mockDataSource },
      ],
    }).compile();

    store = module.get<EditionStore>(EditionStore);

    // Set here, not in the jest.fn() calls above, because afterEach's
    // resetAllMocks wipes implementations.
    mockDataSource.manager.transaction.mockImplementation(
      (work: (manager: typeof mockManager) => Promise<unknown>) =>
        work(mockManager),
    );
    mockManager.upsert.mockResolvedValue(undefined);
    mockManager.delete.mockResolvedValue({ raw: [], affected: 0 });
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

  // saveEdition writes through the transaction's EntityManager, so these
  // assert on mockManager.upsert(Entity, row, options), not the repositories.
  const upsertsInto = (entity: unknown) =>
    (mockManager.upsert.mock.calls as [unknown, unknown, unknown][]).filter(
      ([target]) => target === entity,
    );

  it('should run both writes in one transaction, through its entity manager', async () => {
    await store.saveEdition(
      databaseZootopia as unknown as EditionResponse,
      zootopiaTitle,
      zootopia,
    );

    expect(mockDataSource.manager.transaction).toHaveBeenCalledTimes(1);
    expect(upsertsInto(Title)).toHaveLength(1);
    expect(upsertsInto(Edition)).toHaveLength(1);
    expect(mockTitleRepository.upsert).not.toHaveBeenCalled();
    expect(mockEditionRepository.upsert).not.toHaveBeenCalled();
  });

  it('should upsert an edition linked to its title', async () => {
    const edition = databaseZootopia as unknown as EditionResponse;

    await store.saveEdition(edition, zootopiaTitle, zootopia);

    const [[, saved]] = upsertsInto(Edition) as [
      [unknown, Record<string, unknown>, unknown],
    ];
    expect(saved.work).toBe(zootopiaTitle);
  });

  // editions.(title_tmdb_id, title_kind) is a foreign key to titles
  // (migration 1793932312854), so the title row has to exist before the
  // edition that points at it, or Postgres rejects the edition upsert.
  it('should upsert the title row before the edition that links to it', async () => {
    await store.saveEdition(
      databaseZootopia as unknown as EditionResponse,
      zootopiaTitle,
      zootopia,
    );

    expect(upsertsInto(Title)).toEqual([
      [
        Title,
        expect.objectContaining({
          tmdbId: zootopiaTitle.tmdbId,
          kind: zootopiaTitle.kind,
          raw: zootopiaTitle.raw,
        }),
        { conflictPaths: ['tmdbId', 'kind'] },
      ],
    ]);
    const targets = (mockManager.upsert.mock.calls as [unknown][]).map(
      ([target]) => target,
    );
    expect(targets).toEqual([Title, Edition]);
  });

  it('should not write a title row when the edition has no title', async () => {
    await store.saveEdition(
      databaseZootopia as unknown as EditionResponse,
      undefined,
      zootopia,
    );

    expect(upsertsInto(Title)).toEqual([]);
    expect(upsertsInto(Edition)).toHaveLength(1);
  });

  // Decided 2026-11-07: a code that was unresolved and later resolves leaves
  // unresolved_upcs, in the same transaction as the edition save.
  describe('clearing the unresolved row', () => {
    // Accepts the primary-key shorthand (a bare GTIN) or a criteria object.
    const deletesOfUnresolved = () =>
      (mockManager.delete.mock.calls as [unknown, unknown][]).filter(
        ([target]) => target === UnresolvedUPC,
      );
    const isGTINCriteria = (criteria: unknown, gtin: string) =>
      criteria === gtin ||
      (typeof criteria === 'object' &&
        criteria !== null &&
        (criteria as Record<string, unknown>).gtin === gtin);

    it.each([
      ['with a title', zootopiaTitle],
      ['without a title', undefined],
    ])(
      'should delete the unresolved row for the edition GTIN %s',
      async (_case, title) => {
        await store.saveEdition(
          databaseZootopia as unknown as EditionResponse,
          title,
          zootopia,
        );

        const deletes = deletesOfUnresolved();
        expect(deletes).toHaveLength(1);
        expect(isGTINCriteria(deletes[0][1], databaseZootopia.id)).toBe(true);
      },
    );

    it('should delete through the transaction, not the unresolved repository', async () => {
      await store.saveEdition(
        databaseZootopia as unknown as EditionResponse,
        zootopiaTitle,
        zootopia,
      );

      expect(mockDataSource.manager.transaction).toHaveBeenCalledTimes(1);
      expect(deletesOfUnresolved()).toHaveLength(1);
      expect(mockUnresolvedRepositoryDelete).not.toHaveBeenCalled();
    });

    it('should only delete from unresolved_upcs', async () => {
      await store.saveEdition(
        databaseZootopia as unknown as EditionResponse,
        zootopiaTitle,
        zootopia,
      );

      const targets = (mockManager.delete.mock.calls as [unknown][]).map(
        ([target]) => target,
      );
      expect(targets).toEqual([UnresolvedUPC]);
    });

    it('should reject, so the transaction rolls back, when the delete fails', async () => {
      const failure = new Error('delete failed');
      mockManager.delete.mockRejectedValue(failure);

      await expect(
        store.saveEdition(
          databaseZootopia as unknown as EditionResponse,
          zootopiaTitle,
          zootopia,
        ),
      ).rejects.toBe(failure);
    });

    it('should still save when there was no unresolved row to delete', async () => {
      mockManager.delete.mockResolvedValue({ raw: [], affected: 0 });

      await expect(
        store.saveEdition(
          databaseZootopia as unknown as EditionResponse,
          undefined,
          zootopia,
        ),
      ).resolves.toBeUndefined();
      expect(upsertsInto(Edition)).toHaveLength(1);
    });
  });

  it('should reject when the edition write fails, so the transaction rolls back', async () => {
    const failure = new Error('insert failed');
    mockManager.upsert.mockImplementation((target: unknown) =>
      target === Edition ? Promise.reject(failure) : Promise.resolve(),
    );

    await expect(
      store.saveEdition(
        databaseZootopia as unknown as EditionResponse,
        zootopiaTitle,
        zootopia,
      ),
    ).rejects.toBe(failure);
  });

  it('should upsert an edition with its raw response, fetch time and normalizer version', async () => {
    const edition = databaseZootopia as unknown as EditionResponse;
    const before = new Date();

    await store.saveEdition(edition, undefined, zootopia);

    const editionUpserts = upsertsInto(Edition);
    expect(editionUpserts).toHaveLength(1);
    const [[, saved, options]] = editionUpserts as [
      [unknown, Record<string, unknown> & { fetchedAt: unknown }, unknown],
    ];
    const { fetchedAt, ...rest } = saved;

    expect(rest).toStrictEqual({
      ...edition,
      raw: zootopia,
      normalizerVersion: NORMALIZER_VERSION,
      work: undefined,
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
  let dataSource: DataSource;
  let queries: string[];
  let deletes: { sql: string; parameters: unknown[] }[];

  const normalize = (sql: string) => sql.replace(/\s+/g, ' ').trim();

  // saveEdition can send more than one statement (the title, then the
  // edition), so pick the one for the table under test rather than the first.
  const insertInto = (table: string): string => {
    const sql = queries.find((query) =>
      query.startsWith(`INSERT INTO "${table}"`),
    );
    if (!sql)
      throw new Error(`No INSERT INTO "${table}" in: ${queries.join(' ;; ')}`);
    return sql;
  };

  beforeAll(async () => {
    dataSource = new DataSource({
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
      dataSource,
    );
  });

  beforeEach(() => {
    queries = [];
    // There's no connection to open a real transaction on, so run the
    // callback with the data source's own (unconnected) EntityManager. Its
    // upserts still build real SQL from the entity metadata, which execute()
    // below captures instead of sending.
    jest
      .spyOn(dataSource.manager, 'transaction')
      .mockImplementation(((work: (manager: unknown) => Promise<unknown>) =>
        work(dataSource.manager)) as never);
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
    deletes = [];
    jest
      .spyOn(DeleteQueryBuilder.prototype, 'execute')
      .mockImplementation(function (this: DeleteQueryBuilder<object>) {
        const [sql, parameters] = this.getQueryAndParameters();
        deletes.push({ sql: normalize(sql), parameters });
        return Promise.resolve({ raw: [], affected: 0 });
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

  it('should write both columns of the title link when an edition is saved with a title', async () => {
    await store.saveEdition(
      databaseZootopia as unknown as EditionResponse,
      zootopiaTitle,
      zootopia,
    );

    const sql = insertInto('editions');
    const columns = sql.slice(0, sql.indexOf('VALUES'));
    expect(columns).toContain('"title_tmdb_id"');
    expect(columns).toContain('"title_kind"');
    const updateSet = sql.slice(sql.indexOf('DO UPDATE SET'));
    expect(updateSet).toContain('"title_tmdb_id" = EXCLUDED."title_tmdb_id"');
    expect(updateSet).toContain('"title_kind" = EXCLUDED."title_kind"');
  });

  it('should delete the unresolved row by its gtin column when an edition is saved', async () => {
    await store.saveEdition(
      databaseZootopia as unknown as EditionResponse,
      undefined,
      zootopia,
    );

    expect(deletes).toHaveLength(1);
    const [{ sql, parameters }] = deletes;
    expect(sql).toMatch(/^DELETE FROM "unresolved_upcs" WHERE/);
    expect(sql).toContain('"gtin"');
    expect(parameters).toEqual([databaseZootopia.id]);
  });

  it('should upsert editions on the GTIN primary key', async () => {
    await store.saveEdition(
      databaseZootopia as unknown as EditionResponse,
      undefined,
      zootopia,
    );

    const sql = insertInto('editions');
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
