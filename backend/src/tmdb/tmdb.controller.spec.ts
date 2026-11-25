// RMSTR-56: GET /search?q= as the client sees it on the wire. The service is
// mocked; these specs cover validation, what reaches the service, and the
// status codes. The RetryAfterExceptionFilter is registered the same way
// AppModule registers it (APP_FILTER), so the 503 + Retry-After path is real.

import { RetryableServiceUnavailableException } from '@/common/exceptions/retryable-service-unavailable.exception';
import { RetryAfterExceptionFilter } from '@/common/filters/retry-after.filter';
import { TmdbService } from '@/tmdb/tmdb.service';
import { TitleResponse } from '@/upc/types/title';
import {
  BadGatewayException,
  GatewayTimeoutException,
  INestApplication,
} from '@nestjs/common';
import { APP_FILTER } from '@nestjs/core';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { TmdbController } from './tmdb.controller';

describe('TmdbController', () => {
  let controller: TmdbController;
  let app: INestApplication<App>;
  let mockTmdbService: { searchTitle: jest.Mock };

  const homeAlone: TitleResponse = {
    tmdbId: '771',
    kind: 'movie',
    name: 'Home Alone',
    year: 1990,
    imdbId: undefined,
    posterURL:
      'https://image.tmdb.org/t/p/w500/onTSipZ8R3bliBdKfPtsDuHTdlL.jpg',
  };

  beforeEach(async () => {
    mockTmdbService = {
      searchTitle: jest.fn().mockResolvedValue([]),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [TmdbController],
      providers: [
        { provide: TmdbService, useValue: mockTmdbService },
        { provide: APP_FILTER, useClass: RetryAfterExceptionFilter },
      ],
    }).compile();

    controller = module.get<TmdbController>(TmdbController);
    app = module.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('valid queries', () => {
    it('should pass the search text to the service and return its results', async () => {
      mockTmdbService.searchTitle.mockResolvedValue([homeAlone]);

      const response = await request(app.getHttpServer())
        .get('/search')
        .query({ q: 'Home Alone' })
        .expect(200);

      expect(mockTmdbService.searchTitle).toHaveBeenCalledWith('Home Alone');
      expect(response.body).toEqual([
        {
          tmdbId: '771',
          kind: 'movie',
          name: 'Home Alone',
          year: 1990,
          posterURL: homeAlone.posterURL,
        },
      ]);
    });

    it('should accept a query of exactly 2 characters', async () => {
      await request(app.getHttpServer())
        .get('/search')
        .query({ q: 'Up' })
        .expect(200);

      expect(mockTmdbService.searchTitle).toHaveBeenCalledWith('Up');
    });

    it('should trim surrounding whitespace before calling the service', async () => {
      await request(app.getHttpServer())
        .get('/search')
        .query({ q: '  Up  ' })
        .expect(200);

      expect(mockTmdbService.searchTitle).toHaveBeenCalledWith('Up');
    });

    it('should pass punctuation and non-ASCII text through unchanged', async () => {
      await request(app.getHttpServer())
        .get('/search')
        .query({ q: 'AC/DC & Amélie?' })
        .expect(200);

      expect(mockTmdbService.searchTitle).toHaveBeenCalledWith(
        'AC/DC & Amélie?',
      );
    });

    it('should return an empty array when nothing matches', async () => {
      const response = await request(app.getHttpServer())
        .get('/search')
        .query({ q: 'Zzyzx Road' })
        .expect(200);

      expect(response.body).toEqual([]);
    });
  });

  describe('invalid queries', () => {
    it.each([
      ['missing', '/search'],
      ['empty', '/search?q='],
      ['1 character', '/search?q=a'],
      ['only whitespace', '/search?q=%20%20%20'],
      ['1 character after trimming', '/search?q=%20a%20'],
      ['given twice', '/search?q=Home&q=Alone'],
    ])(
      'should return 400 without calling TMDB when q is %s',
      async (_, path) => {
        await request(app.getHttpServer()).get(path).expect(400);

        expect(mockTmdbService.searchTitle).not.toHaveBeenCalled();
      },
    );

    it('should not serve the old /tmdb/search/:text route', async () => {
      await request(app.getHttpServer())
        .get('/tmdb/search/Home%20Alone')
        .expect(404);

      expect(mockTmdbService.searchTitle).not.toHaveBeenCalled();
    });
  });

  describe('upstream errors', () => {
    it('should return 503 with Retry-After when TMDB rate-limits', async () => {
      mockTmdbService.searchTitle.mockRejectedValue(
        new RetryableServiceUnavailableException(2),
      );

      const response = await request(app.getHttpServer())
        .get('/search')
        .query({ q: 'Home Alone' })
        .expect(503);

      expect(response.headers['retry-after']).toBe('2');
      expect(response.body).toMatchObject({ statusCode: 503 });
    });

    it("should send the exception's Retry-After seconds as the header", async () => {
      mockTmdbService.searchTitle.mockRejectedValue(
        new RetryableServiceUnavailableException(7),
      );

      const response = await request(app.getHttpServer())
        .get('/search')
        .query({ q: 'Home Alone' })
        .expect(503);

      expect(response.headers['retry-after']).toBe('7');
    });

    it.each([
      [502, new BadGatewayException('TMDB returned an error')],
      [504, new GatewayTimeoutException('TMDB request timed out')],
    ])(
      'should return %i with no Retry-After for other TMDB failures',
      async (status, thrown) => {
        mockTmdbService.searchTitle.mockRejectedValue(thrown);

        const response = await request(app.getHttpServer())
          .get('/search')
          .query({ q: 'Home Alone' })
          .expect(status);

        expect(response.headers).not.toHaveProperty('retry-after');
      },
    );
  });
});
