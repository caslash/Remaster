import { UpcModule } from '@/upc/upc.module';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { z } from 'zod';

export const envSchema = z.object({
  UPCMDB_LOOKUP_URL: z.string(),
  UPCMDB_API_KEY: z.string().default(''),
});
export type Env = z.infer<typeof envSchema>;

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (config) => envSchema.parse(config),
    }),
    UpcModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
