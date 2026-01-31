# Tabla `liquidaciones` en Supabase

Si aún no creaste la tabla, ejecutá en el **SQL Editor** de Supabase:

```sql
CREATE TABLE IF NOT EXISTS liquidaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id TEXT NOT NULL,
  empresa_nombre TEXT,
  empleado_id TEXT NOT NULL,
  empleado_nombre TEXT,
  periodo TEXT NOT NULL,
  fecha_pago TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('docente', 'sanidad', 'general')),
  sueldo_bruto DECIMAL(14,2) DEFAULT 0,
  sueldo_neto DECIMAL(14,2) DEFAULT 0,
  total_deducciones DECIMAL(14,2) DEFAULT 0,
  total_no_remunerativo DECIMAL(14,2) DEFAULT 0,
  datos JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_liquidaciones_empresa ON liquidaciones (empresa_id);
CREATE INDEX IF NOT EXISTS idx_liquidaciones_periodo ON liquidaciones (periodo);
CREATE INDEX IF NOT EXISTS idx_liquidaciones_created ON liquidaciones (created_at DESC);

-- RLS (opcional): permitir insert/select con anon por ahora
ALTER TABLE liquidaciones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_insert" ON liquidaciones FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_select" ON liquidaciones FOR SELECT TO anon USING (true);
```

Ajustá las políticas de RLS cuando integres autenticación.
