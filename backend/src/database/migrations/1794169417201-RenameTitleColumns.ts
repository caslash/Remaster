import { MigrationInterface, QueryRunner } from 'typeorm';

export class RenameTitleColumns1794169417201 implements MigrationInterface {
  name = 'RenameTitleColumns1794169417201';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "title" TO "upc_title"`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "upc_title" TO "title"`,
    );
  }
}
