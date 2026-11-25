import { ServiceUnavailableException } from '@nestjs/common';

export class RetryableServiceUnavailableException extends ServiceUnavailableException {
  constructor(
    public readonly retryAfter: number,
    message = 'Service temporarily unavailable. Please try again later.',
  ) {
    super(message);
  }
}
