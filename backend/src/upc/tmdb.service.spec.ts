import { TMDBService } from '@/upc/tmdb.service';
import { PosterSize } from '@/upc/types/poster-size';
import {
  BadGatewayException,
  GatewayTimeoutException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';

import tmdbEmpty from './mock/tmdbempty.json';
import tmdbMovie from './mock/tmdbmovie.json';
import tmdbTV from './mock/tmdbtv.json';

const FIND_URL = 'https://tmdb.test/3/find/';
const TOKEN = 'test-token';
const ZOOTOPIA_IMDB = 'tt26443597';
const WANDAVISION_IMDB = 'tt9140560';

describe('TMDBService', () => {
  let service: TMDBService;
  let warn: jest.SpyInstance;
  let error: jest.SpyInstance;

  const mockConfigService = {
    getOrThrow: jest.fn((key: string) => {
      const env: Record<string, string> = {
        TMDB_FIND_URL: FIND_URL,
        TMDB_READ_ACCESS_TOKEN: TOKEN,
      };

      if (!(key in env)) throw new Error(`Missing config key: ${key}`);
      return env[key];
    }),
  };

  const respondWithBody = (body: string, status = 200) => {
    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: status >= 200 && status < 300,
      status,
      statusText: 'status text',
      text: () => Promise.resolve(body),
    });
  };

  const respondWithJSON = (json: unknown, status = 200) =>
    respondWithBody(JSON.stringify(json), status);

  /** Every argument passed to the logger, flattened to strings. */
  const loggedText = (): string =>
    [...(warn.mock.calls as unknown[][]), ...(error.mock.calls as unknown[][])]
      .flat()
      .map((arg) => String(arg))
      .join('\n');

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TMDBService,
        { provide: ConfigService, useValue: mockConfigService },
      ],
    }).compile();

    service = module.get<TMDBService>(TMDBService);
    warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation();
    error = jest.spyOn(Logger.prototype, 'error').mockImplementation();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('request', () => {
    it('sends only the IMDb ID and the bearer token to /find', async () => {
      respondWithJSON(tmdbMovie);

      await service.getTitle(ZOOTOPIA_IMDB, 'movie');

      expect(global.fetch).toHaveBeenCalledTimes(1);
      const [url, init] = (global.fetch as jest.Mock).mock.calls[0] as [
        string,
        RequestInit,
      ];
      expect(url).toBe(`${FIND_URL}${ZOOTOPIA_IMDB}?external_source=imdb_id`);
      expect(init.method).toBe('GET');
      expect(init.headers).toEqual({ Authorization: `Bearer ${TOKEN}` });
      expect(init.signal).toBeInstanceOf(AbortSignal);
    });
  });

  describe('match', () => {
    it('maps a movie result', async () => {
      respondWithJSON(tmdbMovie);

      const title = await service.getTitle(ZOOTOPIA_IMDB, 'movie');

      expect(title).toMatchObject({
        tmdbId: '1084242',
        kind: 'movie',
        name: 'Zootopia 2',
        year: 2025,
        imdbId: ZOOTOPIA_IMDB,
        posterPath: '/oJ7g2CifqpStmoYQyaLQgEU32qO.jpg',
      });
    });

    it('maps a TV result using name and first_air_date', async () => {
      respondWithJSON(tmdbTV);

      const title = await service.getTitle(WANDAVISION_IMDB, 'tv');

      expect(title).toMatchObject({
        tmdbId: '85271',
        kind: 'tv',
        name: 'WandaVision',
        year: 2021,
        imdbId: WANDAVISION_IMDB,
        posterPath: '/ijWWwINc8h71NQ8j1LTJMFSj5wr.jpg',
      });
    });

    it('returns the TMDB ID as a string', async () => {
      respondWithJSON(tmdbMovie);

      const title = await service.getTitle(ZOOTOPIA_IMDB, 'movie');

      expect(typeof title?.tmdbId).toBe('string');
    });

    it('keeps the whole TMDB response as raw, not just the chosen entry', async () => {
      respondWithJSON(tmdbTV);

      const title = await service.getTitle(WANDAVISION_IMDB, 'tv');

      expect(title?.raw).toEqual(tmdbTV);
    });

    it('leaves year undefined when the date is missing', async () => {
      const [entry] = tmdbMovie.movie_results;
      respondWithJSON({
        ...tmdbMovie,
        movie_results: [{ ...entry, release_date: undefined }],
      });

      const title = await service.getTitle(ZOOTOPIA_IMDB, 'movie');

      expect(title).toBeDefined();
      expect(title?.year).toBeUndefined();
    });

    it('leaves year undefined and warns when the date is not YYYY-MM-DD', async () => {
      const [entry] = tmdbMovie.movie_results;
      respondWithJSON({
        ...tmdbMovie,
        movie_results: [{ ...entry, release_date: 'Nov 26, 2025' }],
      });

      const title = await service.getTitle(ZOOTOPIA_IMDB, 'movie');

      expect(title).toBeDefined();
      expect(title?.year).toBeUndefined();
      expect(warn).toHaveBeenCalled();
    });

    it('leaves posterPath undefined when poster_path is null', async () => {
      const [entry] = tmdbMovie.movie_results;
      respondWithJSON({
        ...tmdbMovie,
        movie_results: [{ ...entry, poster_path: null }],
      });

      const title = await service.getTitle(ZOOTOPIA_IMDB, 'movie');

      expect(title).toBeDefined();
      expect(title?.posterPath).toBeUndefined();
    });

    it('takes kind from the list when media_type is missing', async () => {
      const [entry] = tmdbTV.tv_results;
      respondWithJSON({
        ...tmdbTV,
        tv_results: [{ ...entry, media_type: undefined }],
      });

      const title = await service.getTitle(WANDAVISION_IMDB, 'tv');

      expect(title?.kind).toBe('tv');
    });
  });

  describe('choosing between movie and TV results', () => {
    const bothLists = {
      ...tmdbMovie,
      tv_results: tmdbTV.tv_results,
    };

    it('uses the movie list when kind is undefined and only movies match', async () => {
      respondWithJSON(tmdbMovie);

      const title = await service.getTitle(ZOOTOPIA_IMDB, undefined);

      expect(title?.kind).toBe('movie');
      expect(title?.name).toBe('Zootopia 2');
    });

    it('uses the TV list when kind is undefined and only TV matches', async () => {
      respondWithJSON(tmdbTV);

      const title = await service.getTitle(WANDAVISION_IMDB, undefined);

      expect(title?.kind).toBe('tv');
      expect(title?.name).toBe('WandaVision');
    });

    it('prefers the movie result when kind is undefined and both lists match', async () => {
      respondWithJSON(bothLists);

      const title = await service.getTitle(ZOOTOPIA_IMDB, undefined);

      expect(title?.kind).toBe('movie');
    });

    it('prefers the hinted kind when both lists match (tv)', async () => {
      respondWithJSON(bothLists);

      const title = await service.getTitle(WANDAVISION_IMDB, 'tv');

      expect(title?.kind).toBe('tv');
      expect(warn).not.toHaveBeenCalled();
    });

    it('prefers the hinted kind when both lists match (movie)', async () => {
      respondWithJSON(bothLists);

      const title = await service.getTitle(ZOOTOPIA_IMDB, 'movie');

      expect(title?.kind).toBe('movie');
      expect(warn).not.toHaveBeenCalled();
    });

    it('falls back to the movie result and warns when kind is tv', async () => {
      respondWithJSON(tmdbMovie);

      const title = await service.getTitle(ZOOTOPIA_IMDB, 'tv');

      expect(title?.kind).toBe('movie');
      expect(warn).toHaveBeenCalledTimes(1);
    });

    it('falls back to the TV result and warns when kind is movie', async () => {
      respondWithJSON(tmdbTV);

      const title = await service.getTitle(WANDAVISION_IMDB, 'movie');

      expect(title?.kind).toBe('tv');
      expect(warn).toHaveBeenCalledTimes(1);
    });
  });

  describe('no match', () => {
    it.each([['movie' as const], ['tv' as const], [undefined]])(
      'returns undefined when both lists are empty (kind %s)',
      async (kind) => {
        respondWithJSON(tmdbEmpty);

        await expect(service.getTitle(ZOOTOPIA_IMDB, kind)).resolves.toBe(
          undefined,
        );
      },
    );

    it('returns undefined when the entry has no id', async () => {
      const [entry] = tmdbMovie.movie_results;
      respondWithJSON({
        ...tmdbMovie,
        movie_results: [{ ...entry, id: undefined }],
      });

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).resolves.toBe(
        undefined,
      );
    });

    it('returns undefined when the movie entry has no title', async () => {
      const [entry] = tmdbMovie.movie_results;
      respondWithJSON({
        ...tmdbMovie,
        movie_results: [{ ...entry, title: undefined }],
      });

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).resolves.toBe(
        undefined,
      );
    });

    it('returns undefined when the TV entry has no name', async () => {
      const [entry] = tmdbTV.tv_results;
      respondWithJSON({
        ...tmdbTV,
        tv_results: [{ ...entry, name: undefined }],
      });

      await expect(service.getTitle(WANDAVISION_IMDB, 'tv')).resolves.toBe(
        undefined,
      );
    });

    it('returns undefined when the entry is null', async () => {
      respondWithJSON({ ...tmdbMovie, movie_results: [null] });

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).resolves.toBe(
        undefined,
      );
    });
  });

  describe('upstream failure', () => {
    it('throws GatewayTimeout when the request times out', async () => {
      global.fetch = jest
        .fn()
        .mockRejectedValueOnce(
          new DOMException(
            'The operation was aborted due to timeout',
            'TimeoutError',
          ),
        );

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
        GatewayTimeoutException,
      );
      expect(error).toHaveBeenCalled();
    });

    it('throws GatewayTimeout when reading the body times out', async () => {
      global.fetch = jest.fn().mockResolvedValueOnce({
        ok: true,
        status: 200,
        text: () =>
          Promise.reject(
            new DOMException(
              'The operation was aborted due to timeout',
              'TimeoutError',
            ),
          ),
      });

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
        GatewayTimeoutException,
      );
    });

    it('throws BadGateway and logs the cause code on a network error', async () => {
      global.fetch = jest.fn().mockRejectedValueOnce(
        new TypeError('fetch failed', {
          cause: { code: 'ECONNREFUSED' },
        }),
      );

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
        BadGatewayException,
      );
      expect(loggedText()).toContain('ECONNREFUSED');
    });

    it('throws BadGateway on a network error with no cause', async () => {
      global.fetch = jest
        .fn()
        .mockRejectedValueOnce(new TypeError('fetch failed'));

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
        BadGatewayException,
      );
    });

    it.each([[401], [404], [429], [500], [503]])(
      'throws BadGateway when TMDB responds with %i',
      async (status) => {
        respondWithJSON({ status_code: 7, success: false }, status);

        await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
          BadGatewayException,
        );
      },
    );

    it('throws BadGateway when the body is not JSON', async () => {
      respondWithBody('<html><head><title>Zootopia 2</title></head></html>');

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
        BadGatewayException,
      );
    });

    it.each([
      ['an array', []],
      ['a string', 'Zootopia 2'],
      ['a number', 42],
      ['null', null],
    ])('throws BadGateway when the JSON is %s', async (_, json) => {
      respondWithJSON(json);

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
        BadGatewayException,
      );
    });

    it('throws BadGateway when tv_results is missing', async () => {
      const withoutTV: Record<string, unknown> = { ...tmdbMovie };
      delete withoutTV.tv_results;
      respondWithJSON(withoutTV);

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
        BadGatewayException,
      );
    });

    it('throws BadGateway when movie_results is not an array', async () => {
      respondWithJSON({ ...tmdbTV, movie_results: {} });

      await expect(service.getTitle(WANDAVISION_IMDB, 'tv')).rejects.toThrow(
        BadGatewayException,
      );
    });

    it('does not put upstream details in the client-facing message', async () => {
      global.fetch = jest.fn().mockRejectedValueOnce(
        new TypeError('fetch failed', {
          cause: { code: 'ECONNREFUSED' },
        }),
      );

      await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
        'TMDB request failed',
      );
    });
  });

  describe('getPosterURL', () => {
    const posterPath = tmdbMovie.movie_results[0].poster_path;

    it.each(Object.values(PosterSize))(
      'builds the TMDB image URL for size %s',
      (size) => {
        expect(service.getPosterURL(posterPath, size)).toBe(
          `https://image.tmdb.org/t/p/${size}/oJ7g2CifqpStmoYQyaLQgEU32qO.jpg`,
        );
      },
    );

    it('covers exactly the poster sizes TMDB offers', () => {
      expect(Object.values(PosterSize)).toEqual([
        'w92',
        'w154',
        'w185',
        'w342',
        'w500',
        'w780',
        'original',
      ]);
    });

    it.each(Object.values(PosterSize))(
      'produces a URL that parses, with no doubled slash (size %s)',
      (size) => {
        const url = new URL(service.getPosterURL(posterPath, size));

        expect(url.protocol).toBe('https:');
        expect(url.pathname).not.toContain('//');
        expect(url.pathname.endsWith(posterPath)).toBe(true);
      },
    );

    it('makes no network request', () => {
      global.fetch = jest.fn();

      service.getPosterURL(posterPath, PosterSize.W500);

      expect(global.fetch).not.toHaveBeenCalled();
    });
  });

  describe('privacy', () => {
    const failures: [string, () => void][] = [
      ['a non-2xx response', () => respondWithJSON({}, 500)],
      [
        'a body that is not JSON',
        () => respondWithBody('{"title": "Zootopia 2", '),
      ],
      ['JSON that is not an object', () => respondWithJSON(['Zootopia 2'])],
      [
        'missing result lists',
        () => respondWithJSON({ movie_results: 'Zootopia 2' }),
      ],
      [
        'a network error',
        () => {
          global.fetch = jest.fn().mockRejectedValueOnce(
            new TypeError('fetch failed', {
              cause: { code: 'ENOTFOUND' },
            }),
          );
        },
      ],
    ];

    it.each(failures)(
      'does not log the IMDb ID or title on %s',
      async (_, arrange) => {
        arrange();

        await expect(service.getTitle(ZOOTOPIA_IMDB, 'movie')).rejects.toThrow(
          BadGatewayException,
        );

        const logged = loggedText();
        expect(logged).not.toContain(ZOOTOPIA_IMDB);
        expect(logged).not.toContain('Zootopia');
      },
    );

    it('does not log the IMDb ID or title on a kind mismatch', async () => {
      respondWithJSON(tmdbMovie);

      await service.getTitle(ZOOTOPIA_IMDB, 'tv');

      const logged = loggedText();
      expect(logged).not.toContain(ZOOTOPIA_IMDB);
      expect(logged).not.toContain('Zootopia');
    });
  });
});
