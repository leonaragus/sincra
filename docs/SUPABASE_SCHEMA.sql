-- ============================================
-- ESQUEMA COMPLETO PARA ELEVAR LIQUIDACIÓN
-- ============================================

-- 1. TABLA: empresas
CREATE TABLE IF NOT EXISTS empresas (
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

CREATE INDEX IF NOT EXISTS idx_empresas_cuit ON empresas (cuit);
CREATE INDEX IF NOT EXISTS idx_empresas_razon_social ON empresas (razon_social);

-- 2. TABLA: empleados
CREATE TABLE IF NOT EXISTS empleados (
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

CREATE INDEX IF NOT EXISTS idx_empleados_empresa ON empleados (empresa_id);
CREATE INDEX IF NOT EXISTS idx_empleados_nombre ON empleados (nombre);
CREATE INDEX IF NOT EXISTS idx_empleados_tipo ON empleados (tipo);

-- 3. TABLA: liquidaciones (mejorada)
CREATE TABLE IF NOT EXISTS liquidaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID REFERENCES empresas(id) ON DELETE SET NULL,
  empresa_nombre TEXT,
  empleado_id UUID REFERENCES empleados(id) ON DELETE SET NULL,
  empleado_nombre TEXT,
  periodo TEXT NOT NULL,
  fecha_pago TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('docente', 'sanidad', 'general')),
  
  -- Datos básicos
  sueldo_basico DECIMAL(14,2) DEFAULT 0,
  dias_trabajados INTEGER DEFAULT 30,
  
  -- Horas extras
  cantidad_horas_extras_50 INTEGER DEFAULT 0,
  cantidad_horas_extras_100 INTEGER DEFAULT 0,
  horas_mensuales_divisor DECIMAL(5,2) DEFAULT 173.0,
  
  -- Presentismo
  presentismo_activo BOOLEAN DEFAULT true,
  dias_inasistencia INTEGER DEFAULT 0,
  porcentaje_presentismo DECIMAL(5,2) DEFAULT 8.33,
  
  -- Vacaciones
  vacaciones_activas BOOLEAN DEFAULT false,
  dias_vacaciones INTEGER DEFAULT 0,
  monto_vacaciones DECIMAL(14,2) DEFAULT 0,
  plus_vacacional DECIMAL(14,2) DEFAULT 0,
  
  -- Conceptos adicionales
  premios DECIMAL(14,2) DEFAULT 0,
  conceptos_no_remunerativos DECIMAL(14,2) DEFAULT 0,
  kilometros_recorridos INTEGER DEFAULT 0,
  dias_viaticos_comida INTEGER DEFAULT 0,
  dias_pernocte INTEGER DEFAULT 0,
  
  -- Afiliación sindical
  afiliado_sindical BOOLEAN DEFAULT false,
  
  -- Totales calculados
  sueldo_bruto DECIMAL(14,2) DEFAULT 0,
  sueldo_neto DECIMAL(14,2) DEFAULT 0,
  total_deducciones DECIMAL(14,2) DEFAULT 0,
  total_no_remunerativo DECIMAL(14,2) DEFAULT 0,
  
  -- Datos adicionales en JSONB
  conceptos_remunerativos JSONB DEFAULT '{}',
  conceptos_no_remunerativos_adicionales JSONB DEFAULT '{}',
  deducciones_adicionales JSONB DEFAULT '{}',
  datos JSONB DEFAULT '{}',
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_liquidaciones_empresa ON liquidaciones (empresa_id);
CREATE INDEX IF NOT EXISTS idx_liquidaciones_empleado ON liquidaciones (empleado_id);
CREATE INDEX IF NOT EXISTS idx_liquidaciones_periodo ON liquidaciones (periodo);
CREATE INDEX IF NOT EXISTS idx_liquidaciones_tipo ON liquidaciones (tipo);
CREATE INDEX IF NOT EXISTS idx_liquidaciones_created ON liquidaciones (created_at DESC);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Habilitar RLS en todas las tablas
ALTER TABLE empresas ENABLE ROW LEVEL SECURITY;
ALTER TABLE empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE liquidaciones ENABLE ROW LEVEL SECURITY;

-- Políticas: permitir todo para anon (ajustar cuando agregues autenticación)
CREATE POLICY "anon_empresas_all" ON empresas FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_empleados_all" ON empleados FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_liquidaciones_all" ON liquidaciones FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- FUNCIONES ÚTILES
-- ============================================

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_empresas_updated_at BEFORE UPDATE ON empresas
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_empleados_updated_at BEFORE UPDATE ON empleados
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_liquidaciones_updated_at BEFORE UPDATE ON liquidaciones
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
