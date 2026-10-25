import { Module } from '@nestjs/common';
import { UpcController } from '@/upc/upc.controller';
import { UpcService } from '@/upc/upc.service';

@Module({
  controllers: [UpcController],
  providers: [UpcService],
})
export class UpcModule {}
