import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { UpcController } from '@/upc/upc.controller';
import { UpcService } from './upc.service';

describe('UpcController', () => {
  let controller: UpcController;
  let app: INestApplication<App>;
  let mockUPCService: { getTitle: jest.Mock };

  beforeEach(async () => {
    mockUPCService = {
      getTitle: jest.fn(),
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

    expect(mockUPCService.getTitle).toHaveBeenCalledWith(
      '043396647640',
      'UPC-A',
    );
  });

  it('should allow shape to be omitted', async () => {
    await request(app.getHttpServer()).get('/upc/043396647640').expect(200);

    expect(mockUPCService.getTitle).toHaveBeenCalledWith(
      '043396647640',
      undefined,
    );
  });

  it('should reject an unknown shape with 400', async () => {
    await request(app.getHttpServer())
      .get('/upc/043396647640?shape=banana')
      .expect(400);

    expect(mockUPCService.getTitle).not.toHaveBeenCalled();
  });
});
