import { Transform } from 'class-transformer';
import { IsString, MinLength } from 'class-validator';

export class SearchQueryDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MinLength(2)
  q: string;
}
