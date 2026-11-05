import { Barcodes } from '@/upc/types/barcodes';
import { EditionFlags } from '@/upc/types/edition-flags';
import { HDRFormat } from '@/upc/types/hdrformat';
import { Packaging } from '@/upc/types/packaging';
import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity('editions')
export class Edition {
  @PrimaryColumn({ type: 'varchar', length: 13, name: 'edition_id' })
  id: string;

  @Column(() => Barcodes)
  barcodes: Barcodes;

  @Column({ type: 'text', nullable: true })
  asin: string | undefined;

  @Column({ type: 'text', nullable: true })
  imdbId: string | undefined;

  @Column({ type: 'text' })
  title: string;

  @Column({ type: 'text', nullable: true })
  enrichedTitle: string | undefined;

  @Column({ type: 'enum', enum: ['movie', 'tv'], nullable: true })
  kind: 'movie' | 'tv' | undefined;

  @Column({ type: 'int', nullable: true })
  year: number | undefined;

  @Column({ type: 'enum', enum: ['DVD', 'Blu-ray', '4K UHD'], nullable: true })
  format: DiscFormat | undefined;

  @Column({ type: 'jsonb', nullable: true })
  discContents: DiscContents[] | undefined;

  @Column({ type: 'enum', enum: HDRFormat, array: true, nullable: true })
  hdr: HDRFormat[] | undefined;

  @Column(() => Packaging)
  packaging: Packaging;

  @Column(() => EditionFlags)
  editionFlags: EditionFlags;

  @Column({ type: 'enum', enum: ['native', 'upscaled'], nullable: true })
  masterResolution: 'native' | 'upscaled' | undefined;

  @Column({ type: 'text', nullable: true })
  releaseDate: string | undefined; //iso-8601 formatted date string (YYYY-MM-DD)

  @Column({ type: 'text', nullable: true })
  distributor: string | undefined;

  @Column({ type: 'text', nullable: true })
  country: string | undefined;

  @Column({ type: 'text', nullable: true })
  coverImageURL: string | undefined;

  @Column({ type: 'int', nullable: true })
  runtime: number | undefined; //minutes

  @Column({ type: 'text', nullable: true })
  audio: string | undefined;

  @Column('text', { array: true, nullable: true })
  subtitles: string[] | undefined;

  @Column({ type: 'boolean', nullable: true })
  hasDigital: boolean | undefined;
}

export class DiscContents {
  format: DiscFormat;
  region: 'Region free' | string[] | undefined;
}

export type DiscFormat = 'DVD' | 'Blu-ray' | '4K UHD';

export type DiscContent = NonNullable<Edition['discContents']>[number];
