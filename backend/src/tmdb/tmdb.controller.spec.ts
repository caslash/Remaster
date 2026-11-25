import { TmdbService } from '@/tmdb/tmdb.service';
import { Test, TestingModule } from '@nestjs/testing';
import { TmdbController } from './tmdb.controller';

describe('TmdbController', () => {
  let controller: TmdbController;
  let mockTmdbService: { searchTitle: jest.Mock };

  beforeEach(async () => {
    mockTmdbService = {
      searchTitle: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [TmdbController],
      providers: [{ provide: TmdbService, useValue: mockTmdbService }],
    }).compile();

    controller = module.get<TmdbController>(TmdbController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
