import { Column } from 'typeorm';

export class Packaging {
  @Column({ type: 'boolean', nullable: true })
  steelbook: boolean | undefined;

  @Column({ type: 'boolean', nullable: true })
  slipcover: boolean | undefined;

  @Column({ type: 'boolean', nullable: true })
  memorabilia: boolean | undefined;
}
