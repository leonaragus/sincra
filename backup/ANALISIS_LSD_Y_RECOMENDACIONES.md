# 📋 ANÁLISIS DEL FORMATO LSD Y RECOMENDACIONES PROFESIONALES
## Backup realizado: 2026-01-22

---

## 🔍 ANÁLISIS DEL FORMATO LSD ACTUAL

### Estado Actual del Código

#### Registro 1 (Cabecera) - 150 caracteres
**Estructura implementada:**
- ✅ Posición 1: Tipo de registro = "1"
- ✅ Posición 2-12: CUIT empresa (11 caracteres, sin guiones)
- ✅ Posición 13-18: Período AAAAMM (6 caracteres)
- ✅ Posición 19-26: Fecha de pago AAAAMMDD (8 caracteres)
- ✅ Posición 27-56: Razón social (30 caracteres, espacios a la derecha)
- ✅ Posición 57-96: Domicilio (40 caracteres, espacios a la derecha)
- ⚠️ Posición 97-150: Campos adicionales (54 caracteres) - **VACÍO, REQUIERE REVISIÓN**

**Problemas identificados:**
1. Los campos adicionales (97-150) están vacíos. Según AFIP, pueden requerir:
   - Código de actividad económica
   - Código de obra social
   - Código de ART
   - Otros datos según especificaciones oficiales

#### Registro 3 (Conceptos) - 110 caracteres
**Estructura implementada:**
- ✅ Posición 1: Tipo de registro = "3"
- ✅ Posición 2-12: CUIL empleado (11 caracteres, sin guiones)
- ⚠️ Posición 13-18: Código de concepto (6 caracteres) - **CÓDIGOS GENÉRICOS, NO OFICIALES**
- ✅ Posición 19-33: Importe (15 caracteres, 2 decimales, ceros a la izquierda)
- ✅ Posición 34-83: Descripción (50 caracteres, espacios a la derecha)
- ⚠️ Posición 84-110: Campos adicionales (27 caracteres) - **VACÍO, REQUIERE REVISIÓN**

**Problemas identificados:**
1. **Códigos de concepto no oficiales**: Se usan códigos genéricos ('001', '002', '101', etc.) que pueden no ser los oficiales de AFIP/ARBA
2. **Deducciones con signo negativo**: En el código actual se envía `-importe` para deducciones, pero el formato puede requerir que las deducciones se identifiquen por código, no por signo
3. **Campos adicionales vacíos**: Los campos 84-110 pueden requerir información específica según el tipo de concepto

### Correcciones Necesarias en el Formato LSD

#### 1. Códigos de Concepto Oficiales
**ACCIÓN REQUERIDA**: Consultar y usar los códigos oficiales de AFIP/ARBA. Los códigos varían según:
- Tipo de concepto (remunerativo, no remunerativo, descuento)
- Subsistema de seguridad social
- Especificaciones del convenio colectivo

**Fuente**: Descargar "Diseño interfaz conceptos" de www.arca.gob.ar/LibrodeSueldosDigital

#### 2. Formato de Deducciones
**Problema actual**: Se está usando signo negativo en el importe
```dart
importe: -(aportes['jubilacion'] ?? 0.0),  // ❌ INCORRECTO
```

**Solución**: Las deducciones deben identificarse por el código de concepto, NO por signo negativo. El importe siempre debe ser positivo.

#### 3. Campos Adicionales del Registro 1
**ACCIÓN REQUERIDA**: Completar campos 97-150 según especificaciones oficiales. Pueden incluir:
- Código de actividad económica (CIIU)
- Código de obra social
- Código de ART
- Otros datos según normativa vigente

#### 4. Campos Adicionales del Registro 3
**ACCIÓN REQUERIDA**: Completar campos 84-110 según especificaciones oficiales. Pueden incluir:
- Código de subsistema de seguridad social
- Tipo de concepto (R=Remunerativo, N=No Remunerativo, D=Descuento)
- Período de devengamiento
- Otros datos según normativa

#### 5. Validación de Formato
**ACCIÓN REQUERIDA**: 
- Verificar que el archivo sea .txt (ya implementado ✅)
- Verificar codificación Latin1/ANSI (ya implementado ✅)
- Verificar que cada registro esté en una línea separada (ya implementado ✅)
- Agregar validación de códigos de concepto antes de generar

---

## 💡 RECOMENDACIONES DE CÁLCULOS PROFESIONALES

### Cálculos Faltantes Críticos para Argentina 2026

#### 1. **SAC (Sueldo Anual Complementario / Aguinaldo)** ⭐ PRIORITARIO
**Qué es**: Pago semestral obligatorio equivalente al 50% de la mayor remuneración del semestre
**Cuándo se paga**: 
- Primera cuota: 30 de junio
- Segunda cuota: 18 de diciembre

**Cálculo**:
```
SAC = Mayor remuneración mensual del semestre × 0.5
SAC Proporcional = (Mayor remuneración / 12) × meses trabajados en el semestre
```

**Incluye en el cálculo**:
- Sueldo básico
- Horas extras (sin promediar)
- Comisiones
- Adicionales de convenio
- Gratificaciones anuales habituales

**Excluye**:
- Conceptos no remunerativos
- Viáticos
- Asignaciones familiares
- Asignación por maternidad

**Implementación sugerida**:
- Selector de tipo de liquidación: "Normal" o "SAC"
- Si es SAC, mostrar selector de semestre (Enero-Junio / Julio-Diciembre)
- Cargar automáticamente la mayor remuneración del semestre desde historial
- Calcular proporcional si no trabajó todo el semestre

#### 2. **Presentismo** ⭐ PRIORITARIO
**Qué es**: Adicional por asistencia perfecta durante el mes
**Porcentaje estándar**: 8.33% del sueldo básico (equivale a 1/12 del sueldo anual)
**Cálculo**: `Sueldo básico × 0.0833`
**Condición**: Solo se paga si no tuvo inasistencias injustificadas

**Implementación sugerida**:
- Checkbox "Presentismo" (por defecto activado)
- Campo "Días de inasistencia injustificada"
- Si hay inasistencias, no se paga presentismo
- Mostrar en tabla como concepto remunerativo

#### 3. **Antigüedad** ⭐ PRIORITARIO
**Qué es**: Adicional por años de servicio en la empresa
**Cálculo estándar**: 1% por año trabajado sobre sueldo básico
**Ejemplo**: 5 años de antigüedad = 5% adicional

**Implementación sugerida**:
- Campo "Años de antigüedad" (calcular automáticamente desde fecha de ingreso)
- Campo editable para ajustar si es necesario
- Mostrar porcentaje calculado
- Mostrar en tabla como concepto remunerativo

#### 4. **Vacaciones Proporcionales**
**Qué es**: Pago de vacaciones no gozadas al finalizar la relación laboral
**Cálculo**: 
```
Días de vacaciones = (Días trabajados / 365) × Días de vacaciones correspondientes
Monto = (Sueldo básico / 30) × Días de vacaciones
```

**Días por año según antigüedad**:
- Hasta 5 años: 14 días
- 5 a 10 años: 21 días
- 10 a 20 años: 28 días
- Más de 20 años: 35 días

**Implementación sugerida**:
- Solo mostrar en liquidación de fin de relación laboral
- Calcular automáticamente según antigüedad
- Mostrar días calculados y monto

#### 5. **Días Trabajados / Licencias** (Mejorar visibilidad)
**Estado actual**: Existe el campo `diasTrabajados` pero no es visible en la UI
**Mejora sugerida**:
- Campo visible "Días trabajados en el mes" (por defecto 30)
- Campo "Días de licencia" (médica, vacaciones, etc.)
- Validación: Días trabajados + Días de licencia = 30 (o días del mes)
- Cálculo proporcional automático del sueldo básico

#### 6. **Adicionales por Convenio**
**Tipos comunes**:
- **Zona**: Adicional por zona geográfica (ej: 10%, 15%, 20%)
- **Riesgo**: Adicional por trabajo en condiciones de riesgo
- **Nocturnidad**: Adicional por trabajo nocturno (generalmente 20% adicional)
- **Insalubridad**: Adicional por condiciones insalubres

**Implementación sugerida**:
- Sección "Adicionales de Convenio"
- Selector de tipo de adicional
- Campo de porcentaje o monto fijo
- Mostrar en tabla como concepto remunerativo

#### 7. **Comisiones y Bonificaciones**
**Comisiones**: 
- Porcentaje sobre ventas o producción
- Campo "Porcentaje" y "Base de cálculo"
- Cálculo automático: Base × Porcentaje

**Bonificaciones**:
- Montos fijos o variables según objetivos
- Campo de monto directo

**Implementación sugerida**:
- Sección "Comisiones y Bonificaciones"
- Agregar múltiples comisiones/bonificaciones
- Mostrar en tabla como concepto remunerativo

#### 8. **Asignaciones Familiares (ANSeS)**
**Qué es**: Asignación Universal por Hijo (AUH) y otras asignaciones
**Cálculo**: Monto fijo por hijo según cantidad
**Límite**: Hasta 18 años (o más si estudia)

**Implementación sugerida**:
- Campo "Cantidad de hijos menores de 18 años"
- Calcular automáticamente según tabla ANSeS
- Mostrar en tabla como concepto no remunerativo

#### 9. **Descuentos por Inasistencias**
**Tipos**:
- Faltas injustificadas: Descuento proporcional
- Licencias sin goce de sueldo: Descuento completo
- Suspensiones: Descuento según días

**Implementación sugerida**:
- Campo "Días de inasistencia injustificada"
- Campo "Días de licencia sin goce de sueldo"
- Cálculo automático: (Sueldo básico / 30) × Días
- Mostrar en tabla como deducción

#### 10. **Retenciones Judiciales y Préstamos**
**Tipos**:
- Retención judicial (embargos, alimentos)
- Préstamos otorgados por la empresa
- Seguros de vida (si el empleado tiene)

**Implementación sugerida**:
- Sección "Retenciones y Préstamos"
- Agregar múltiples retenciones
- Mostrar en tabla como deducción

### Mejoras en la Interfaz del Liquidador

#### 1. Selector de Tipo de Liquidación
```
[ ] Liquidación Normal
[ ] Liquidación de SAC (Aguinaldo)
[ ] Liquidación de Fin de Relación Laboral
[ ] Liquidación Proporcional
```

#### 2. Campos Adicionales Visibles
- **Días trabajados**: Campo numérico (1-31)
- **Días de licencia**: Campo numérico
- **Días de vacaciones**: Campo numérico (si aplica)
- **Años de antigüedad**: Campo numérico (calcular desde fecha de ingreso)
- **Presentismo**: Checkbox (por defecto activado)
- **Zona geográfica**: Dropdown o campo texto
- **Tipo de jornada**: Dropdown (Diurna/Nocturna/Mixta)

#### 3. Validaciones Adicionales
- Validar que días trabajados + días de licencia ≤ días del mes
- Validar que antigüedad no sea mayor a años desde fecha de ingreso
- Validar rangos de porcentajes según convenio
- Validar que SAC solo se calcule en fechas correspondientes (junio/diciembre)

#### 4. Cálculos Automáticos Mejorados
- **Sueldo básico proporcional**: Calcular automáticamente según días trabajados
- **Presentismo**: Calcular automáticamente si no hay inasistencias
- **Antigüedad**: Calcular automáticamente desde fecha de ingreso
- **SAC**: Calcular automáticamente la mayor remuneración del semestre

---

## ⚠️ PRIORIDADES DE IMPLEMENTACIÓN

### Alta Prioridad (Implementar primero)
1. ✅ **Presentismo** - Muy común en convenios
2. ✅ **Antigüedad** - Muy común en convenios
3. ✅ **Días trabajados** - Mejorar visibilidad y cálculo proporcional
4. ✅ **Corregir formato LSD** - Códigos oficiales y formato de deducciones

### Media Prioridad
5. **SAC (Aguinaldo)** - Solo necesario en junio y diciembre
6. **Adicionales por convenio** - Depende del convenio específico
7. **Comisiones y bonificaciones** - Depende del tipo de trabajo

### Baja Prioridad (Puede esperar)
8. **Vacaciones proporcionales** - Solo para fin de relación laboral
9. **Asignaciones familiares** - Se calculan aparte en ANSeS
10. **Retenciones judiciales** - Casos específicos

---

## 📝 PRÓXIMOS PASOS INMEDIATOS

1. **Descargar documentación oficial de AFIP**:
   - Ir a www.arca.gob.ar/LibrodeSueldosDigital
   - Descargar "Diseño interfaz conceptos"
   - Verificar estructura exacta de registros 1 y 3
   - Obtener tabla de códigos de concepto oficiales

2. **Corregir formato LSD**:
   - Reemplazar códigos genéricos por códigos oficiales
   - Remover signos negativos de deducciones
   - Completar campos adicionales según especificaciones

3. **Implementar cálculos prioritarios**:
   - Presentismo (8.33%)
   - Antigüedad (1% por año)
   - Mejorar visibilidad de días trabajados

4. **Mejorar interfaz**:
   - Agregar campos faltantes
   - Agregar validaciones
   - Mejorar UX del liquidador

---

## 📚 REFERENCIAS Y FUENTES

- **AFIP Libro de Sueldos Digital**: www.afip.gob.ar/LibrodeSueldosDigital
- **ARCA**: www.arca.gob.ar/LibrodeSueldosDigital
- **Ley 23.041**: Sueldo Anual Complementario (SAC/Aguinaldo)
- **Ley 20.744**: Ley de Contrato de Trabajo (LCT)
- **Resolución General AFIP 5250/2022**: Normativa vigente del LSD
- **Calculadora de Sueldos**: calculadoradesueldos.com.ar (referencia)

---

## ✅ CHECKLIST DE VERIFICACIÓN

Antes de subir archivos LSD a AFIP/ARBA, verificar:

- [ ] Códigos de concepto son los oficiales de AFIP
- [ ] Importes no tienen signo negativo (deducciones identificadas por código)
- [ ] Registro 1 tiene exactamente 150 caracteres
- [ ] Registro 3 tiene exactamente 110 caracteres
- [ ] Archivo es .txt con codificación Latin1/ANSI
- [ ] Cada registro está en una línea separada
- [ ] CUIT/CUIL sin guiones ni espacios
- [ ] Fechas en formato AAAAMMDD
- [ ] Período en formato AAAAMM
- [ ] Campos alfanuméricos con espacios a la derecha
- [ ] Campos numéricos con ceros a la izquierda
- [ ] Campos adicionales completados según especificaciones oficiales
