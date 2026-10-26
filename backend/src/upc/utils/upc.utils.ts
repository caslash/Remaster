import { BadRequestException } from '@nestjs/common';
import { upcE, isValid } from 'gtin';
import { BarcodeShape } from '@/upc/types/barcode-shape';

export function normalizeUPC(
  upc: string,
  shape: BarcodeShape | undefined,
): string {
  if (!/^\d+$/.test(upc)) throw new BadRequestException();
  switch (shape) {
    case 'EAN-13':
      if (upc.length === 13 && isValid(upc)) return upc;
      throw new BadRequestException();
    case 'UPC-A':
      if (upc.length === 12 && isValid(upc)) return `0${upc}`;
      throw new BadRequestException();
    case 'EAN-8':
      if (upc.length === 8 && isValid(upc)) return `00000${upc}`;
      throw new BadRequestException();
    case 'UPC-E':
      if (isValidUPCE(upc)) return `0${upcE.expand(upc)}`;
      throw new BadRequestException();
    default:
      if (upc.length === 12 && isValid(upc)) return `0${upc}`;
      if (upc.length === 13 && isValid(upc)) return upc;
      if (upc.length === 8) {
        if (isValidUPCE(upc)) return `0${upcE.expand(upc)}`;
        if (isValid(upc)) return `00000${upc}`;
      }
      throw new BadRequestException();
  }
}

function isValidUPCE(upc: string): boolean {
  return (
    upc.length === 8 &&
    (upc[0] === '0' || upc[0] === '1') &&
    isValid(upcE.expand(upc))
  );
}

export function isRecord(obj: unknown): obj is Record<string, unknown> {
  return typeof obj === 'object' && obj !== null && !Array.isArray(obj);
}
