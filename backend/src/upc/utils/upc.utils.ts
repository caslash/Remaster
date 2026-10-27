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

export function isNotRetailProductReason(
  upc: string,
): StoreRangeReason | undefined {
  const prefix = Number(upc.slice(0, 3));

  return storeRangeTable.find(
    (range) => prefix >= range.start && prefix <= range.end,
  )?.reason;
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

export const StoreRangeReason = {
  RESTRICTED: 'Restricted circulation',
  COUPON: 'Coupon',
  REFUND: 'Refund receipt',
} as const;

export type StoreRangeReason =
  (typeof StoreRangeReason)[keyof typeof StoreRangeReason];

interface StoreRange {
  start: number;
  end: number;
  reason: StoreRangeReason;
}

const storeRangeTable: Readonly<StoreRange[]> = [
  { start: 20, end: 29, reason: StoreRangeReason.RESTRICTED },
  { start: 40, end: 49, reason: StoreRangeReason.RESTRICTED },
  { start: 200, end: 299, reason: StoreRangeReason.RESTRICTED },
  { start: 50, end: 59, reason: StoreRangeReason.COUPON },
  { start: 981, end: 984, reason: StoreRangeReason.COUPON },
  { start: 990, end: 999, reason: StoreRangeReason.COUPON },
  { start: 980, end: 980, reason: StoreRangeReason.REFUND },
];
