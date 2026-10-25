import { Controller, Get, Param, Query } from '@nestjs/common';
import { UpcService } from './upc.service';
import { Edition } from './types/edition';

@Controller('upc')
export class UpcController {
  public constructor(private upcService: UpcService) {}

  @Get(':upc')
  async getTitle(@Param('upc') upc: string): Promise<Edition | undefined> {
    return await this.upcService.getTitle(upc);
  }
}
