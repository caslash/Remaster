import { BarcodeShape } from '@/upc/types/barcode-shape';
import { DiscContent, DiscFormat } from '@/upc/types/edition';
import { BadRequestException } from '@nestjs/common';
import { isValid, upcE } from 'gtin';

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

export function isValidString(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.toLowerCase() !== 'null' &&
    value.trim().length > 0
  );
}

export function getBoolean(value: unknown): boolean | undefined {
  if (typeof value === 'boolean') return value;
  if (!isValidString(value)) return;

  const valueString = value.toLowerCase();

  return valueString === 'true'
    ? true
    : valueString === 'false'
      ? false
      : undefined;
}

export interface DiscCount {
  count: number;
  capacity: string;
}

export function parseDiscCounts(discs: string): DiscCount[] | undefined {
  const breakdown = Array.from(discs.matchAll(/\(([^()]*)\)/g)).pop()?.[1];
  if (breakdown === undefined) return;

  const counts: DiscCount[] = [];
  for (const item of breakdown.split(',')) {
    const match = item.trim().match(/^(\d+)\s*(.*)$/);
    if (!match) return;
    counts.push({ count: Number(match[1]), capacity: match[2] });
  }

  return counts;
}

export function parseRegion(text: string): DiscContent['region'] {
  if (text.toLowerCase() === 'region free') return 'Region free';
  const codes = text.match(/^Region\s+(.+)$/)?.[1];
  if (!codes) return;

  return codes
    .split(',')
    .map((code) => code.trim())
    .filter((code) => code);
}

export type PlaybackResult =
  | { ok: true; discTypes: DiscContent[]; unknownRegions: string[] }
  | {
      ok: false;
      reason: 'unknown-format' | 'unlabelled-without-format';
      segment: string;
    };

export function parsePlayback(
  playback: string,
  discFormat: DiscFormat | undefined,
): PlaybackResult {
  const discTypes: DiscContent[] = [];
  const unknownRegions: string[] = [];

  const regionFor = (text: string): DiscContent['region'] => {
    const region = parseRegion(text);
    if (!region) unknownRegions.push(text);
    return region;
  };

  const segments = playback.split('|').map((segment) => segment.trim());
  for (const segment of segments) {
    if (!segment || /^\(.*\)$/.test(segment)) continue;

    const colonIndex = segment.indexOf(':');
    if (colonIndex === -1) {
      if (!discFormat)
        return { ok: false, reason: 'unlabelled-without-format', segment };
      discTypes.push({ format: discFormat, region: regionFor(segment) });
      continue;
    }

    const label = segment.slice(0, colonIndex).trim();
    const region = regionFor(segment.slice(colonIndex + 1).trim());
    if (label === '4K Blu-ray') {
      discTypes.push({ format: '4K UHD', region });
    } else if (label === '2K Blu-ray') {
      discTypes.push({ format: 'Blu-ray', region });
    } else {
      return { ok: false, reason: 'unknown-format', segment: label };
    }
  }

  return { ok: true, discTypes, unknownRegions };
}
