-- ============================================
-- SETUP COMPLETO SUPABASE – ELEVAR LIQUIDACIÓN
-- ============================================
-- Ejecutá ESTE ÚNICO SCRIPT en Supabase → SQL Editor (Run).
-- Borra las tablas existentes y las recrea con el esquema que usa la app.
-- Si tenés datos que quieras conservar, hacé backup antes.
-- ============================================

-- 1. BORRAR TABLAS EXISTENTES (orden por dependencias)
DROP TABLE IF EXISTS liquidaciones CASCADE;
DROP TABLE IF EXISTS empleados CASCADE;
DROP TABLE IF EXISTS empresas CASCADE;
DROP TABLE IF EXISTS syncra_entities CASCADE;
DROP TABLE IF EXISTS maestro_paritarias CASCADE;

-- 2. FUNCIÓN updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. TABLA empresas
CREATE TABLE empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  razon_social TEXT NOT NULL,
  cuit TEXT NOT NULL UNIQUE,
  domicilio TEXT,
  convenio_id TEXT,
  convenio_nombre TEXT,
  convenio_personalizado BOOLEAN DEFAULT false,
  logo_path TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_empresas_cuit ON empresas (cuit);
CREATE INDEX idx_empresas_razon_social ON empresas (razon_social);
CREATE TRIGGER update_empresas_updated_at
  BEFORE UPDATE ON empresas FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- 4. TABLA empleados
CREATE TABLE empleados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID REFERENCES empresas(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  categoria TEXT,
  sueldo_basico DECIMAL(14,2) DEFAULT 0,
  fecha_ingreso DATE,
  lugar_pago TEXT,
  codigo_rnos TEXT,
  tipo TEXT CHECK (tipo IN ('docente', 'sanidad', 'general')) DEFAULT 'general',
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_empleados_empresa ON empleados (empresa_id);
CREATE INDEX idx_empleados_nombre ON empleados (nombre);
CREATE INDEX idx_empleados_tipo ON empleados (tipo);
CREATE TRIGGER update_empleados_updated_at
  BEFORE UPDATE ON empleados FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- 5. TABLA liquidaciones
CREATE TABLE liquidaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID REFERENCES empresas(id) ON DELETE SET NULL,
  empresa_nombre TEXT,
  empleado_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
  empleado_nombre TEXT,
  periodo TEXT NOT NULL,
  fecha_pago TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('docente', 'sanidad', 'general')),
  sueldo_basico DECIMAL(14,2) DEFAULT 0,
  dias_trabajados INTEGER DEFAULT 30,
  cantidad_horas_extras_50 INTEGER DEFAULT 0,
  cantidad_horas_extras_100 INTEGER DEFAULT 0,
  horas_mensuales_divisor DECIMAL(5,2) DEFAULT 173.0,
  presentismo_activo BOOLEAN DEFAULT true,
  dias_inasistencia INTEGER DEFAULT 0,
  porcentaje_presentismo DECIMAL(5,2) DEFAULT 8.33,
  vacaciones_activas BOOLEAN DEFAULT false,
  dias_vacaciones INTEGER DEFAULT 0,
  monto_vacaciones DECIMAL(14,2) DEFAULT 0,
  plus_vacacional DECIMAL(14,2) DEFAULT 0,
  premios DECIMAL(14,2) DEFAULT 0,
  conceptos_no_remunerativos DECIMAL(14,2) DEFAULT 0,
  kilometros_recorridos INTEGER DEFAULT 0,
  dias_viaticos_comida INTEGER DEFAULT 0,
  dias_pernocte INTEGER DEFAULT 0,
  afiliado_sindical BOOLEAN DEFAULT false,
  sueldo_bruto DECIMAL(14,2) DEFAULT 0,
  sueldo_neto DECIMAL(14,2) DEFAULT 0,
  total_deducciones DECIMAL(14,2) DEFAULT 0,
  total_no_remunerativo DECIMAL(14,2) DEFAULT 0,
  conceptos_remunerativos JSONB DEFAULT '{}',
  conceptos_no_remunerativos_adicionales JSONB DEFAULT '{}',
  deducciones_adicionales JSONB DEFAULT '{}',
  datos JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_liquidaciones_empresa ON liquidaciones (empresa_id);
CREATE INDEX idx_liquidaciones_empleado ON liquidaciones (empleado_id);
CREATE INDEX idx_liquidaciones_periodo ON liquidaciones (periodo);
CREATE INDEX idx_liquidaciones_tipo ON liquidaciones (tipo);
CREATE INDEX idx_liquidaciones_created ON liquidaciones (created_at DESC);
CREATE TRIGGER update_liquidaciones_updated_at
  BEFORE UPDATE ON liquidaciones FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- 6. TABLA syncra_entities (instituciones, etc.)
CREATE TABLE syncra_entities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  key TEXT NOT NULL,
  data JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT syncra_entities_type_key_unique UNIQUE (type, key)
);
CREATE INDEX idx_syncra_entities_type_key ON syncra_entities (type, key);

-- 7. ROW LEVEL SECURITY – permitir anon para que la app funcione sin auth
ALTER TABLE empresas ENABLE ROW LEVEL SECURITY;
ALTER TABLE empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE liquidaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE syncra_entities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_empresas_all" ON empresas;
CREATE POLICY "anon_empresas_all" ON empresas FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_empleados_all" ON empleados;
CREATE POLICY "anon_empleados_all" ON empleados FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_liquidaciones_all" ON liquidaciones;
CREATE POLICY "anon_liquidaciones_all" ON liquidaciones FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon_full" ON syncra_entities;
DROP POLICY IF EXISTS "anon_syncra_all" ON syncra_entities;
CREATE POLICY "anon_syncra_all" ON syncra_entities FOR ALL TO anon USING (true) WITH CHECK (true);

-- 8. TABLA maestro_paritarias (Centralización de aumentos docentes)
CREATE TABLE maestro_paritarias (
  jurisdiccion TEXT PRIMARY KEY,
  nombre_mostrar TEXT NOT NULL,
  valor_indice DECIMAL(14,4) NOT NULL,
  piso_salarial DECIMAL(14,2) DEFAULT 0,
  monto_fonid DECIMAL(14,2) DEFAULT 0,
  monto_conectividad DECIMAL(14,2) DEFAULT 0,
  porcentaje_aporte_jub DECIMAL(5,2) DEFAULT 11,
  porcentaje_aporte_os DECIMAL(5,2) DEFAULT 3,
  fuente_legal TEXT,
  metadata JSONB DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE maestro_paritarias ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_paritarias_read" ON maestro_paritarias FOR SELECT TO anon USING (true);
CREATE POLICY "anon_paritarias_all" ON maestro_paritarias FOR ALL TO anon USING (true) WITH CHECK (true);

-- Listo. Ejecutá este script una sola vez y probá la app.
