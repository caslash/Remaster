import { Test, TestingModule } from '@nestjs/testing';
import { UpcService } from '@/upc/upc.service';

describe('UpcService', () => {
  let service: UpcService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [UpcService],
    }).compile();

    service = module.get<UpcService>(UpcService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
