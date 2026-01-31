-- ========================================================================
-- PASO 2: CREAR LOS ÍNDICES (EJECUTAR DESPUÉS DEL PASO 1)
-- ========================================================================
-- NOTA: No se crean índices en columnas de PRIMARY KEY (ya existen implícitamente)

CREATE INDEX IF NOT EXISTS idx_empleados_estado ON empleados(estado);
CREATE INDEX IF NOT EXISTS idx_empleados_provincia ON empleados(provincia);
CREATE INDEX IF NOT EXISTS idx_empleados_sector ON empleados(sector);

CREATE INDEX IF NOT EXISTS idx_conceptos_empleado ON conceptos_recurrentes(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_conceptos_activo ON conceptos_recurrentes(activo);
CREATE INDEX IF NOT EXISTS idx_conceptos_categoria ON conceptos_recurrentes(categoria);

CREATE INDEX IF NOT EXISTS idx_f931_empresa ON f931_historial(empresa_cuit);
CREATE INDEX IF NOT EXISTS idx_f931_periodo ON f931_historial(periodo_anio, periodo_mes);

CREATE INDEX IF NOT EXISTS idx_ausencias_empleado ON ausencias(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_ausencias_empresa ON ausencias(empresa_cuit);
CREATE INDEX IF NOT EXISTS idx_ausencias_estado ON ausencias(estado);

CREATE INDEX IF NOT EXISTS idx_presentismo_empleado ON presentismo(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_presentismo_periodo ON presentismo(periodo_anio, periodo_mes);

CREATE INDEX IF NOT EXISTS idx_prestamos_empleado ON prestamos(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_prestamos_estado ON prestamos(estado);

CREATE INDEX IF NOT EXISTS idx_cuotas_prestamo ON prestamos_cuotas(prestamo_id);

CREATE INDEX IF NOT EXISTS idx_cct_sector ON cct_master(sector);
CREATE INDEX IF NOT EXISTS idx_cct_activo ON cct_master(activo);

-- ELIMINADOS: empresas(cuit) y usuarios(email) tienen UNIQUE constraint (índice automático)

CREATE INDEX IF NOT EXISTS idx_user_empresas_user ON usuarios_empresas(user_id);
CREATE INDEX IF NOT EXISTS idx_user_empresas_empresa ON usuarios_empresas(empresa_id);

CREATE INDEX IF NOT EXISTS idx_historial_empleado ON historial_liquidaciones(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_historial_periodo ON historial_liquidaciones(anio DESC, mes DESC);
CREATE INDEX IF NOT EXISTS idx_historial_empresa ON historial_liquidaciones(empresa_cuit);

CREATE INDEX IF NOT EXISTS idx_auditoria_tipo ON auditoria(tipo);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria(fecha DESC);

CREATE INDEX IF NOT EXISTS idx_cct_versiones_codigo ON cct_versiones(cct_codigo);

-- ========================================================================
-- PASO 2 COMPLETADO - TODOS LOS ÍNDICES CREADOS
-- ========================================================================
