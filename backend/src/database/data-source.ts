import { Edition } from '@/upc/types/edition';
import * as dotenv from 'dotenv';
import { DataSource } from 'typeorm';

dotenv.config();

export const AppDataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: [Edition],
  migrations: ['src/database/migrations/*.ts'],
});
