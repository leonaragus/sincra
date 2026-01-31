import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* Permitir acceso por IP en dev (evita 404 al usar dev:pruebas desde otra PC).
   * Si accedés desde otra PC y sigue 404, agregá su IP ej. "192.168.1.50" */
  allowedDevOrigins: [
    "localhost",
    "127.0.0.1",
    "0.0.0.0",
    "[::1]",
    "192.168.1.6",
    "192.168.1.15",
  ],
};

export default nextConfig;
