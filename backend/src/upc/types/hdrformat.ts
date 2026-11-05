export enum HDRFormat {
  HDR10 = 'HDR10',
  HDR10PLUS = 'HDR10+',
  DOLBYVISION = 'Dolby Vision',
}
export const HDR_FORMATS = HDRFormat;

export function isHDRFormat(format: unknown): format is HDRFormat {
  return (
    typeof format === 'string' &&
    format !== null &&
    !!Object.values(HDRFormat).find((hdr) => hdr === format)
  );
}
