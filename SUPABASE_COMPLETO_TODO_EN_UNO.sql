-- ========================================================================
-- SCHEMA SUPABASE COMPLETO - TODO EN UNO
-- ========================================================================
-- EJECUTAR TODO DE UNA VEZ EN SQL EDITOR
-- ========================================================================

-- PASO 1: BORRAR TABLAS SI EXISTEN (LIMPIEZA)
DROP TABLE IF EXISTS cct_versiones CASCADE;
DROP TABLE IF EXISTS auditoria CASCADE;
DROP TABLE IF EXISTS historial_liquidaciones CASCADE;
DROP TABLE IF EXISTS usuarios_empresas CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS empresas CASCADE;
DROP TABLE IF EXISTS cct_robot_ejecuciones CASCADE;
DROP TABLE IF EXISTS cct_actualizaciones CASCADE;
DROP TABLE IF EXISTS cct_master CASCADE;
DROP TABLE IF EXISTS prestamos_cuotas CASCADE;
DROP TABLE IF EXISTS prestamos CASCADE;
DROP TABLE IF EXISTS presentismo CASCADE;
DROP TABLE IF EXISTS ausencias CASCADE;
DROP TABLE IF EXISTS f931_historial CASCADE;
DROP TABLE IF EXISTS conceptos_recurrentes CASCADE;
DROP TABLE IF EXISTS empleados CASCADE;

-- ========================================================================
-- PASO 2: CREAR TODAS LAS TABLAS
-- ========================================================================

CREATE TABLE empleados (
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

CREATE TABLE conceptos_recurrentes (
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

CREATE TABLE f931_historial (
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

CREATE TABLE ausencias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  tipo TEXT NOT NULL,
  fecha_desde DATE NOT NULL,
  fecha_hasta DATE NOT NULL,
  estado TEXT DEFAULT 'pendiente',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE presentismo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  dias_habiles INTEGER NOT NULL,
  dias_trabajados INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE prestamos (
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

CREATE TABLE prestamos_cuotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id UUID NOT NULL,
  numero_cuota INTEGER NOT NULL,
  monto DECIMAL NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  pagada BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE cct_master (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  sector TEXT,
  version_actual INTEGER DEFAULT 1,
  json_estructura JSONB,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE cct_actualizaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cct_codigo TEXT NOT NULL,
  version INTEGER NOT NULL,
  fecha_vigencia DATE NOT NULL,
  cambios JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE cct_robot_ejecuciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha_ejecucion TIMESTAMP DEFAULT NOW(),
  exitosa BOOLEAN NOT NULL,
  cct_procesados INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cuit TEXT UNIQUE NOT NULL,
  razon_social TEXT NOT NULL,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE usuarios (
  id UUID PRIMARY KEY,
  nombre_completo TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE usuarios_empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  empresa_id UUID NOT NULL,
  rol TEXT NOT NULL,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE historial_liquidaciones (
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

CREATE TABLE auditoria (
  id TEXT PRIMARY KEY,
  tipo TEXT NOT NULL,
  accion TEXT NOT NULL,
  entidad TEXT NOT NULL,
  fecha TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE cct_versiones (
  id TEXT PRIMARY KEY,
  cct_codigo TEXT NOT NULL,
  numero_version INTEGER DEFAULT 1,
  contenido JSONB NOT NULL,
  es_version_activa BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ========================================================================
-- PASO 3: CREAR ÍNDICES (SOLO EN COLUMNAS NO-PK Y NO-UNIQUE)
-- ========================================================================

-- Índices para empleados
CREATE INDEX idx_empleados_estado ON empleados(estado);
CREATE INDEX idx_empleados_provincia ON empleados(provincia);
CREATE INDEX idx_empleados_sector ON empleados(sector);

-- Índices para conceptos_recurrentes
CREATE INDEX idx_conceptos_empleado ON conceptos_recurrentes(empleado_cuil);
CREATE INDEX idx_conceptos_activo ON conceptos_recurrentes(activo);
CREATE INDEX idx_conceptos_categoria ON conceptos_recurrentes(categoria);

-- Índices para f931_historial
CREATE INDEX idx_f931_empresa ON f931_historial(empresa_cuit);
CREATE INDEX idx_f931_periodo ON f931_historial(periodo_anio, periodo_mes);

-- Índices para ausencias
CREATE INDEX idx_ausencias_empleado ON ausencias(empleado_cuil);
CREATE INDEX idx_ausencias_empresa ON ausencias(empresa_cuit);
CREATE INDEX idx_ausencias_estado ON ausencias(estado);

-- Índices para presentismo
CREATE INDEX idx_presentismo_empleado ON presentismo(empleado_cuil);
CREATE INDEX idx_presentismo_periodo ON presentismo(periodo_anio, periodo_mes);

-- Índices para prestamos
CREATE INDEX idx_prestamos_empleado ON prestamos(empleado_cuil);
CREATE INDEX idx_prestamos_estado ON prestamos(estado);

-- Índices para prestamos_cuotas
CREATE INDEX idx_cuotas_prestamo ON prestamos_cuotas(prestamo_id);

-- Índices para cct_master
CREATE INDEX idx_cct_sector ON cct_master(sector);
CREATE INDEX idx_cct_activo ON cct_master(activo);

-- Índices para usuarios_empresas
CREATE INDEX idx_user_empresas_user ON usuarios_empresas(user_id);
CREATE INDEX idx_user_empresas_empresa ON usuarios_empresas(empresa_id);

-- Índices para historial_liquidaciones
CREATE INDEX idx_historial_empleado ON historial_liquidaciones(empleado_cuil);
CREATE INDEX idx_historial_periodo ON historial_liquidaciones(anio DESC, mes DESC);
CREATE INDEX idx_historial_empresa ON historial_liquidaciones(empresa_cuit);

-- Índices para auditoria
CREATE INDEX idx_auditoria_tipo ON auditoria(tipo);
CREATE INDEX idx_auditoria_fecha ON auditoria(fecha DESC);

-- Índices para cct_versiones
CREATE INDEX idx_cct_versiones_codigo ON cct_versiones(cct_codigo);

-- ========================================================================
-- COMPLETADO: 15 TABLAS + 27 ÍNDICES CREADOS
-- ========================================================================
