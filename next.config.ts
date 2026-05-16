import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Required for Docker standalone build
  output: "standalone",

  images: {
    remotePatterns: [
      // Matches any S3 bucket in us-east-1 (covers dev and prod bucket names)
      new URL("https://*.s3.us-east-1.amazonaws.com/**"),
      // Also match any other region just in case
      new URL("https://*.s3.amazonaws.com/**"),
    ],
  },
};

export default nextConfig;
