import { Test, TestingModule } from '@nestjs/testing';
import { UpcController } from '@/upc/upc.controller';

describe('UpcController', () => {
  let controller: UpcController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UpcController],
    }).compile();

    controller = module.get<UpcController>(UpcController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
