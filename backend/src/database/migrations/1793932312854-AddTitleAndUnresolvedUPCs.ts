import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddTitleAndUnresolvedUPCs1793932312854 implements MigrationInterface {
  name = 'AddTitleAndUnresolvedUPCs1793932312854';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TYPE "public"."kind_enum" AS ENUM('movie', 'tv')`,
    );
    await queryRunner.query(
      `CREATE TABLE "titles" ("tmdb_id" text NOT NULL, "kind" "public"."kind_enum" NOT NULL, "name" text NOT NULL, "year" integer, "imdb_id" text, "poster_path" text, "raw" jsonb NOT NULL, CONSTRAINT "PK_b64d5be4611e27b8777a937e427" PRIMARY KEY ("tmdb_id", "kind"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "unresolved_upcs" ("gtin" character varying(13) NOT NULL, "first_seen_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "last_seen_at" TIMESTAMP WITH TIME ZONE NOT NULL, CONSTRAINT "PK_1d14f4e6c90309845110fea598b" PRIMARY KEY ("gtin"))`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "imdbId" TO "imdb_id"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "enrichedTitle" TO "enriched_title"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "discContents" TO "disc_contents"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "masterResolution" TO "master_resolution"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "releaseDate" TO "release_date"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "coverImageURL" TO "cover_image_url"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "hasDigital" TO "has_digital"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "barcodesUpc" TO "upc"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "barcodesEan" TO "ean"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "packagingSteelbook" TO "steelbook"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "packagingSlipcover" TO "slipcover"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "packagingMemorabilia" TO "memorabilia"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "editionFlagsLimited" TO "limited"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "editionFlagsCollector" TO "collector"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "editionFlagsSpecial" TO "special"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "editionFlagsAnniversary" TO "anniversary"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "editionFlagsBoxset" TO "boxset"`,
    );
    await queryRunner.query(
      `ALTER TYPE "public"."editions_masterresolution_enum" RENAME TO "editions_master_resolution_enum"`,
    );
    await queryRunner.query(`ALTER TABLE "editions" ADD "raw" jsonb NOT NULL`);
    await queryRunner.query(
      `ALTER TABLE "editions" ADD "normalizer_version" integer NOT NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" ADD "fetched_at" TIMESTAMP WITH TIME ZONE NOT NULL`,
    );
    await queryRunner.query(`ALTER TABLE "editions" ADD "title_tmdb_id" text`);
    await queryRunner.query(
      `ALTER TABLE "editions" ADD "title_kind" "public"."kind_enum"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" ALTER COLUMN "kind" TYPE "public"."kind_enum" USING "kind"::"text"::"public"."kind_enum"`,
    );
    await queryRunner.query(`DROP TYPE "public"."editions_kind_enum"`);
    await queryRunner.query(
      `ALTER TABLE "editions" ADD CONSTRAINT "FK_9b521b8497dbed2f101a4577962" FOREIGN KEY ("title_tmdb_id", "title_kind") REFERENCES "titles"("tmdb_id","kind") ON DELETE SET NULL ON UPDATE NO ACTION`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "editions" DROP CONSTRAINT "FK_9b521b8497dbed2f101a4577962"`,
    );
    await queryRunner.query(
      `CREATE TYPE "public"."editions_kind_enum" AS ENUM('movie', 'tv')`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" ALTER COLUMN "kind" TYPE "public"."editions_kind_enum" USING "kind"::"text"::"public"."editions_kind_enum"`,
    );
    await queryRunner.query(`ALTER TABLE "editions" DROP COLUMN "title_kind"`);
    await queryRunner.query(
      `ALTER TABLE "editions" DROP COLUMN "title_tmdb_id"`,
    );
    await queryRunner.query(`ALTER TABLE "editions" DROP COLUMN "fetched_at"`);
    await queryRunner.query(
      `ALTER TABLE "editions" DROP COLUMN "normalizer_version"`,
    );
    await queryRunner.query(`ALTER TABLE "editions" DROP COLUMN "raw"`);
    await queryRunner.query(
      `ALTER TYPE "public"."editions_master_resolution_enum" RENAME TO "editions_masterresolution_enum"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "boxset" TO "editionFlagsBoxset"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "anniversary" TO "editionFlagsAnniversary"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "special" TO "editionFlagsSpecial"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "collector" TO "editionFlagsCollector"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "limited" TO "editionFlagsLimited"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "memorabilia" TO "packagingMemorabilia"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "slipcover" TO "packagingSlipcover"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "steelbook" TO "packagingSteelbook"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "ean" TO "barcodesEan"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "upc" TO "barcodesUpc"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "has_digital" TO "hasDigital"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "cover_image_url" TO "coverImageURL"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "release_date" TO "releaseDate"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "master_resolution" TO "masterResolution"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "disc_contents" TO "discContents"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "enriched_title" TO "enrichedTitle"`,
    );
    await queryRunner.query(
      `ALTER TABLE "editions" RENAME COLUMN "imdb_id" TO "imdbId"`,
    );
    await queryRunner.query(`DROP TABLE "unresolved_upcs"`);
    await queryRunner.query(`DROP TABLE "titles"`);
    await queryRunner.query(`DROP TYPE "public"."kind_enum"`);
  }
}
