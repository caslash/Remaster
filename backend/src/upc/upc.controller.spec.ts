import { UpcController } from '@/upc/upc.controller';
import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { UpcService } from './upc.service';

describe('UpcController', () => {
  let controller: UpcController;
  let app: INestApplication<App>;
  let mockUPCService: { getEdition: jest.Mock };

  beforeEach(async () => {
    mockUPCService = {
      getEdition: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [UpcController],
      providers: [{ provide: UpcService, useValue: mockUPCService }],
    }).compile();

    controller = module.get<UpcController>(UpcController);
    app = module.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should pass a known shape through to the service', async () => {
    await request(app.getHttpServer())
      .get('/upc/043396647640?shape=UPC-A')
      .expect(200);

    expect(mockUPCService.getEdition).toHaveBeenCalledWith(
      '043396647640',
      'UPC-A',
    );
  });

  it('should allow shape to be omitted', async () => {
    await request(app.getHttpServer()).get('/upc/043396647640').expect(200);

    expect(mockUPCService.getEdition).toHaveBeenCalledWith(
      '043396647640',
      undefined,
    );
  });

  // RMSTR-69: what the client's decoder sees on the wire.
  it('should send the nested title and unmatchedTitle false for a matched edition', async () => {
    const title = {
      tmdbId: '1084242',
      kind: 'movie',
      name: 'Zootopia 2',
      year: 2025,
      imdbId: 'tt26443597',
      posterURL: 'https://image.tmdb.org/t/p/w500/poster.jpg',
    };
    mockUPCService.getEdition.mockResolvedValue({
      id: '0043396647640',
      upcTitle: 'Zootopia 2',
      title,
      unmatchedTitle: false,
    });

    const response = await request(app.getHttpServer())
      .get('/upc/043396647640')
      .expect(200);

    expect(response.body).toMatchObject({
      upcTitle: 'Zootopia 2',
      title,
      unmatchedTitle: false,
    });
  });

  it('should leave the title key out of the JSON for an unmatched edition', async () => {
    mockUPCService.getEdition.mockResolvedValue({
      id: '0043396640559',
      upcTitle: 'Loki: The Complete Second Season',
      title: undefined,
      unmatchedTitle: true,
    });

    const response = await request(app.getHttpServer())
      .get('/upc/043396640559')
      .expect(200);

    expect(response.body).not.toHaveProperty('title');
    expect(response.body).toMatchObject({ unmatchedTitle: true });
  });

  it('should reject an unknown shape with 400', async () => {
    await request(app.getHttpServer())
      .get('/upc/043396647640?shape=banana')
      .expect(400);

    expect(mockUPCService.getEdition).not.toHaveBeenCalled();
  });
});
