import { Column, CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

@Entity('unresolved_upcs')
export class UnresolvedUPC {
  @PrimaryColumn({ type: 'varchar', length: 13 })
  gtin: string;

  @CreateDateColumn({ type: 'timestamptz', name: 'first_seen_at' })
  firstSeenAt: Date;

  @Column({ type: 'timestamptz', name: 'last_seen_at' })
  lastSeenAt: Date;
}
