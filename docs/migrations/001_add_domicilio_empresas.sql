-- Migración: agregar columna domicilio a empresas si no existe
-- Ejecutá esto en Supabase → SQL Editor si tenés el error:
-- "could not find the domicilio column of empresas in the schema cache"

ALTER TABLE empresas ADD COLUMN IF NOT EXISTS domicilio TEXT;
