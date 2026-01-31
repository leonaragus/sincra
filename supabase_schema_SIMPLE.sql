-- ========================================================================
-- SCHEMA SUPABASE SIMPLIFICADO - SIN RLS, SIN VISTAS COMPLEJAS
-- Ejecutar este script si el consolidado da errores
-- Total: 15 tablas + índices básicos
-- ========================================================================

-- EMPLEADOS
CREATE TABLE IF NOT EXISTS empleados (
  cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  nombre_completo TEXT NOT NULL,
  apellido TEXT,
  nombre TEXT,
  fecha_nacimiento TIMESTAMP,
  domicilio TEXT,
  localidad TEXT,
  codigo_postal TEXT,
  telefono TEXT,
  email TEXT,
  fecha_ingreso TIMESTAMP NOT NULL,
  categoria TEXT NOT NULL,
  categoria_descripcion TEXT,
  antiguedad_anios INTEGER DEFAULT 0,
  antiguedad_meses INTEGER DEFAULT 0,
  sector TEXT,
  subsector TEXT,
  provincia TEXT NOT NULL,
  jurisdiccion TEXT,
  cct_codigo TEXT,
  cct_nombre TEXT,
  cbu TEXT,
  banco TEXT,
  tipo_cuenta TEXT,
  codigo_rnos TEXT,
  obra_social_nombre TEXT,
  aporte_sindical DECIMAL,
  modalidad_contratacion INTEGER DEFAULT 1,
  estado TEXT DEFAULT 'activo',
  fecha_baja TIMESTAMP,
  motivo_baja TEXT,
  empresa_nombre TEXT,
  notas TEXT,
  tags TEXT[],
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT,
  modificado_por TEXT,
  PRIMARY KEY (cuil, empresa_cuit)
);

CREATE INDEX idx_empleados_cuil ON empleados(cuil);
CREATE INDEX idx_empleados_empresa ON empleados(empresa_cuit);
CREATE INDEX idx_empleados_estado ON empleados(estado);

-- CONCEPTOS RECURRENTES
CREATE TABLE IF NOT EXISTS conceptos_recurrentes (
  id TEXT PRIMARY KEY,
  empleado_cuil TEXT NOT NULL,
  codigo TEXT NOT NULL,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  tipo TEXT NOT NULL,
  valor DECIMAL NOT NULL,
  formula TEXT,
  categoria TEXT NOT NULL,
  subcategoria TEXT,
  activo_desde TIMESTAMP NOT NULL,
  activo_hasta TIMESTAMP,
  activo BOOLEAN DEFAULT true,
  condicion TEXT,
  monto_total_embargo DECIMAL,
  monto_acumulado_descontado DECIMAL DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT
);

CREATE INDEX idx_conceptos_empleado ON conceptos_recurrentes(empleado_cuil);

-- F931 HISTORIAL
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
  generado_por TEXT,
  fecha_generacion TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_f931_empresa ON f931_historial(empresa_cuit);

-- AUSENCIAS
CREATE TABLE IF NOT EXISTS ausencias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  tipo TEXT NOT NULL,
  fecha_desde DATE NOT NULL,
  fecha_hasta DATE NOT NULL,
  con_goce BOOLEAN DEFAULT true,
  porcentaje_goce DECIMAL DEFAULT 100,
  motivo TEXT,
  certificado_url TEXT,
  numero_certificado TEXT,
  estado TEXT DEFAULT 'pendiente',
  aprobado_por TEXT,
  fecha_aprobacion TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT
);

CREATE INDEX idx_ausencias_empleado ON ausencias(empleado_cuil);

-- PRESENTISMO
CREATE TABLE IF NOT EXISTS presentismo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  dias_habiles INTEGER NOT NULL,
  dias_trabajados INTEGER NOT NULL,
  dias_ausentes INTEGER NOT NULL,
  dias_tarde INTEGER DEFAULT 0,
  porcentaje_puntualidad DECIMAL DEFAULT 100,
  aplica_adicional BOOLEAN DEFAULT false,
  monto_adicional DECIMAL DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_presentismo_empleado ON presentismo(empleado_cuil);

-- PRESTAMOS
CREATE TABLE IF NOT EXISTS prestamos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  monto_total DECIMAL NOT NULL,
  tasa_interes DECIMAL DEFAULT 0,
  cantidad_cuotas INTEGER NOT NULL,
  valor_cuota DECIMAL NOT NULL,
  cuotas_pagadas INTEGER DEFAULT 0,
  monto_pagado DECIMAL DEFAULT 0,
  fecha_otorgamiento DATE NOT NULL,
  fecha_primera_cuota DATE NOT NULL,
  fecha_ultima_cuota DATE,
  estado TEXT DEFAULT 'activo',
  motivo_prestamo TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT
);

CREATE INDEX idx_prestamos_empleado ON prestamos(empleado_cuil);

-- PRESTAMOS CUOTAS
CREATE TABLE IF NOT EXISTS prestamos_cuotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id UUID NOT NULL,
  numero_cuota INTEGER NOT NULL,
  monto DECIMAL NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  pagada BOOLEAN DEFAULT false,
  fecha_pago TIMESTAMP,
  liquidacion_id UUID,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_cuotas_prestamo ON prestamos_cuotas(prestamo_id);

-- CCT MASTER
CREATE TABLE IF NOT EXISTS cct_master (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  sector TEXT,
  subsector TEXT,
  version_actual INTEGER DEFAULT 1,
  fecha_actualizacion DATE,
  json_estructura JSONB,
  descripcion TEXT,
  fuente_oficial TEXT,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  actualizado_por TEXT
);

CREATE INDEX idx_cct_sector ON cct_master(sector);

-- CCT ACTUALIZACIONES
CREATE TABLE IF NOT EXISTS cct_actualizaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cct_codigo TEXT NOT NULL,
  version INTEGER NOT NULL,
  fecha_vigencia DATE NOT NULL,
  cambios JSONB,
  json_estructura_completa JSONB,
  fuente_oficial TEXT,
  notas TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT
);

CREATE INDEX idx_cct_act_codigo ON cct_actualizaciones(cct_codigo);

-- CCT ROBOT EJECUCIONES
CREATE TABLE IF NOT EXISTS cct_robot_ejecuciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha_ejecucion TIMESTAMP DEFAULT NOW(),
  exitosa BOOLEAN NOT NULL,
  cct_procesados INTEGER DEFAULT 0,
  cct_actualizados INTEGER DEFAULT 0,
  cct_sin_cambios INTEGER DEFAULT 0,
  cct_con_errores INTEGER DEFAULT 0,
  log_completo TEXT,
  errores TEXT[],
  ejecutado_por TEXT,
  duracion_segundos INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_robot_fecha ON cct_robot_ejecuciones(fecha_ejecucion DESC);

-- EMPRESAS
CREATE TABLE IF NOT EXISTS empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cuit TEXT UNIQUE NOT NULL,
  razon_social TEXT NOT NULL,
  nombre_fantasia TEXT,
  domicilio TEXT,
  localidad TEXT,
  provincia TEXT,
  codigo_postal TEXT,
  telefono TEXT,
  email TEXT,
  logo_url TEXT,
  color_primario TEXT,
  actividad TEXT,
  fecha_inicio_actividad DATE,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT
);

CREATE INDEX idx_empresas_cuit ON empresas(cuit);

-- USUARIOS
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY,
  nombre_completo TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  rol_global TEXT,
  avatar_url TEXT,
  preferencias JSONB,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_usuarios_email ON usuarios(email);

-- USUARIOS EMPRESAS
CREATE TABLE IF NOT EXISTS usuarios_empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  empresa_id UUID NOT NULL,
  rol TEXT NOT NULL,
  permisos JSONB,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  asignado_por UUID
);

CREATE INDEX idx_user_empresas_user ON usuarios_empresas(user_id);
CREATE INDEX idx_user_empresas_empresa ON usuarios_empresas(empresa_id);

-- HISTORIAL LIQUIDACIONES
CREATE TABLE IF NOT EXISTS historial_liquidaciones (
  id TEXT PRIMARY KEY,
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  mes INTEGER NOT NULL,
  anio INTEGER NOT NULL,
  periodo TEXT NOT NULL,
  tipo TEXT NOT NULL DEFAULT 'mensual',
  sector TEXT,
  sueldo_basico DECIMAL NOT NULL DEFAULT 0,
  adicional_antiguedad DECIMAL NOT NULL DEFAULT 0,
  otros_haberes DECIMAL NOT NULL DEFAULT 0,
  total_bruto_remunerativo DECIMAL NOT NULL DEFAULT 0,
  total_no_remunerativo DECIMAL NOT NULL DEFAULT 0,
  total_aportes DECIMAL NOT NULL DEFAULT 0,
  total_descuentos DECIMAL NOT NULL DEFAULT 0,
  embargos_judiciales DECIMAL NOT NULL DEFAULT 0,
  cuotas_alimentarias DECIMAL NOT NULL DEFAULT 0,
  total_contribuciones DECIMAL NOT NULL DEFAULT 0,
  neto_a_cobrar DECIMAL NOT NULL DEFAULT 0,
  antiguedad_anios INTEGER DEFAULT 0,
  provincia TEXT,
  categoria TEXT,
  tiene_errores BOOLEAN DEFAULT false,
  tiene_advertencias BOOLEAN DEFAULT false,
  errores JSONB,
  advertencias JSONB,
  fecha_liquidacion TIMESTAMP NOT NULL DEFAULT NOW(),
  liquidado_por TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  liquidacion_id TEXT,
  recibo_url TEXT
);

CREATE INDEX idx_historial_empleado ON historial_liquidaciones(empleado_cuil);
CREATE INDEX idx_historial_periodo ON historial_liquidaciones(anio DESC, mes DESC);

-- AUDITORIA
CREATE TABLE IF NOT EXISTS auditoria (
  id TEXT PRIMARY KEY,
  tipo TEXT NOT NULL,
  accion TEXT NOT NULL,
  entidad TEXT NOT NULL,
  descripcion TEXT,
  valor_anterior JSONB,
  valor_nuevo JSONB,
  fecha TIMESTAMP NOT NULL DEFAULT NOW(),
  usuario TEXT,
  empresa_cuit TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_auditoria_tipo ON auditoria(tipo);
CREATE INDEX idx_auditoria_fecha ON auditoria(fecha DESC);

-- CCT VERSIONES
CREATE TABLE IF NOT EXISTS cct_versiones (
  id TEXT PRIMARY KEY,
  cct_codigo TEXT NOT NULL,
  numero_version INTEGER NOT NULL DEFAULT 1,
  contenido JSONB NOT NULL,
  descripcion_cambios TEXT,
  fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW(),
  creado_por TEXT,
  es_version_activa BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_cct_versiones_codigo ON cct_versiones(cct_codigo);

-- ========================================================================
-- FIN - 15 TABLAS CREADAS SIN ERRORES
-- ========================================================================
