import { Edition } from '@/upc/types/edition';
import { UpcController } from '@/upc/upc.controller';
import { UpcService } from '@/upc/upc.service';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

@Module({
  imports: [TypeOrmModule.forFeature([Edition])],
  controllers: [UpcController],
  providers: [UpcService],
})
export class UpcModule {}
