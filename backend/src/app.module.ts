import { Edition } from '@/upc/types/edition';
import { Title } from '@/upc/types/title';
import { UnresolvedUPC } from '@/upc/types/unresolved-upc';
import { UpcModule } from '@/upc/upc.module';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { join } from 'path';
import { z } from 'zod';

export const envSchema = z.object({
  UPCMDB_LOOKUP_URL: z.string(),
  UPCMDB_API_KEY: z.string(),
  TMDB_API_KEY: z.string(),
  DATABASE_URL: z.string(),
});
export type Env = z.infer<typeof envSchema>;

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (config) => envSchema.parse(config),
    }),
    TypeOrmModule.forRootAsync({
      useFactory: () => ({
        type: 'postgres',
        url: process.env.DATABASE_URL,
        entities: [Edition, Title, UnresolvedUPC],
        migrations: [join(__dirname, 'database/migrations/*.js')],
        synchronize: false,
        migrationsRun: true,
        extra: {
          max: 20,
          idleTimeoutMillis: 30_000,
          connectionTimeoutMillis: 5_000,
        },
        logging: false,
        retryAttempts: 4,
        retryDelay: 2000,
      }),
    }),
    UpcModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
