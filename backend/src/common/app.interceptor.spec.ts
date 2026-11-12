import { TimingInterceptor } from '@/common/app.interceptor';
import { UpcController } from '@/upc/upc.controller';
import { UpcService } from '@/upc/upc.service';
import {
  CallHandler,
  ExecutionContext,
  INestApplication,
  Logger,
  LoggerService,
  NotFoundException,
} from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import { lastValueFrom, of, throwError, timer } from 'rxjs';
import { map } from 'rxjs/operators';
import request from 'supertest';
import { App } from 'supertest/types';

// RMSTR-70: the timing interceptor logs one line per request with the route
// (controller + handler names) and the duration, and nothing about the
// request. The UPC is in the URL, and docs/upc-endpoint.md (Privacy) says the
// server never logs the client's IP or request details.

const DURATION = /(\d+(?:\.\d+)?)\s*ms/;

describe('TimingInterceptor', () => {
  let interceptor: TimingInterceptor;
  let log: jest.SpyInstance;

  // The interceptor is only allowed to read which controller and handler
  // ran. Every way into the request throws, so a change that reads the URL,
  // params, headers or IP fails here.
  const context = (): ExecutionContext => {
    const off = () => {
      throw new Error('the timing interceptor must not read the request');
    };
    return {
      getClass: () => UpcController,
      // A stand-in with the handler's name; only `.name` is read.
      getHandler: () => function getTitle() {},
      switchToHttp: off,
      switchToRpc: off,
      switchToWs: off,
      getArgs: off,
      getArgByIndex: off,
      getType: () => 'http',
    } as unknown as ExecutionContext;
  };

  const handler = (source: CallHandler['handle']): CallHandler => ({
    handle: source,
  });

  const lines = (): string[] => log.mock.calls.map(([line]) => String(line));

  beforeEach(() => {
    interceptor = new TimingInterceptor();
    log = jest
      .spyOn(Logger.prototype, 'log')
      .mockImplementation(() => undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should log one line with the controller and handler name and a duration', async () => {
    await lastValueFrom(
      interceptor.intercept(
        context(),
        handler(() => of('edition')),
      ),
    );

    expect(lines()).toHaveLength(1);
    const [line] = lines();
    expect(line).toContain('UpcController.getTitle');
    expect(line).toMatch(DURATION);
  });

  it('should pass the response through unchanged', async () => {
    const response = { id: '0043396647640' };

    const result: unknown = await lastValueFrom(
      interceptor.intercept(
        context(),
        handler(() => of(response)),
      ),
    );

    expect(result).toBe(response);
  });

  it('should time how long the handler took', async () => {
    await lastValueFrom(
      interceptor.intercept(
        context(),
        handler(() => timer(40).pipe(map(() => 'edition'))),
      ),
    );

    const [line] = lines();
    const ms = Number(line.match(DURATION)?.[1]);
    expect(ms).toBeGreaterThanOrEqual(30);
    expect(ms).toBeLessThan(5_000);
  });

  it('should still log one line when the handler throws, and pass the error on unchanged', async () => {
    const error = new NotFoundException();

    await expect(
      lastValueFrom(
        interceptor.intercept(
          context(),
          handler(() => throwError(() => error)),
        ),
      ),
    ).rejects.toBe(error);

    expect(lines()).toHaveLength(1);
    expect(lines()[0]).toContain('UpcController.getTitle');
  });

  it('should not log until the handler has finished', () => {
    const observable = interceptor.intercept(
      context(),
      handler(() => of('edition')),
    );

    expect(lines()).toHaveLength(0);
    observable.subscribe();
    expect(lines()).toHaveLength(1);
  });
});

// The same interceptor registered as in AppModule, on the real controller,
// driven over HTTP with a request full of identifying details.
describe('TimingInterceptor over HTTP', () => {
  const UPC = '043396647640';
  const IP = '203.0.113.77';
  const USER_AGENT = 'Remaster-Test-Agent/9.9';

  let app: INestApplication<App>;
  let getEdition: jest.Mock;
  let logged: { level: string; message: string; context?: string }[];

  // Captures everything Nest logs during the request, from any class.
  const capture =
    (level: string) =>
    (message: unknown, ...rest: unknown[]) => {
      const context = rest.find(
        (part): part is string => typeof part === 'string',
      );
      logged.push({ level, message: String(message), context });
    };
  const captureLogger: LoggerService = {
    log: capture('log'),
    warn: capture('warn'),
    error: capture('error'),
    debug: capture('debug'),
    verbose: capture('verbose'),
    fatal: capture('fatal'),
  };

  const timingLines = () =>
    logged.filter((entry) => entry.context === TimingInterceptor.name);

  const send = (path: string) =>
    request(app.getHttpServer())
      .get(path)
      .set('X-Forwarded-For', IP)
      .set('User-Agent', USER_AGENT)
      .set('Authorization', 'Bearer not-a-real-token');

  beforeEach(async () => {
    getEdition = jest.fn();
    const module = await Test.createTestingModule({
      controllers: [UpcController],
      providers: [
        { provide: UpcService, useValue: { getEdition } },
        { provide: APP_INTERCEPTOR, useClass: TimingInterceptor },
      ],
    }).compile();

    // Nest logs while starting up, so the capture has to exist first; it's
    // cleared after init so each test sees only its own requests.
    logged = [];
    app = module.createNestApplication({ logger: captureLogger });
    await app.init();
    logged = [];
  });

  afterEach(async () => {
    await app.close();
  });

  it('should log one timing line for a lookup, with the route and a duration', async () => {
    getEdition.mockResolvedValue({ id: `0${UPC}` });

    await send(`/upc/${UPC}?shape=UPC-A`).expect(200);

    expect(timingLines()).toHaveLength(1);
    const [{ message, level }] = timingLines();
    expect(level).toBe('log');
    expect(message).toContain('UpcController.getTitle');
    expect(message).toMatch(DURATION);
  });

  it.each([
    ['a found edition', 200],
    ['a not-found code', 404],
  ])('should log nothing about the request for %s', async (_name, status) => {
    if (status === 200) getEdition.mockResolvedValue({ id: `0${UPC}` });
    else getEdition.mockRejectedValue(new NotFoundException());

    await send(`/upc/${UPC}?shape=UPC-A`).expect(status);

    expect(timingLines()).toHaveLength(1);
    const [{ message }] = timingLines();
    for (const detail of [
      UPC,
      'UPC-A',
      'shape',
      '/upc/',
      IP,
      USER_AGENT,
      'Bearer',
    ])
      expect([detail, message.includes(detail)]).toEqual([detail, false]);
  });

  it('should log one timing line for a request that fails', async () => {
    getEdition.mockRejectedValue(new NotFoundException());

    await send(`/upc/${UPC}`).expect(404);

    expect(timingLines()).toHaveLength(1);
  });

  it('should log one line per request', async () => {
    getEdition.mockResolvedValue({ id: `0${UPC}` });

    await send(`/upc/${UPC}`).expect(200);
    await send(`/upc/${UPC}`).expect(200);
    await send(`/upc/${UPC}`).expect(200);

    expect(timingLines()).toHaveLength(3);
  });
});
