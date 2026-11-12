import { AppModule } from '@/app.module';
import { RebuildService } from '@/upc/normalization/rebuild.service';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
const logger = new Logger('Rebuild');

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  try {
    const summary = await app.get(RebuildService).rebuildEditions();
    logger.log(summary);
  } finally {
    await app.close();
  }
}

bootstrap().catch((err) => {
  logger.error(err);
  process.exit(1);
});
