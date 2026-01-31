-- ========================================================================
-- PRUEBA DE FUNCIONAMIENTO - SUPABASE
-- ========================================================================
-- Este archivo inserta datos de prueba y verifica que todo funciona
-- ========================================================================

-- PASO 1: INSERTAR EMPRESA DE PRUEBA
INSERT INTO empresas (cuit, razon_social, activa)
VALUES ('20-12345678-9', 'Empresa Test SA', true)
RETURNING *;

-- PASO 2: INSERTAR EMPLEADO DE PRUEBA
INSERT INTO empleados (cuil, empresa_cuit, nombre_completo, fecha_ingreso, categoria, provincia, sector, cbu, codigo_rnos)
VALUES (
  '20-12345678-9',
  '20-12345678-9',
  'Juan Pérez',
  '2024-01-01 00:00:00',
  'Enfermero Profesional',
  'Neuquén',
  'Sanidad',
  '1234567890123456789012',
  '123456'
)
RETURNING *;

-- PASO 3: INSERTAR CCT DE PRUEBA
INSERT INTO cct_master (codigo, nombre, sector, json_estructura, activo)
VALUES (
  'CCT_122/75',
  'Sanidad - Personal de Establecimientos Asistenciales',
  'Sanidad',
  '{"categorias": [{"codigo": "A", "nombre": "Enfermero Profesional"}]}'::jsonb,
  true
)
RETURNING *;

-- PASO 4: INSERTAR CONCEPTO RECURRENTE
INSERT INTO conceptos_recurrentes (id, empleado_cuil, codigo, nombre, tipo, valor, categoria, activo_desde)
VALUES (
  'CR-001',
  '20-12345678-9',
  '001',
  'Antigüedad',
  'remunerativo',
  5000.00,
  'haber',
  '2024-01-01 00:00:00'
)
RETURNING *;

-- PASO 5: INSERTAR AUSENCIA
INSERT INTO ausencias (empleado_cuil, empresa_cuit, tipo, fecha_desde, fecha_hasta, estado)
VALUES (
  '20-12345678-9',
  '20-12345678-9',
  'Vacaciones',
  '2026-02-01',
  '2026-02-14',
  'aprobada'
)
RETURNING *;

-- PASO 6: INSERTAR PRÉSTAMO
INSERT INTO prestamos (empleado_cuil, empresa_cuit, monto_total, cantidad_cuotas, valor_cuota, fecha_otorgamiento)
VALUES (
  '20-12345678-9',
  '20-12345678-9',
  50000.00,
  12,
  4166.67,
  '2026-01-15'
)
RETURNING *;

-- PASO 7: VERIFICAR TODAS LAS TABLAS
SELECT 'empleados' as tabla, COUNT(*) as registros FROM empleados
UNION ALL
SELECT 'empresas', COUNT(*) FROM empresas
UNION ALL
SELECT 'conceptos_recurrentes', COUNT(*) FROM conceptos_recurrentes
UNION ALL
SELECT 'ausencias', COUNT(*) FROM ausencias
UNION ALL
SELECT 'prestamos', COUNT(*) FROM prestamos
UNION ALL
SELECT 'cct_master', COUNT(*) FROM cct_master;

-- ========================================================================
-- PRUEBA COMPLETADA
-- Si ves resultados en todos los pasos, ¡TODO FUNCIONA! ✓
-- ========================================================================
