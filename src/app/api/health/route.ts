import { NextResponse } from "next/server";

/**
 * GET /api/health
 * Used by ALB and ECS container health checks.
 */
export async function GET() {
  return NextResponse.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV ?? "unknown",
  });
}
