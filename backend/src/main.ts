import { AppModule } from '@/app.module';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import * as fs from 'fs';
import * as path from 'path';

async function bootstrap() {
  let httpsOptions;

  let key: NonSharedBuffer | undefined;
  let cert: NonSharedBuffer | undefined;

  try {
    key = fs.readFileSync(
      path.resolve(__dirname, '../secrets/localhost-key.pem'),
    );
    cert = fs.readFileSync(path.resolve(__dirname, '../secrets/localhost.pem'));
  } catch {
    key = undefined;
    cert = undefined;
  }

  if (key && cert) {
    httpsOptions = {
      key,
      cert,
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
