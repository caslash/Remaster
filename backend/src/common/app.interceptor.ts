import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { performance } from 'node:perf_hooks';
import { finalize, Observable } from 'rxjs';

@Injectable()
export class TimingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(TimingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const startTime = performance.now();
    const label = `${context.getClass().name}.${context.getHandler().name}`;
    return next.handle().pipe(
      finalize(() => {
        const elapsed = performance.now() - startTime;
        this.logger.log(`[${label}] - Finished in ${elapsed.toFixed()}ms`);
      }),
    );
  }
}
