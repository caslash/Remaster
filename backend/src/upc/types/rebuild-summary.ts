export type RebuildSummary = {
  targetVersion: number;
  foundEditions: number;
  rebuilt: number;
  changedMeanwhile: number;
  failedIds: string[];
  mismatchedIds: string[];
};
