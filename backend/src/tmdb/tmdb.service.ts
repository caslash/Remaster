import { Env } from '@/app.module';
import { PosterSize } from '@/upc/types/poster-size';
import { Title, TitleResponse } from '@/upc/types/title';
import { isRecord, isValidString } from '@/upc/utils/upc.utils';
import {
  BadGatewayException,
  GatewayTimeoutException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import dayjs from 'dayjs';
import customParseFormat from 'dayjs/plugin/customParseFormat';
dayjs.extend(customParseFormat);

@Injectable()
export class TmdbService {
  private readonly logger = new Logger(TmdbService.name);
  private readonly tmdbURL: string;
  private readonly tmdbToken: string;
  constructor(private configService: ConfigService<Env, true>) {
    this.tmdbURL = this.configService.getOrThrow<string>('TMDB_BASE_URL');
    this.tmdbToken = this.configService.getOrThrow<string>(
      'TMDB_READ_ACCESS_TOKEN',
    );
  }

  public async getTitle(
    imdbId: string,
    kind: 'tv' | 'movie' | undefined,
  ): Promise<Title | undefined> {
    let response: Response;
    let body: string = '';
    let json: unknown;

    try {
      response = await fetch(
        `${this.tmdbURL}/find/${imdbId}?external_source=imdb_id`,
        {
          method: 'GET',
          headers: { Authorization: `Bearer ${this.tmdbToken}` },
          signal: AbortSignal.timeout(5000),
        },
      );

      if (!response.ok) {
        this.logger.warn(
          `TMDB responded with status ${response.status} - ${response.statusText}`,
        );
        throw new BadGatewayException('TMDB returned an error');
      }

      body = await response.text();
      json = JSON.parse(body);
    } catch (error) {
      if (error instanceof DOMException) {
        if (error.name === 'TimeoutError') {
          this.logger.error(error.message);
          throw new GatewayTimeoutException('TMDB request timed out');
        }
      }
      if (error instanceof TypeError) {
        if (!isRecord(error.cause))
          throw new BadGatewayException('TMDB request failed');
        this.logger.error(error.cause.code);
        throw new BadGatewayException('TMDB request failed');
      }
      if (error instanceof SyntaxError) {
        this.logger.error(
          `TMDB returned an invalid response of length ${body.length}`,
        );
        throw new BadGatewayException('TMDB returned an invalid response');
      }
      throw error;
    }

    if (isRecord(json)) return this.parseTitleFromJSON(imdbId, json, kind);
    this.logger.error('TMDB response body is not a JSON object');
    throw new BadGatewayException('TMDB returned an invalid response');
  }

  public async searchTitle(searchText: string): Promise<TitleResponse[]> {
    let response: Response;
    let body: string = '';
    let json: unknown;

    try {
      response = await fetch(
        `${this.tmdbURL}/search/multi?query=${encodeURIComponent(searchText)}&include_adult=false&language=en-US&page=1`,
        {
          method: 'GET',
          headers: { Authorization: `Bearer ${this.tmdbToken}` },
          signal: AbortSignal.timeout(5000),
        },
      );

      if (!response.ok) {
        this.logger.warn(
          `TMDB responded with status ${response.status} - ${response.statusText}`,
        );
        throw new BadGatewayException('TMDB returned an error');
      }

      body = await response.text();
      json = JSON.parse(body);
    } catch (error) {
      if (error instanceof DOMException) {
        if (error.name === 'TimeoutError') {
          this.logger.error(error.message);
          throw new GatewayTimeoutException('TMDB request timed out');
        }
      }
      if (error instanceof TypeError) {
        if (!isRecord(error.cause))
          throw new BadGatewayException('TMDB request failed');
        this.logger.error(error.cause.code);
        throw new BadGatewayException('TMDB request failed');
      }
      if (error instanceof SyntaxError) {
        this.logger.error(
          `TMDB returned an invalid response of length ${body.length}`,
        );
        throw new BadGatewayException('TMDB returned an invalid response');
      }
      throw error;
    }

    if (isRecord(json)) return this.parseTitleResponsesFromJSON(json);
    this.logger.error('TMDB response body is not a JSON object');
    throw new BadGatewayException('TMDB returned an invalid response');
  }

  public getPosterURL(path: string, size: PosterSize): string {
    return `https://image.tmdb.org/t/p/${size}${path}`;
  }

  private parseTitleFromJSON(
    imdbId: string,
    response: Record<string, unknown>,
    kind: 'tv' | 'movie' | undefined,
  ): Title | undefined {
    if (
      !Array.isArray(response.tv_results) ||
      !Array.isArray(response.movie_results)
    ) {
      this.logger.error(
        `The following fields were invalid: ${!Array.isArray(response.tv_results) ? '\n- tv_results' : ''}${!Array.isArray(response.movie_results) ? '\n- movie_results' : ''}`,
      );
      throw new BadGatewayException('TMDB returned an invalid response');
    }

    const tvResult = this.parseTitleFromResponse(
      imdbId,
      response.tv_results,
      'tv',
      response,
    );
    const movieResult = this.parseTitleFromResponse(
      imdbId,
      response.movie_results,
      'movie',
      response,
    );

    switch (kind) {
      case 'tv':
        if (movieResult && !tvResult)
          this.logger.warn('Mismatched kind: Expected tv but only found movie');
        return tvResult ?? movieResult;
      case 'movie':
        if (!movieResult && tvResult)
          this.logger.warn('Mismatched kind: Expected movie but only found tv');
        return movieResult ?? tvResult;
    }

    return movieResult ?? tvResult;
  }

  private parseTitleFromResponse(
    imdbId: string,
    results: unknown[],
    kind: 'tv' | 'movie',
    response: Record<string, unknown>,
  ): Title | undefined {
    if (results.length == 0 || !isRecord(results[0])) return;
    const result = results[0];

    const name: string = this.normalizeName(kind, result);
    const tmdbId: number | undefined =
      typeof result.id === 'number' ? result.id : undefined;
    if (!name || !tmdbId) return;

    return {
      tmdbId: `${tmdbId}`,
      kind: this.normalizeKind(result) ?? kind,
      name,
      year: this.normalizeYear(kind, result),
      imdbId: imdbId,
      posterPath: isValidString(result.poster_path)
        ? result.poster_path
        : undefined,
      raw: response,
      editions: [],
    };
  }

  private normalizeName(
    kind: 'tv' | 'movie',
    result: Record<string, unknown>,
  ): string {
    switch (kind) {
      case 'tv':
        return isValidString(result.name) ? result.name : '';
      case 'movie':
        return isValidString(result.title) ? result.title : '';
    }
  }

  private normalizeKind(
    result: Record<string, unknown>,
  ): 'movie' | 'tv' | undefined {
    if (result.media_type === 'movie' || result.media_type === 'tv')
      return result.media_type;
  }

  private normalizeYear(
    kind: 'tv' | 'movie',
    result: Record<string, unknown>,
  ): number | undefined {
    let dateString: string;
    switch (kind) {
      case 'tv':
        if (!isValidString(result.first_air_date)) return;
        dateString = result.first_air_date;
        break;
      case 'movie':
        if (!isValidString(result.release_date)) return;
        dateString = result.release_date;
        break;
    }

    const parsedDate = dayjs(dateString, ['YYYY-MM-DD', 'YYYY-MM-D'], true);

    if (parsedDate.isValid()) return parsedDate.year();

    this.logger.warn(`Unknown release_date format - ${dateString}`);
  }

  private parseTitleResponsesFromJSON(
    response: Record<string, unknown>,
  ): TitleResponse[] {
    if (!Array.isArray(response.results)) {
      this.logger.error(`The results field in the response was invalid`);
      throw new BadGatewayException('TMDB returned an invalid response');
    }

    return response.results
      .map((item) => this.parseTitleResponseFromObject(item))
      .filter((item) => item != undefined);
  }

  private parseTitleResponseFromObject(
    response: unknown,
  ): TitleResponse | undefined {
    if (!isRecord(response)) return undefined;

    const tmdbId: number | undefined =
      typeof response.id === 'number' ? response.id : undefined;
    if (!tmdbId) return undefined;

    const kind = this.normalizeKind(response);
    if (!kind) return undefined;

    const name = this.normalizeName(kind, response);
    if (!name) return undefined;

    if (!isValidString(response.id)) return undefined;

    return {
      tmdbId: `${tmdbId}`,
      kind: kind,
      name: name,
      year: this.normalizeYear(kind, response),
      imdbId: undefined,
      posterURL: isValidString(response.poster_path)
        ? this.getPosterURL(response.poster_path, PosterSize.W500)
        : undefined,
    };
  }
}
