import { Column } from 'typeorm';

export class EditionFlags {
  @Column({ type: 'boolean', nullable: true })
  limited: boolean | undefined;

  @Column({ type: 'boolean', nullable: true })
  collector: boolean | undefined;

  @Column({ type: 'boolean', nullable: true })
  special: boolean | undefined;

  @Column({ type: 'boolean', nullable: true })
  anniversary: boolean | undefined;

  @Column({ type: 'boolean', nullable: true })
  boxset: boolean | undefined;
}
