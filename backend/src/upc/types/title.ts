import { Edition } from '@/upc/types/edition';
import { Column, Entity, OneToMany, PrimaryColumn } from 'typeorm';

@Entity('titles')
export class Title {
  @PrimaryColumn({ type: 'text', name: 'tmdb_id' })
  tmdbId: string;

  @PrimaryColumn({
    type: 'enum',
    enum: ['movie', 'tv'],
    enumName: 'kind_enum',
  })
  kind: 'movie' | 'tv';

  @Column({ type: 'text' })
  name: string;

  @Column({ type: 'int', nullable: true })
  year: number | undefined;

  @Column({ type: 'text', nullable: true, name: 'imdb_id' })
  imdbId: string | undefined;

  @Column({ type: 'text', nullable: true, name: 'poster_path' })
  posterPath: string | undefined;

  @Column({ type: 'jsonb', select: false })
  raw: object;

  @OneToMany(() => Edition, (edition) => edition.title)
  editions: Edition[];
}

export type TitleResponse = Omit<Title, 'raw' | 'posterPath' | 'editions'> & {
  posterURL: string | undefined;
};
