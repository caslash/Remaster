import { Transform } from 'class-transformer';
import { IsString, MinLength } from 'class-validator';

export class SearchQueryDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @MinLength(2)
  q: string;
}
