import { HttpException, HttpStatus } from '@nestjs/common';

export class UpcTitleNotFoundException extends HttpException {
  constructor(upc: string) {
    super(`Title for UPC ${upc} could not be found`, HttpStatus.NOT_FOUND);
  }
}
