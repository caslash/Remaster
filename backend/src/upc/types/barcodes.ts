import { Column } from 'typeorm';

export class Barcodes {
  @Column({ type: 'text', nullable: true })
  upc: string | undefined;

  @Column({ type: 'text', nullable: true })
  ean: string | undefined;
}
