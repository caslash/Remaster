export type Edition = {
  id: string;
  barcodes: {
    upc: string | undefined;
    ean: string | undefined;
  };
  asin: string | undefined;
  imdbId: string | undefined;
  title: string;
  enrichedTitle: string | undefined;
  kind: 'movie' | 'tv' | undefined;
  year: number | undefined;
  format: DiscFormat | undefined;
  discContents:
    | {
        format: DiscFormat;
        region: 'Region free' | string[] | undefined;
      }[]
    | undefined;
  hdr: HDRFormat[] | undefined;
  packaging: {
    steelbook: boolean | undefined;
    slipcover: boolean | undefined;
    memorabilia: boolean | undefined;
  };
  editionFlags: {
    limited: boolean | undefined;
    collector: boolean | undefined;
    special: boolean | undefined;
    anniversary: boolean | undefined;
    boxset: boolean | undefined;
  };
  masterResolution: 'native' | 'upscaled' | undefined;
  releaseDate: string | undefined; //iso-8601 formatted date string (YYYY-MM-DD)
  distributor: string | undefined;
  country: string | undefined;
  coverImageURL: string | undefined;
  runtime: number | undefined; //minutes
  audio: string | undefined;
  subtitles: string[] | undefined;
  hasDigital: boolean | undefined;
};

export type DiscFormat = 'DVD' | 'Blu-ray' | '4K UHD';
export type HDRFormat = 'HDR10' | 'HDR10+' | 'Dolby Vision';
