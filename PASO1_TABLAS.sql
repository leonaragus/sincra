-- ========================================================================
-- PASO 1: CREAR SOLO LAS TABLAS (EJECUTAR PRIMERO)
-- ========================================================================

CREATE TABLE IF NOT EXISTS empleados (
  cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  nombre_completo TEXT NOT NULL,
  fecha_ingreso TIMESTAMP NOT NULL,
  categoria TEXT NOT NULL,
  provincia TEXT NOT NULL,
  estado TEXT DEFAULT 'activo',
  sector TEXT,
  cbu TEXT,
  codigo_rnos TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (cuil, empresa_cuit)
);

CREATE TABLE IF NOT EXISTS conceptos_recurrentes (
  id TEXT PRIMARY KEY,
  empleado_cuil TEXT NOT NULL,
  codigo TEXT NOT NULL,
  nombre TEXT NOT NULL,
  tipo TEXT NOT NULL,
  valor DECIMAL NOT NULL,
  categoria TEXT NOT NULL,
  activo BOOLEAN DEFAULT true,
  activo_desde TIMESTAMP NOT NULL,
  activo_hasta TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS f931_historial (
  id TEXT PRIMARY KEY,
  empresa_cuit TEXT NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  cantidad_empleados INTEGER NOT NULL,
  total_remuneraciones DECIMAL NOT NULL,
  total_aportes DECIMAL NOT NULL,
  total_contribuciones DECIMAL NOT NULL,
  contenido_archivo TEXT NOT NULL,
  fecha_generacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ausencias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  tipo TEXT NOT NULL,
  fecha_desde DATE NOT NULL,
  fecha_hasta DATE NOT NULL,
  estado TEXT DEFAULT 'pendiente',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS presentismo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  dias_habiles INTEGER NOT NULL,
  dias_trabajados INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS prestamos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  monto_total DECIMAL NOT NULL,
  cantidad_cuotas INTEGER NOT NULL,
  valor_cuota DECIMAL NOT NULL,
  cuotas_pagadas INTEGER DEFAULT 0,
  monto_pagado DECIMAL DEFAULT 0,
  fecha_otorgamiento DATE NOT NULL,
  estado TEXT DEFAULT 'activo',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS prestamos_cuotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id UUID NOT NULL,
  numero_cuota INTEGER NOT NULL,
  monto DECIMAL NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  pagada BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cct_master (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  sector TEXT,
  version_actual INTEGER DEFAULT 1,
  json_estructura JSONB,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cct_actualizaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cct_codigo TEXT NOT NULL,
  version INTEGER NOT NULL,
  fecha_vigencia DATE NOT NULL,
  cambios JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cct_robot_ejecuciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha_ejecucion TIMESTAMP DEFAULT NOW(),
  exitosa BOOLEAN NOT NULL,
  cct_procesados INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cuit TEXT UNIQUE NOT NULL,
  razon_social TEXT NOT NULL,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY,
  nombre_completo TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS usuarios_empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  empresa_id UUID NOT NULL,
  rol TEXT NOT NULL,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS historial_liquidaciones (
  id TEXT PRIMARY KEY,
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  mes INTEGER NOT NULL,
  anio INTEGER NOT NULL,
  periodo TEXT NOT NULL,
  tipo TEXT DEFAULT 'mensual',
  sueldo_basico DECIMAL DEFAULT 0,
  total_bruto_remunerativo DECIMAL DEFAULT 0,
  total_aportes DECIMAL DEFAULT 0,
  neto_a_cobrar DECIMAL DEFAULT 0,
  fecha_liquidacion TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auditoria (
  id TEXT PRIMARY KEY,
  tipo TEXT NOT NULL,
  accion TEXT NOT NULL,
  entidad TEXT NOT NULL,
  fecha TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cct_versiones (
  id TEXT PRIMARY KEY,
  cct_codigo TEXT NOT NULL,
  numero_version INTEGER DEFAULT 1,
  contenido JSONB NOT NULL,
  es_version_activa BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ========================================================================
-- PASO 1 COMPLETADO - 15 TABLAS CREADAS
-- AHORA EJECUTA PASO2_INDICES.sql
-- ========================================================================
