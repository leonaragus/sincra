-- ========================================================================
-- SCHEMA SUPABASE PARA SPRINT 1
-- Tablas para Empleados, Conceptos Recurrentes y F931
-- Ejecutar este script en el SQL Editor de Supabase
-- ========================================================================

-- ========================================
-- TABLA: empleados
-- ========================================
CREATE TABLE IF NOT EXISTS empleados (
  -- Identificación (Primary Key compuesta)
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
  sector TEXT, -- sanidad, docente, cct_generico
  subsector TEXT,
  
  -- Ubicación
  provincia TEXT NOT NULL,
  jurisdiccion TEXT, -- provincial, municipal, nacional, privado
  
  -- CCT aplicable
  cct_codigo TEXT,
  cct_nombre TEXT,
  
  -- Datos bancarios
  cbu TEXT,
  banco TEXT,
  tipo_cuenta TEXT,
  
  -- Obra social y sindicato
  codigo_rnos TEXT,
  obra_social_nombre TEXT,
  aporte_sindical DECIMAL,
  
  -- Modalidad contratación (para F931)
  modalidad_contratacion INTEGER DEFAULT 1,
  
  -- Estado
  estado TEXT DEFAULT 'activo', -- activo, suspendido, de_baja, licencia
  fecha_baja TIMESTAMP,
  motivo_baja TEXT,
  
  -- Empresa
  empresa_nombre TEXT,
  
  -- Metadata
  notas TEXT,
  tags TEXT[], -- Array de strings
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT,
  modificado_por TEXT,
  
  -- Constraints
  PRIMARY KEY (cuil, empresa_cuit)
);

-- Índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_empleados_empresa ON empleados(empresa_cuit);
CREATE INDEX IF NOT EXISTS idx_empleados_cuil ON empleados(cuil);
CREATE INDEX IF NOT EXISTS idx_empleados_estado ON empleados(estado);
CREATE INDEX IF NOT EXISTS idx_empleados_provincia ON empleados(provincia);
CREATE INDEX IF NOT EXISTS idx_empleados_categoria ON empleados(categoria);
CREATE INDEX IF NOT EXISTS idx_empleados_sector ON empleados(sector);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_empleados_updated_at
BEFORE UPDATE ON empleados
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- TABLA: conceptos_recurrentes
-- ========================================
CREATE TABLE IF NOT EXISTS conceptos_recurrentes (
  -- Identificación
  id TEXT PRIMARY KEY,
  empleado_cuil TEXT NOT NULL,
  
  -- Identificación del concepto
  codigo TEXT NOT NULL,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  
  -- Tipo
  tipo TEXT NOT NULL, -- fijo, porcentaje, calculado
  valor DECIMAL NOT NULL,
  formula TEXT,
  
  -- Categorización
  categoria TEXT NOT NULL, -- remunerativo, no_remunerativo, descuento
  subcategoria TEXT,
  
  -- Vigencia
  activo_desde TIMESTAMP NOT NULL,
  activo_hasta TIMESTAMP,
  
  -- Estado
  activo BOOLEAN DEFAULT true,
  
  -- Condiciones
  condicion TEXT,
  
  -- Para embargos
  monto_total_embargo DECIMAL,
  monto_acumulado_descontado DECIMAL DEFAULT 0,
  
  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  creado_por TEXT
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_conceptos_empleado ON conceptos_recurrentes(empleado_cuil);
CREATE INDEX IF NOT EXISTS idx_conceptos_activo ON conceptos_recurrentes(activo);
CREATE INDEX IF NOT EXISTS idx_conceptos_categoria ON conceptos_recurrentes(categoria);
CREATE INDEX IF NOT EXISTS idx_conceptos_codigo ON conceptos_recurrentes(codigo);

-- Trigger updated_at
CREATE TRIGGER update_conceptos_recurrentes_updated_at
BEFORE UPDATE ON conceptos_recurrentes
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- TABLA: f931_historial
-- ========================================
CREATE TABLE IF NOT EXISTS f931_historial (
  -- Identificación
  id TEXT PRIMARY KEY, -- formato: {cuit}_{anio}_{mes}
  empresa_cuit TEXT NOT NULL,
  periodo_mes INTEGER NOT NULL,
  periodo_anio INTEGER NOT NULL,
  
  -- Resumen
  cantidad_empleados INTEGER NOT NULL,
  total_remuneraciones DECIMAL NOT NULL,
  total_aportes DECIMAL NOT NULL,
  total_contribuciones DECIMAL NOT NULL,
  
  -- Contenido del archivo
  contenido_archivo TEXT NOT NULL,
  
  -- Auditoría
  generado_por TEXT,
  fecha_generacion TIMESTAMP DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT unique_f931_periodo UNIQUE (empresa_cuit, periodo_anio, periodo_mes)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_f931_empresa ON f931_historial(empresa_cuit);
CREATE INDEX IF NOT EXISTS idx_f931_periodo ON f931_historial(periodo_anio, periodo_mes);

-- ========================================
-- ROW LEVEL SECURITY (RLS)
-- ========================================
-- NOTA: Habilitar RLS si quieres que cada usuario solo vea sus propios datos
-- ALTER TABLE empleados ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE conceptos_recurrentes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE f931_historial ENABLE ROW LEVEL SECURITY;

-- Ejemplo de política RLS (descomenta si lo necesitas):
-- CREATE POLICY "Usuarios pueden ver sus propios empleados"
-- ON empleados FOR SELECT
-- USING (auth.uid()::text = creado_por);

-- ========================================
-- VISTAS ÚTILES PARA REPORTES
-- ========================================

-- Vista: Empleados activos con antigüedad calculada
CREATE OR REPLACE VIEW vista_empleados_activos AS
SELECT 
  cuil,
  empresa_cuit,
  nombre_completo,
  categoria,
  provincia,
  fecha_ingreso,
  EXTRACT(YEAR FROM AGE(CURRENT_DATE, fecha_ingreso)) AS antiguedad_anios_actual,
  provincia,
  sector,
  estado,
  created_at
FROM empleados
WHERE estado = 'activo';

-- Vista: Conceptos recurrentes activos por empleado
CREATE OR REPLACE VIEW vista_conceptos_activos AS
SELECT 
  cr.empleado_cuil,
  e.nombre_completo,
  cr.codigo,
  cr.nombre AS concepto_nombre,
  cr.categoria,
  cr.valor,
  cr.activo_desde,
  cr.activo_hasta
FROM conceptos_recurrentes cr
JOIN empleados e ON cr.empleado_cuil = e.cuil
WHERE cr.activo = true
  AND cr.activo_desde <= CURRENT_DATE
  AND (cr.activo_hasta IS NULL OR cr.activo_hasta >= CURRENT_DATE);

-- Vista: Resumen de empleados por provincia y estado
CREATE OR REPLACE VIEW vista_resumen_empleados_provincia AS
SELECT 
  provincia,
  estado,
  COUNT(*) AS cantidad,
  ARRAY_AGG(DISTINCT categoria) AS categorias
FROM empleados
GROUP BY provincia, estado;

-- Vista: Historial F931 con resumen
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

-- ========================================
-- FUNCIONES ÚTILES
-- ========================================

-- Función: Obtener empleados por empresa y estado
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

-- Función: Calcular total de conceptos recurrentes para un empleado
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

-- ========================================
-- DATOS DE EJEMPLO (opcional, comentado)
-- ========================================
/*
-- Empleado de ejemplo
INSERT INTO empleados (
  cuil, empresa_cuit, nombre_completo, apellido, nombre,
  fecha_ingreso, categoria, provincia, estado
) VALUES (
  '20123456789', '30123456780', 'Juan Pérez', 'Pérez', 'Juan',
  '2020-01-15', 'Enfermero', 'Buenos Aires', 'activo'
) ON CONFLICT DO NOTHING;

-- Concepto recurrente de ejemplo
INSERT INTO conceptos_recurrentes (
  id, empleado_cuil, codigo, nombre, descripcion,
  tipo, valor, categoria, activo_desde, activo
) VALUES (
  '1', '20123456789', 'VALE_COMIDA', 'Vale alimentario', 'Vale de comida mensual',
  'fijo', 50000, 'no_remunerativo', CURRENT_DATE, true
) ON CONFLICT DO NOTHING;
*/

-- ========================================
-- COMENTARIOS EN LAS TABLAS
-- ========================================
COMMENT ON TABLE empleados IS 'Tabla maestra de empleados para todas las empresas';
COMMENT ON TABLE conceptos_recurrentes IS 'Conceptos que se aplican automáticamente cada mes (vales, descuentos, embargos)';
COMMENT ON TABLE f931_historial IS 'Historial de archivos F931 (SICOSS) generados para AFIP';

COMMENT ON COLUMN empleados.modalidad_contratacion IS '1=Permanente, 2=Temporario, 3=Eventual (según AFIP)';
COMMENT ON COLUMN conceptos_recurrentes.tipo IS 'fijo: monto fijo, porcentaje: % del bruto, calculado: usa fórmula';
COMMENT ON COLUMN conceptos_recurrentes.monto_total_embargo IS 'Para embargos: monto total a descontar hasta completar';

-- ========================================
-- FIN DEL SCRIPT
-- ========================================
