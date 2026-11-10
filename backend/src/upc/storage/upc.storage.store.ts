import { Edition, EditionResponse } from '@/upc/types/edition';
import { Title } from '@/upc/types/title';

export abstract class EditionStore {
  abstract findEditionByGTIN(gtin: string): Promise<EditionResponse | null>;
  abstract saveEdition(edition: Edition): Promise<void>;
  abstract saveTitle(title: Title): Promise<void>;
  abstract recordUnresolvedGTIN(gtin: string): Promise<void>;
  abstract findFullEditionByGTIN(gtin: string): Promise<Edition | null>;
}
