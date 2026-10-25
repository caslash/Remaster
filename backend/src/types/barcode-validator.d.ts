declare module 'barcode-validator' {
  function validateBarcode(barcode: string | null): boolean;
  export = validateBarcode;
}
