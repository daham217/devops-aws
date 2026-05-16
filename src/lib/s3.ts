import { S3Client } from "@aws-sdk/client-s3";

/**
 * In production (ECS Fargate), the SDK automatically uses the IAM task role
 * via the container credentials endpoint — no static keys needed.
 *
 * In local development, it falls back to AWS_ACCESS_KEY_ID /
 * AWS_SECRET_ACCESS_KEY from .env.local if present.
 */
export const s3Client = new S3Client({
  region: process.env.AWS_REGION ?? "us-east-1",
});

export const S3_BUCKET = process.env.AWS_S3_BUCKET!;
