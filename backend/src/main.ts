import { AppModule } from '@/app.module';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import * as fs from 'fs';
import * as path from 'path';

async function bootstrap() {
  let httpsOptions;

  if (process.env.NODE_ENV !== 'production') {
    httpsOptions = {
      key: fs.readFileSync(
        path.resolve(__dirname, '../secrets/localhost-key.pem'),
      ),
      cert: fs.readFileSync(
        path.resolve(__dirname, '../secrets/localhost.pem'),
      ),
    };
  }

  const app = await NestFactory.create(AppModule, {
    httpsOptions,
  });
  await app.listen(process.env.PORT ?? 3000);
}

bootstrap().catch((error: unknown) => {
  new Logger('Bootstrap').error('Failed to start application', error);
  process.exit(1);
});
