import { Module } from '@nestjs/common';
import { UpcModule } from './upc/upc.module';
import { ConfigModule } from '@nestjs/config';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), UpcModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
