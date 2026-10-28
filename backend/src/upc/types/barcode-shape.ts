export const BarcodeShape = {
  UPC_A: 'UPC-A',
  UPC_E: 'UPC-E',
  EAN_8: 'EAN-8',
  EAN_13: 'EAN-13',
} as const;

export type BarcodeShape = (typeof BarcodeShape)[keyof typeof BarcodeShape];
