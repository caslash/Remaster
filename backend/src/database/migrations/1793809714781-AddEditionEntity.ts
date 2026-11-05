import { MigrationInterface, QueryRunner } from "typeorm";

export class AddEditionEntity1793809714781 implements MigrationInterface {
    name = 'AddEditionEntity1793809714781'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."editions_kind_enum" AS ENUM('movie', 'tv')`);
        await queryRunner.query(`CREATE TYPE "public"."editions_format_enum" AS ENUM('DVD', 'Blu-ray', '4K UHD')`);
        await queryRunner.query(`CREATE TYPE "public"."editions_hdr_enum" AS ENUM('HDR10', 'HDR10+', 'Dolby Vision')`);
        await queryRunner.query(`CREATE TYPE "public"."editions_masterresolution_enum" AS ENUM('native', 'upscaled')`);
        await queryRunner.query(`CREATE TABLE "editions" ("edition_id" character varying(13) NOT NULL, "asin" text, "imdbId" text, "title" text NOT NULL, "enrichedTitle" text, "kind" "public"."editions_kind_enum", "year" integer, "format" "public"."editions_format_enum", "discContents" jsonb, "hdr" "public"."editions_hdr_enum" array, "masterResolution" "public"."editions_masterresolution_enum", "releaseDate" text, "distributor" text, "country" text, "coverImageURL" text, "runtime" integer, "audio" text, "subtitles" text array, "hasDigital" boolean, "barcodesUpc" text, "barcodesEan" text, "packagingSteelbook" boolean, "packagingSlipcover" boolean, "packagingMemorabilia" boolean, "editionFlagsLimited" boolean, "editionFlagsCollector" boolean, "editionFlagsSpecial" boolean, "editionFlagsAnniversary" boolean, "editionFlagsBoxset" boolean, CONSTRAINT "PK_11cde4db78a25164ca59d13aefb" PRIMARY KEY ("edition_id"))`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP TABLE "editions"`);
        await queryRunner.query(`DROP TYPE "public"."editions_masterresolution_enum"`);
        await queryRunner.query(`DROP TYPE "public"."editions_hdr_enum"`);
        await queryRunner.query(`DROP TYPE "public"."editions_format_enum"`);
        await queryRunner.query(`DROP TYPE "public"."editions_kind_enum"`);
    }

}
