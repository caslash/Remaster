import { BarcodeShape } from '@/upc/types/barcode-shape';
import { Edition } from '@/upc/types/edition';
import { UpcService } from '@/upc/upc.service';
import { Controller, Get, Param, ParseEnumPipe, Query } from '@nestjs/common';

@Controller('upc')
export class UpcController {
  public constructor(private upcService: UpcService) {}

  @Get(':upc')
  async getTitle(
    @Param('upc') upc: string,
    @Query('shape', new ParseEnumPipe(BarcodeShape, { optional: true }))
    shape: BarcodeShape | undefined,
  ): Promise<Edition> {
    return await this.upcService.getTitle(upc, shape);
  }
}
