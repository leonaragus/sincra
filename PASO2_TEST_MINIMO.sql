-- ========================================================================
-- PASO 2 TEST MÍNIMO - SOLO 3 ÍNDICES PARA PROBAR
-- ========================================================================

-- Test 1: Índice simple en empleados
CREATE INDEX IF NOT EXISTS idx_test_empleados_estado ON empleados(estado);

-- Test 2: Índice simple en ausencias
CREATE INDEX IF NOT EXISTS idx_test_ausencias_estado ON ausencias(estado);

-- Test 3: Índice en conceptos_recurrentes
CREATE INDEX IF NOT EXISTS idx_test_conceptos_activo ON conceptos_recurrentes(activo);

-- ========================================================================
-- SI ESTO FUNCIONA, EL PROBLEMA ES OTRO ÍNDICE ESPECÍFICO
-- ========================================================================
