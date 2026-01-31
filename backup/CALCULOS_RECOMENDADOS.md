# 💡 CÁLCULOS RECOMENDADOS PARA SISTEMA PROFESIONAL
## Análisis basado en sistemas de liquidación Argentina 2026

---

## ⭐ ALTA PRIORIDAD (Muy comunes en convenios)

### 1. **Presentismo**
**Descripción**: Adicional por asistencia perfecta durante el mes
**Cálculo**: `Sueldo básico × 8.33%` (equivale a 1/12 del sueldo anual)
**Cuándo se aplica**: Si el empleado no tuvo inasistencias injustificadas
**Tipo**: Concepto REMUNERATIVO
**Complejidad**: ⭐ Baja (simple multiplicación)
**¿Aplicar?**: [ ] Sí  [ ] No

**Implementación sugerida**:
- Checkbox "Presentismo" (por defecto activado)
- Campo "Días de inasistencia injustificada"
- Si hay inasistencias > 0, no se paga presentismo
- Mostrar en tabla como concepto remunerativo

---

### 2. **Antigüedad**
**Descripción**: Adicional por años de servicio en la empresa
**Cálculo estándar**: `Sueldo básico × (Años de antigüedad × 1%)`
**Ejemplo**: 5 años = 5% adicional sobre sueldo básico
**Tipo**: Concepto REMUNERATIVO
**Complejidad**: ⭐ Baja (calcular años desde fecha de ingreso)
**¿Aplicar?**: [ ] Sí  [ ] No

**Implementación sugerida**:
- Calcular automáticamente desde fecha de ingreso del empleado
- Campo editable "Años de antigüedad" (por si hay ajustes)
- Mostrar porcentaje calculado
- Mostrar en tabla como concepto remunerativo

---

### 3. **Días Trabajados (Mejorar visibilidad)**
**Descripción**: Campo ya existe pero no es visible en la UI
**Cálculo proporcional**: `Sueldo básico × (Días trabajados / 30)`
**Tipo**: Afecta el cálculo del sueldo básico
**Complejidad**: ⭐ Muy Baja (solo hacer visible el campo existente)
**¿Aplicar?**: [ ] Sí  [ ] No

**Implementación sugerida**:
- Campo visible "Días trabajados en el mes" (por defecto 30)
- Campo "Días de licencia" (médica, vacaciones, etc.)
- Validación: Días trabajados + Días de licencia ≤ 30
- Cálculo proporcional automático del sueldo básico

---

## 📅 MEDIA PRIORIDAD (Necesarios en momentos específicos)

### 4. **SAC (Sueldo Anual Complementario / Aguinaldo)**
**Descripción**: Pago semestral obligatorio - 50% de la mayor remuneración del semestre
**Cuándo se paga**: 
- Primera cuota: 30 de junio
- Segunda cuota: 18 de diciembre

**Cálculo**:
```
SAC = Mayor remuneración mensual del semestre × 0.5
SAC Proporcional = (Mayor remuneración / 12) × meses trabajados
```

**Incluye**: Sueldo básico, horas extras, comisiones, adicionales
**Excluye**: Conceptos no remunerativos, viáticos, asignaciones familiares
**Tipo**: Concepto REMUNERATIVO (pero se liquida aparte)
**Complejidad**: ⭐⭐⭐ Media (requiere historial de liquidaciones)
**¿Aplicar?**: [ ] Sí  [ ] No

**Implementación sugerida**:
- Selector de tipo de liquidación: "Normal" o "SAC"
- Si es SAC: selector de semestre (Enero-Junio / Julio-Diciembre)
- Cargar automáticamente mayor remuneración del semestre desde historial
- Calcular proporcional si no trabajó todo el semestre

---

### 5. **Adicionales por Convenio**
**Tipos comunes**:
- **Zona**: Adicional por zona geográfica (ej: 10%, 15%, 20%)
- **Riesgo**: Adicional por trabajo en condiciones de riesgo
- **Nocturnidad**: Adicional por trabajo nocturno (generalmente 20%)
- **Insalubridad**: Adicional por condiciones insalubres

**Cálculo**: Generalmente porcentaje sobre sueldo básico o monto fijo
**Tipo**: Concepto REMUNERATIVO
**Complejidad**: ⭐⭐ Baja-Media (depende del convenio)
**¿Aplicar?**: [ ] Sí  [ ] No

**Implementación sugerida**:
- Sección "Adicionales de Convenio"
- Selector de tipo de adicional (Zona, Riesgo, Nocturnidad, Insalubridad)
- Campo de porcentaje o monto fijo
- Mostrar en tabla como concepto remunerativo

---

### 6. **Comisiones y Bonificaciones**
**Comisiones**: 
- Porcentaje sobre ventas o producción
- Cálculo: `Base de cálculo × Porcentaje`

**Bonificaciones**:
- Montos fijos o variables según objetivos

**Tipo**: Concepto REMUNERATIVO
**Complejidad**: ⭐⭐ Baja (campos simples)
**¿Aplicar?**: [ ] Sí  [ ] No

**Implementación sugerida**:
- Sección "Comisiones y Bonificaciones"
- Agregar múltiples comisiones/bonificaciones
- Para comisiones: Campo "Base" y "Porcentaje"
- Para bonificaciones: Campo "Monto"
- Mostrar en tabla como concepto remunerativo

---

## 🔧 BAJA PRIORIDAD (Casos específicos)

### 7. **Vacaciones Proporcionales**
**Descripción**: Pago de vacaciones no gozadas al finalizar la relación laboral
**Cálculo**: 
```
Días de vacaciones = (Días trabajados / 365) × Días correspondientes según antigüedad
Monto = (Sueldo básico / 30) × Días de vacaciones
```

**Días por año según antigüedad**:
- Hasta 5 años: 14 días
- 5 a 10 años: 21 días
- 10 a 20 años: 28 días
- Más de 20 años: 35 días

**Tipo**: Concepto REMUNERATIVO
**Complejidad**: ⭐⭐⭐ Media (requiere cálculo de días proporcionales)
**Cuándo**: Solo para liquidación de fin de relación laboral
**¿Aplicar?**: [ ] Sí  [ ] No

---

### 8. **Asignaciones Familiares (ANSeS)**
**Descripción**: Asignación Universal por Hijo (AUH) y otras asignaciones
**Cálculo**: Monto fijo por hijo según tabla ANSeS
**Tipo**: Concepto NO REMUNERATIVO
**Complejidad**: ⭐⭐ Baja (tabla de montos)
**Nota**: Generalmente se calculan aparte en ANSeS, no en la liquidación de sueldo
**¿Aplicar?**: [ ] Sí  [ ] No

---

### 9. **Descuentos por Inasistencias**
**Tipos**:
- Faltas injustificadas: Descuento proporcional
- Licencias sin goce de sueldo: Descuento completo
- Suspensiones: Descuento según días

**Cálculo**: `(Sueldo básico / 30) × Días de inasistencia`
**Tipo**: DEDUCCIÓN
**Complejidad**: ⭐ Baja (similar a días trabajados)
**¿Aplicar?**: [ ] Sí  [ ] No

---

### 10. **Retenciones Judiciales y Préstamos**
**Tipos**:
- Retención judicial (embargos, alimentos)
- Préstamos otorgados por la empresa
- Seguros de vida

**Tipo**: DEDUCCIÓN
**Complejidad**: ⭐ Baja (monto fijo o porcentaje)
**Nota**: Ya existe sección de "Deducciones Adicionales" que puede cubrir esto
**¿Aplicar?**: [ ] Sí  [ ] No (ya cubierto parcialmente)

---

## 📊 RESUMEN DE COMPLEJIDAD

| Cálculo | Complejidad | Prioridad | Esfuerzo |
|---------|-------------|-----------|----------|
| Presentismo | ⭐ Baja | Alta | 1-2 horas |
| Antigüedad | ⭐ Baja | Alta | 1-2 horas |
| Días Trabajados | ⭐ Muy Baja | Alta | 30 min |
| SAC | ⭐⭐⭐ Media | Media | 4-6 horas |
| Adicionales Convenio | ⭐⭐ Baja | Media | 2-3 horas |
| Comisiones | ⭐⭐ Baja | Media | 2-3 horas |
| Vacaciones Prop. | ⭐⭐⭐ Media | Baja | 3-4 horas |
| Asignaciones Familiares | ⭐⭐ Baja | Baja | 2 horas |
| Descuentos Inasistencias | ⭐ Baja | Baja | 1 hora |
| Retenciones Judiciales | ⭐ Baja | Baja | Ya existe |

---

## 🎯 RECOMENDACIÓN FINAL

**Para un sistema profesional básico, recomiendo implementar**:

1. ✅ **Presentismo** - Muy común, fácil de implementar
2. ✅ **Antigüedad** - Muy común, fácil de implementar  
3. ✅ **Días Trabajados** - Ya existe, solo hacer visible
4. ⚠️ **SAC** - Importante pero complejo (requiere historial)
5. ⚠️ **Adicionales por Convenio** - Útil pero depende del convenio

**Los demás pueden agregarse según necesidad específica del cliente**.

---

## 📝 NOTAS IMPORTANTES

- **SAC**: Requiere guardar historial de liquidaciones para calcular la mayor remuneración del semestre
- **Presentismo y Antigüedad**: Son los más comunes en convenios colectivos
- **Días Trabajados**: Ya está implementado en el modelo, solo falta hacerlo visible en la UI
- **Adicionales**: Dependen mucho del convenio específico, pueden variar
