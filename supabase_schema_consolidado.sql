-- ========================================================================
-- SCHEMA SUPABASE CONSOLIDADO - SPRINT 1 + 2 + 3 + 4 + 5
-- Ejecutar este script UNA SOLA VEZ al final de completar los sprints
-- Total: 15 tablas + índices + triggers + RLS + vistas + funciones
-- ========================================================================

-- ========================================
-- SPRINT 1: EMPLEADOS
-- ========================================
CREATE TABLE IF NOT EXISTS empleados (
  cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  
  -- Datos personales
  nombre_completo TEXT NOT NULL,
  apellido TEXT,
  nombre TEXT,
  fecha_nacimiento TIMESTAMP,
  domicilio TEXT,
  localidad TEXT,
  codigo_postal TEXT,
  telefono TEXT,
  email TEXT,
  
  -- Datos laborales
  fecha_ingreso TIMESTAMP NOT NULL,
  categoria TEXT NOT NULL,
  categoria_descripcion TEXT,
  antiguedad_anios INTEGER DEFAULT 0,
  antiguedad_meses INTEGER DEFAULT 0,
  sector TEXT,
  subsector TEXT,
  
  -- Ubicación
  provincia TEXT NOT NULL,
  jurisdiccion TEXT,
  
  -- CCT
  cct_codigo TEXT,
  cct_nombre TEXT,
  
  -- Bancarios
  cbu TEXT,
  banco TEXT,
  tipo_cuenta TEXT,
  
  -- Obra social
  codigo_rnos TEXT,
  obra_social_nombre TEXT,
  aporte_sindical DECIMAL,
  
  -- Modalidad (para F931)
  modalidad_contratacion INTEGER DEFAULT 1,
  
  -- Estado
  estado TEXT DEFAULT 'activo',
  fecha_baja TIMESTAMP,
  motivo_baja TEXT,
  
  -- Empresa
  empresa_nombre TEXT,
  
  -- Metadata
  notas TEXT,
  tags TEXT[],
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT,
  modificado_por TEXT,
  
  PRIMARY KEY (cuil, empresa_cuit)
);

CREATE INDEX IF NOT EXISTS idx_empleados_empresa ON empleados(empresa_cuit);
CREATE INDEX IF NOT EXISTS idx_empleados_cuil ON empleados(cuil);
CREATE INDEX IF NOT EXISTS idx_empleados_estado ON empleados(estado);
CREATE INDEX IF NOT EXISTS idx_empleados_provincia ON empleados(provincia);
CREATE INDEX IF NOT EXISTS idx_empleados_categoria ON empleados(categoria);
CREATE INDEX IF NOT EXISTS idx_empleados_sector ON empleados(sector);

-- ========================================
-- SPRINT 1: CONCEPTOS RECURRENTES
-- ========================================
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

CREATE INDEX IF NOT EXISTS idx_conceptos_empleado ON conceptos_recurrentes(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_conceptos_activo ON conceptos_recurrentes(activo);
CREATE INDEX IF NOT EXISTS idx_conceptos_categoria ON conceptos_recurrentes(categoria);
CREATE INDEX IF NOT EXISTS idx_conceptos_codigo ON conceptos_recurrentes(codigo);

-- ========================================
-- SPRINT 1: F931 HISTORIAL
-- ========================================
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
  fecha_generacion TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT unique_f931_periodo UNIQUE (empresa_cuit, periodo_anio, periodo_mes)
);

CREATE INDEX IF NOT EXISTS idx_f931_empresa ON f931_historial(empresa_cuit);
CREATE INDEX IF NOT EXISTS idx_f931_periodo ON f931_historial(periodo_anio, periodo_mes);

-- ========================================
-- SPRINT 2: AUSENCIAS
-- ========================================
CREATE TABLE IF NOT EXISTS ausencias (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  
  -- Tipo de ausencia
  tipo TEXT NOT NULL,
  fecha_desde DATE NOT NULL,
  fecha_hasta DATE NOT NULL,
  dias_totales INTEGER GENERATED ALWAYS AS (fecha_hasta - fecha_desde + 1) STORED,
  
  -- Remuneración
  con_goce BOOLEAN DEFAULT true,
  porcentaje_goce DECIMAL DEFAULT 100,
  
  -- Documentación
  motivo TEXT,
  certificado_url TEXT,
  numero_certificado TEXT,
  
  -- Estado
  estado TEXT DEFAULT 'pendiente',
  aprobado_por TEXT,
  fecha_aprobacion TIMESTAMP,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT,
  
  -- Constraints
  CONSTRAINT ausencias_fechas_check CHECK (fecha_hasta >= fecha_desde)
);

CREATE INDEX IF NOT EXISTS idx_ausencias_empleado ON ausencias(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_ausencias_empresa ON ausencias(empresa_cuit);
CREATE INDEX IF NOT EXISTS idx_ausencias_fechas ON ausencias(fecha_desde, fecha_hasta);
CREATE INDEX IF NOT EXISTS idx_ausencias_estado ON ausencias(estado);
CREATE INDEX IF NOT EXISTS idx_ausencias_tipo ON ausencias(tipo);

-- ========================================
-- SPRINT 2: PRESENTISMO
-- ========================================
CREATE TABLE IF NOT EXISTS presentismo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  
  -- Estadísticas
  dias_habiles INTEGER NOT NULL,
  dias_trabajados INTEGER NOT NULL,
  dias_ausentes INTEGER NOT NULL,
  dias_tarde INTEGER DEFAULT 0,
  
  -- Porcentajes
  porcentaje_asistencia DECIMAL GENERATED ALWAYS AS 
    (CASE WHEN dias_habiles > 0 THEN (dias_trabajados::DECIMAL / dias_habiles) * 100 ELSE 0 END) STORED,
  porcentaje_puntualidad DECIMAL DEFAULT 100,
  
  -- Resultado
  aplica_adicional BOOLEAN DEFAULT false,
  monto_adicional DECIMAL DEFAULT 0,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT unique_presentismo_periodo UNIQUE (empleado_cuil, periodo_anio, periodo_mes)
);

CREATE INDEX IF NOT EXISTS idx_presentismo_empleado ON presentismo(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_presentismo_periodo ON presentismo(periodo_anio, periodo_mes);

-- ========================================
-- SPRINT 2: PRÉSTAMOS
-- ========================================
CREATE TABLE IF NOT EXISTS prestamos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  
  -- Datos del préstamo
  monto_total DECIMAL NOT NULL CHECK (monto_total > 0),
  tasa_interes DECIMAL DEFAULT 0 CHECK (tasa_interes >= 0),
  cantidad_cuotas INTEGER NOT NULL CHECK (cantidad_cuotas > 0),
  valor_cuota DECIMAL NOT NULL CHECK (valor_cuota > 0),
  
  -- Progreso
  cuotas_pagadas INTEGER DEFAULT 0,
  monto_pagado DECIMAL DEFAULT 0,
  monto_restante DECIMAL GENERATED ALWAYS AS (monto_total - monto_pagado) STORED,
  
  -- Fechas
  fecha_otorgamiento DATE NOT NULL,
  fecha_primera_cuota DATE NOT NULL,
  fecha_ultima_cuota DATE,
  
  -- Estado
  estado TEXT DEFAULT 'activo',
  motivo_prestamo TEXT,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT
);

CREATE INDEX IF NOT EXISTS idx_prestamos_empleado ON prestamos(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_prestamos_estado ON prestamos(estado);

-- ========================================
-- SPRINT 2: PRÉSTAMOS CUOTAS
-- ========================================
CREATE TABLE IF NOT EXISTS prestamos_cuotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id UUID NOT NULL REFERENCES prestamos(id) ON DELETE CASCADE,
  
  -- Cuota
  numero_cuota INTEGER NOT NULL CHECK (numero_cuota > 0),
  monto DECIMAL NOT NULL CHECK (monto > 0),
  
  -- Período de descuento
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  
  -- Estado
  pagada BOOLEAN DEFAULT false,
  fecha_pago TIMESTAMP,
  liquidacion_id UUID,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT unique_prestamo_cuota UNIQUE (prestamo_id, numero_cuota)
);

CREATE INDEX IF NOT EXISTS idx_cuotas_prestamo ON prestamos_cuotas(prestamo_id);
CREATE INDEX IF NOT EXISTS idx_cuotas_periodo ON prestamos_cuotas(periodo_anio, periodo_mes);
CREATE INDEX IF NOT EXISTS idx_cuotas_pagada ON prestamos_cuotas(pagada);

-- ========================================
-- SPRINT 2: CCT MASTER (Biblioteca)
-- ========================================
CREATE TABLE IF NOT EXISTS cct_master (
  codigo TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  sector TEXT,
  subsector TEXT,
  
  -- Versión
  version_actual INTEGER DEFAULT 1,
  fecha_actualizacion DATE,
  
  -- Estructura (JSON)
  json_estructura JSONB,
  
  -- Metadata
  descripcion TEXT,
  fuente_oficial TEXT,
  activo BOOLEAN DEFAULT true,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  actualizado_por TEXT
);

CREATE INDEX IF NOT EXISTS idx_cct_sector ON cct_master(sector);
CREATE INDEX IF NOT EXISTS idx_cct_activo ON cct_master(activo);

-- ========================================
-- SPRINT 2: CCT ACTUALIZACIONES
-- ========================================
CREATE TABLE IF NOT EXISTS cct_actualizaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cct_codigo TEXT NOT NULL REFERENCES cct_master(codigo),
  
  version INTEGER NOT NULL,
  fecha_vigencia DATE NOT NULL,
  
  cambios JSONB,
  json_estructura_completa JSONB,
  
  fuente_oficial TEXT,
  notas TEXT,
  
  created_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT,
  
  CONSTRAINT unique_cct_version UNIQUE (cct_codigo, version)
);

CREATE INDEX IF NOT EXISTS idx_cct_act_codigo ON cct_actualizaciones(cct_codigo);
CREATE INDEX IF NOT EXISTS idx_cct_act_vigencia ON cct_actualizaciones(fecha_vigencia);

-- ========================================
-- SPRINT 2: CCT ROBOT EJECUCIONES
-- ========================================
CREATE TABLE IF NOT EXISTS cct_robot_ejecuciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Ejecución
  fecha_ejecucion TIMESTAMP DEFAULT NOW(),
  exitosa BOOLEAN NOT NULL,
  
  -- Resultados
  cct_procesados INTEGER DEFAULT 0,
  cct_actualizados INTEGER DEFAULT 0,
  cct_sin_cambios INTEGER DEFAULT 0,
  cct_con_errores INTEGER DEFAULT 0,
  
  -- Detalles
  log_completo TEXT,
  errores TEXT[],
  
  -- Metadata
  ejecutado_por TEXT,
  duracion_segundos INTEGER,
  
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_robot_fecha ON cct_robot_ejecuciones(fecha_ejecucion DESC);
CREATE INDEX IF NOT EXISTS idx_robot_exitosa ON cct_robot_ejecuciones(exitosa);

-- ========================================
-- SPRINT 2: EMPRESAS
-- ========================================
CREATE TABLE IF NOT EXISTS empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cuit TEXT UNIQUE NOT NULL,
  
  -- Datos básicos
  razon_social TEXT NOT NULL,
  nombre_fantasia TEXT,
  
  -- Contacto
  domicilio TEXT,
  localidad TEXT,
  provincia TEXT,
  codigo_postal TEXT,
  telefono TEXT,
  email TEXT,
  
  -- Configuración
  logo_url TEXT,
  color_primario TEXT,
  
  -- Legal
  actividad TEXT,
  fecha_inicio_actividad DATE,
  
  -- Estado
  activa BOOLEAN DEFAULT true,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT
);

CREATE INDEX IF NOT EXISTS idx_empresas_cuit ON empresas(cuit);
CREATE INDEX IF NOT EXISTS idx_empresas_activa ON empresas(activa);

-- ========================================
-- SPRINT 2: USUARIOS
-- ========================================
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Datos personales
  nombre_completo TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  
  -- Rol global
  rol_global TEXT,
  
  -- Preferencias
  avatar_url TEXT,
  preferencias JSONB,
  
  -- Estado
  activo BOOLEAN DEFAULT true,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_activo ON usuarios(activo);

-- ========================================
-- SPRINT 2: USUARIOS_EMPRESAS
-- ========================================
CREATE TABLE IF NOT EXISTS usuarios_empresas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  
  -- Rol en esta empresa
  rol TEXT NOT NULL,
  
  -- Permisos específicos
  permisos JSONB,
  
  -- Estado
  activo BOOLEAN DEFAULT true,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  asignado_por UUID REFERENCES usuarios(id),
  
  CONSTRAINT unique_user_empresa UNIQUE (user_id, empresa_id)
);

CREATE INDEX IF NOT EXISTS idx_user_empresas_user ON usuarios_empresas(user_id);
CREATE INDEX IF NOT EXISTS idx_user_empresas_empresa ON usuarios_empresas(empresa_id);
CREATE INDEX IF NOT EXISTS idx_user_empresas_rol ON usuarios_empresas(rol);

-- ========================================
-- SPRINT 3: HISTORIAL LIQUIDACIONES
-- ========================================
CREATE TABLE IF NOT EXISTS historial_liquidaciones (
  id TEXT PRIMARY KEY,
  empleado_cuil TEXT NOT NULL,
  empresa_cuit TEXT NOT NULL,
  
  -- Período
  mes INTEGER NOT NULL CHECK (mes >= 1 AND mes <= 12),
  anio INTEGER NOT NULL CHECK (anio >= 2020),
  periodo TEXT NOT NULL,
  
  -- Tipo
  tipo TEXT NOT NULL DEFAULT 'mensual',
  sector TEXT,
  
  -- Montos principales
  sueldo_basico DECIMAL NOT NULL DEFAULT 0,
  adicional_antiguedad DECIMAL NOT NULL DEFAULT 0,
  otros_haberes DECIMAL NOT NULL DEFAULT 0,
  total_bruto_remunerativo DECIMAL NOT NULL DEFAULT 0,
  total_no_remunerativo DECIMAL NOT NULL DEFAULT 0,
  
  -- Descuentos
  total_aportes DECIMAL NOT NULL DEFAULT 0,
  total_descuentos DECIMAL NOT NULL DEFAULT 0,
  embargos_judiciales DECIMAL NOT NULL DEFAULT 0,
  cuotas_alimentarias DECIMAL NOT NULL DEFAULT 0,
  
  -- Contribuciones empleador
  total_contribuciones DECIMAL NOT NULL DEFAULT 0,
  
  -- Neto
  neto_a_cobrar DECIMAL NOT NULL DEFAULT 0,
  
  -- Datos del cálculo
  antiguedad_anios INTEGER DEFAULT 0,
  provincia TEXT,
  categoria TEXT,
  
  -- Validaciones
  tiene_errores BOOLEAN DEFAULT false,
  tiene_advertencias BOOLEAN DEFAULT false,
  errores JSONB,
  advertencias JSONB,
  
  -- Auditoría
  fecha_liquidacion TIMESTAMP NOT NULL DEFAULT NOW(),
  liquidado_por TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  
  -- Referencia
  liquidacion_id TEXT,
  recibo_url TEXT
);

CREATE INDEX IF NOT EXISTS idx_historial_empleado ON historial_liquidaciones(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_historial_periodo ON historial_liquidaciones(anio DESC, mes DESC);
CREATE INDEX IF NOT EXISTS idx_historial_empresa ON historial_liquidaciones(empresa_cuit);
CREATE INDEX IF NOT EXISTS idx_historial_completo ON historial_liquidaciones(empleado_cuil, anio DESC, mes DESC);

-- ========================================
-- SPRINT 3: AUDITORÍA
-- ========================================
CREATE TABLE IF NOT EXISTS auditoria (
  id TEXT PRIMARY KEY,
  tipo TEXT NOT NULL,
  accion TEXT NOT NULL,
  entidad TEXT NOT NULL,
  descripcion TEXT,
  
  -- Valores
  valor_anterior JSONB,
  valor_nuevo JSONB,
  
  -- Metadatos
  fecha TIMESTAMP NOT NULL DEFAULT NOW(),
  usuario TEXT,
  empresa_cuit TEXT,
  
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auditoria_tipo ON auditoria(tipo);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria(usuario);
CREATE INDEX IF NOT EXISTS idx_auditoria_entidad ON auditoria(entidad);

-- ========================================
-- SPRINT 4+5: VERSIONADO CCT
-- ========================================
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

CREATE INDEX IF NOT EXISTS idx_cct_versiones_codigo ON cct_versiones(cct_codigo);
CREATE INDEX IF NOT EXISTS idx_cct_versiones_activa ON cct_versiones(es_version_activa) WHERE es_version_activa = true;
CREATE INDEX IF NOT EXISTS idx_cct_versiones_numero ON cct_versiones(cct_codigo, numero_version);

-- ========================================
-- TRIGGERS
-- ========================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_empleados_updated_at
BEFORE UPDATE ON empleados
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_conceptos_updated_at
BEFORE UPDATE ON conceptos_recurrentes
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ausencias_updated_at
BEFORE UPDATE ON ausencias
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_prestamos_updated_at
BEFORE UPDATE ON prestamos
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cct_master_updated_at
BEFORE UPDATE ON cct_master
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_empresas_updated_at
BEFORE UPDATE ON empresas
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_usuarios_updated_at
BEFORE UPDATE ON usuarios
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cct_versiones_updated_at
BEFORE UPDATE ON cct_versiones
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- ROW LEVEL SECURITY (RLS)
-- ========================================

ALTER TABLE empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE conceptos_recurrentes ENABLE ROW LEVEL SECURITY;
ALTER TABLE f931_historial ENABLE ROW LEVEL SECURITY;
ALTER TABLE ausencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE presentismo ENABLE ROW LEVEL SECURITY;
ALTER TABLE prestamos ENABLE ROW LEVEL SECURITY;
ALTER TABLE prestamos_cuotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE empresas ENABLE ROW LEVEL SECURITY;

-- Políticas RLS: Los usuarios solo ven datos de sus empresas

-- Empleados
CREATE POLICY "usuarios_ven_empleados_sus_empresas" ON empleados
FOR SELECT USING (
  empresa_cuit IN (
    SELECT e.cuit FROM empresas e
    JOIN usuarios_empresas ue ON ue.empresa_id = e.id
    WHERE ue.user_id = auth.uid() AND ue.activo = true
  )
);

CREATE POLICY "usuarios_editan_empleados_sus_empresas" ON empleados
FOR ALL USING (
  empresa_cuit IN (
    SELECT e.cuit FROM empresas e
    JOIN usuarios_empresas ue ON ue.empresa_id = e.id
    WHERE ue.user_id = auth.uid() 
      AND ue.activo = true
      AND (ue.rol = 'admin' OR ue.rol = 'liquidador')
  )
);

-- Conceptos Recurrentes
CREATE POLICY "usuarios_ven_conceptos_sus_empleados" ON conceptos_recurrentes
FOR SELECT USING (
  empleado_cuil IN (
    SELECT emp.cuil FROM empleados emp
    JOIN empresas e ON emp.empresa_cuit = e.cuit
    JOIN usuarios_empresas ue ON ue.empresa_id = e.id
    WHERE ue.user_id = auth.uid() AND ue.activo = true
  )
);

-- Empresas
CREATE POLICY "usuarios_ven_sus_empresas" ON empresas
FOR SELECT USING (
  id IN (
    SELECT empresa_id FROM usuarios_empresas
    WHERE user_id = auth.uid() AND activo = true
  )
);

-- ========================================
-- VISTAS ÚTILES
-- ========================================

-- Vista: Empleados activos
CREATE OR REPLACE VIEW vista_empleados_activos AS
SELECT 
  cuil,
  empresa_cuit,
  nombre_completo,
  categoria,
  provincia,
  fecha_ingreso,
  EXTRACT(YEAR FROM AGE(CURRENT_DATE, fecha_ingreso)) AS antiguedad_anios_actual,
  sector,
  estado,
  created_at
FROM empleados
WHERE estado = 'activo';

-- Vista: Conceptos activos (sin JOIN para evitar problemas con PK compuesta)
CREATE OR REPLACE VIEW vista_conceptos_activos AS
SELECT 
  empleado_cuil,
  codigo,
  nombre AS concepto_nombre,
  categoria,
  valor,
  activo_desde,
  activo_hasta
FROM conceptos_recurrentes
WHERE activo = true
  AND activo_desde <= CURRENT_DATE
  AND (activo_hasta IS NULL OR activo_hasta >= CURRENT_DATE);

-- Vista: F931 resumen
CREATE OR REPLACE VIEW vista_f931_resumen AS
SELECT 
  empresa_cuit,
  periodo_anio,
  periodo_mes,
  TO_CHAR(TO_DATE(periodo_mes::text, 'MM'), 'Month') AS mes_nombre,
  cantidad_empleados,
  total_remuneraciones,
  total_aportes,
  total_contribuciones,
  (total_aportes + total_contribuciones) AS total_cargas_sociales,
  ROUND((total_aportes + total_contribuciones) / NULLIF(total_remuneraciones, 0) * 100, 2) AS porcentaje_cargas,
  fecha_generacion
FROM f931_historial
ORDER BY periodo_anio DESC, periodo_mes DESC;

-- Vista: Préstamos con progreso (JOIN corregido)
CREATE OR REPLACE VIEW vista_prestamos_progreso AS
SELECT 
  p.id,
  p.empleado_cuil,
  p.empresa_cuit,
  p.monto_total,
  p.cantidad_cuotas,
  p.cuotas_pagadas,
  ROUND((p.cuotas_pagadas::DECIMAL / p.cantidad_cuotas) * 100, 2) AS porcentaje_pagado,
  p.monto_restante,
  p.estado,
  p.fecha_otorgamiento
FROM prestamos p;

-- Vista: Ausencias pendientes (JOIN corregido)
CREATE OR REPLACE VIEW vista_ausencias_pendientes AS
SELECT 
  a.id,
  a.empleado_cuil,
  a.empresa_cuit,
  a.tipo,
  a.fecha_desde,
  a.fecha_hasta,
  a.dias_totales,
  a.con_goce,
  a.created_at
FROM ausencias a
WHERE a.estado = 'pendiente'
ORDER BY a.created_at DESC;

-- Vista: Últimas liquidaciones (JOIN corregido)
CREATE OR REPLACE VIEW vista_ultimas_liquidaciones AS
SELECT DISTINCT ON (empleado_cuil)
  hl.id,
  hl.empleado_cuil,
  hl.empresa_cuit,
  hl.mes,
  hl.anio,
  hl.periodo,
  hl.tipo,
  hl.sector,
  hl.total_bruto_remunerativo,
  hl.neto_a_cobrar,
  hl.fecha_liquidacion
FROM historial_liquidaciones hl
ORDER BY empleado_cuil, anio DESC, mes DESC;

-- Vista: Resumen auditoría
CREATE OR REPLACE VIEW vista_auditoria_resumen AS
SELECT 
  tipo,
  accion,
  COUNT(*) as cantidad,
  MAX(fecha) as ultima_modificacion,
  ARRAY_AGG(DISTINCT usuario) as usuarios
FROM auditoria
GROUP BY tipo, accion
ORDER BY ultima_modificacion DESC;

-- ========================================
-- FUNCIONES ÚTILES
-- ========================================

-- Función: Obtener empleados por estado
CREATE OR REPLACE FUNCTION obtener_empleados_por_estado(
  p_empresa_cuit TEXT,
  p_estado TEXT
)
RETURNS TABLE (
  cuil TEXT,
  nombre_completo TEXT,
  categoria TEXT,
  fecha_ingreso TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  SELECT e.cuil, e.nombre_completo, e.categoria, e.fecha_ingreso
  FROM empleados e
  WHERE e.empresa_cuit = p_empresa_cuit
    AND e.estado = p_estado
  ORDER BY e.nombre_completo;
END;
$$ LANGUAGE plpgsql;

-- Función: Calcular total conceptos recurrentes
CREATE OR REPLACE FUNCTION calcular_total_conceptos_recurrentes(
  p_empleado_cuil TEXT,
  p_mes INTEGER,
  p_anio INTEGER
)
RETURNS TABLE (
  categoria TEXT,
  total_valor DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cr.categoria,
    SUM(cr.valor) AS total_valor
  FROM conceptos_recurrentes cr
  WHERE cr.empleado_cuil = p_empleado_cuil
    AND cr.activo = true
    AND cr.activo_desde <= make_date(p_anio, p_mes, 1)
    AND (cr.activo_hasta IS NULL OR cr.activo_hasta >= make_date(p_anio, p_mes, 1))
  GROUP BY cr.categoria;
END;
$$ LANGUAGE plpgsql;

-- Función: Registrar cuota pagada
CREATE OR REPLACE FUNCTION registrar_cuota_pagada(
  p_prestamo_id UUID,
  p_numero_cuota INTEGER,
  p_liquidacion_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_monto DECIMAL;
  v_cuotas_totales INTEGER;
  v_cuotas_pagadas INTEGER;
BEGIN
  UPDATE prestamos_cuotas
  SET pagada = true, 
      fecha_pago = NOW(),
      liquidacion_id = p_liquidacion_id
  WHERE prestamo_id = p_prestamo_id 
    AND numero_cuota = p_numero_cuota
  RETURNING monto INTO v_monto;
  
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  
  UPDATE prestamos
  SET monto_pagado = monto_pagado + v_monto,
      cuotas_pagadas = cuotas_pagadas + 1,
      updated_at = NOW()
  WHERE id = p_prestamo_id
  RETURNING cantidad_cuotas, cuotas_pagadas 
  INTO v_cuotas_totales, v_cuotas_pagadas;
  
  IF v_cuotas_pagadas >= v_cuotas_totales THEN
    UPDATE prestamos
    SET estado = 'pagado'
    WHERE id = p_prestamo_id;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Función: Mejor remuneración 6 meses (Art. 245 LCT)
CREATE OR REPLACE FUNCTION calcular_mejor_remuneracion_6meses(
  p_empleado_cuil TEXT
)
RETURNS DECIMAL AS $$
DECLARE
  v_mejor_remuneracion DECIMAL;
  v_fecha_limite TIMESTAMP;
BEGIN
  v_fecha_limite := NOW() - INTERVAL '6 months';
  
  SELECT MAX(total_bruto_remunerativo)
  INTO v_mejor_remuneracion
  FROM historial_liquidaciones
  WHERE empleado_cuil = p_empleado_cuil
    AND tipo = 'mensual'
    AND fecha_liquidacion >= v_fecha_limite;
  
  RETURN COALESCE(v_mejor_remuneracion, 0);
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- COMENTARIOS
-- ========================================
COMMENT ON TABLE empleados IS 'Tabla maestra de empleados';
COMMENT ON TABLE conceptos_recurrentes IS 'Conceptos que se aplican automáticamente';
COMMENT ON TABLE f931_historial IS 'Historial de archivos F931 (SICOSS)';
COMMENT ON TABLE ausencias IS 'Registro de ausencias y licencias';
COMMENT ON TABLE presentismo IS 'Cálculo mensual de presentismo';
COMMENT ON TABLE prestamos IS 'Préstamos otorgados a empleados';
COMMENT ON TABLE prestamos_cuotas IS 'Cuotas de préstamos';
COMMENT ON TABLE cct_master IS 'Biblioteca de CCT actualizable';
COMMENT ON TABLE cct_actualizaciones IS 'Historial de actualizaciones de CCT';
COMMENT ON TABLE cct_robot_ejecuciones IS 'Log de ejecuciones del robot BAT';
COMMENT ON TABLE empresas IS 'Empresas/Instituciones del sistema';
COMMENT ON TABLE usuarios IS 'Usuarios del sistema';
COMMENT ON TABLE usuarios_empresas IS 'Relación usuarios-empresas';
COMMENT ON TABLE historial_liquidaciones IS 'Historial completo de liquidaciones';
COMMENT ON TABLE auditoria IS 'Registro de auditoría de cambios críticos';
COMMENT ON TABLE cct_versiones IS 'Versionado de CCT con rollback';

-- ========================================================================
-- FIN DEL SCRIPT
-- ========================================================================
-- TOTAL: 15 tablas + 6 vistas + 4 funciones + RLS + triggers
-- ========================================================================
