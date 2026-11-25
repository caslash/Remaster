import { RetryableServiceUnavailableException } from '@/common/exceptions/retryable-service-unavailable.exception';
import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';
import { Response } from 'express';

@Catch(RetryableServiceUnavailableException)
export class RetryAfterExceptionFilter implements ExceptionFilter {
  catch(exception: RetryableServiceUnavailableException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const status = exception.getStatus();

    response.setHeader('Retry-After', exception.retryAfter.toString());

    response.status(status).json(exception.getResponse());
  }
}
