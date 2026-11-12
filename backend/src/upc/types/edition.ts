import { Barcodes } from '@/upc/types/barcodes';
import { EditionFlags } from '@/upc/types/edition-flags';
import { HDRFormat } from '@/upc/types/hdrformat';
import { Packaging } from '@/upc/types/packaging';
import { Title, TitleResponse } from '@/upc/types/title';
import { Column, Entity, JoinColumn, ManyToOne, PrimaryColumn } from 'typeorm';

@Entity('editions')
export class Edition {
  @PrimaryColumn({ type: 'varchar', length: 13, name: 'edition_id' })
  id: string;

  @Column(() => Barcodes, { prefix: false })
  barcodes: Barcodes;

  @Column({ type: 'text', nullable: true })
  asin: string | undefined;

  @Column({ type: 'text', nullable: true, name: 'imdb_id' })
  imdbId: string | undefined;

  @Column({ type: 'text', name: 'upc_title' })
  upcTitle: string;

  @Column({ type: 'text', nullable: true, name: 'enriched_title' })
  enrichedTitle: string | undefined;

  @Column({
    type: 'enum',
    enum: ['movie', 'tv'],
    enumName: 'kind_enum',
    nullable: true,
  })
  kind: 'movie' | 'tv' | undefined;

  @Column({ type: 'int', nullable: true })
  year: number | undefined;

  @Column({ type: 'enum', enum: ['DVD', 'Blu-ray', '4K UHD'], nullable: true })
  format: DiscFormat | undefined;

  @Column({ type: 'jsonb', nullable: true, name: 'disc_contents' })
  discContents: DiscContents[] | undefined;

  @Column({ type: 'enum', enum: HDRFormat, array: true, nullable: true })
  hdr: HDRFormat[] | undefined;

  @Column(() => Packaging, { prefix: false })
  packaging: Packaging;

  @Column(() => EditionFlags, { prefix: false })
  editionFlags: EditionFlags;

  @Column({
    type: 'enum',
    enum: ['native', 'upscaled'],
    nullable: true,
    name: 'master_resolution',
  })
  masterResolution: 'native' | 'upscaled' | undefined;

  @Column({ type: 'text', nullable: true, name: 'release_date' })
  releaseDate: string | undefined; //iso-8601 formatted date string (YYYY-MM-DD)

  @Column({ type: 'text', nullable: true })
  distributor: string | undefined;

  @Column({ type: 'text', nullable: true })
  country: string | undefined;

  @Column({ type: 'text', nullable: true, name: 'cover_image_url' })
  coverImageURL: string | undefined;

  @Column({ type: 'int', nullable: true })
  runtime: number | undefined; //minutes

  @Column({ type: 'text', nullable: true })
  audio: string | undefined;

  @Column('text', { array: true, nullable: true })
  subtitles: string[] | undefined;

  @Column({ type: 'boolean', nullable: true, name: 'has_digital' })
  hasDigital: boolean | undefined;

  @Column({ type: 'jsonb', select: false })
  raw: object;

  @Column({ type: 'int', name: 'normalizer_version', select: false })
  normalizerVersion: number;

  @Column({ type: 'timestamptz', name: 'fetched_at', select: false })
  fetchedAt: Date;

  @ManyToOne(() => Title, (title) => title.editions, {
    nullable: true,
    onDelete: 'SET NULL',
  })
  @JoinColumn([
    { name: 'title_tmdb_id', referencedColumnName: 'tmdbId' },
    { name: 'title_kind', referencedColumnName: 'kind' },
  ])
  title: Title | undefined;
}

export class DiscContents {
  format: DiscFormat;
  region: 'Region free' | string[] | undefined;
}

export type DiscFormat = 'DVD' | 'Blu-ray' | '4K UHD';

export type DiscContent = NonNullable<Edition['discContents']>[number];

export type EditionResponse =
  | (Omit<Edition, 'raw' | 'normalizerVersion' | 'fetchedAt' | 'title'> & {
      title: TitleResponse;
      unmatchedTitle: false;
    })
  | (Omit<Edition, 'raw' | 'normalizerVersion' | 'fetchedAt' | 'title'> & {
      title?: undefined;
      unmatchedTitle: true;
    });
