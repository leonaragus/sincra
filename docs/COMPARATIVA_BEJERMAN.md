# Comparativa Técnica: Syncra Arg vs. Sistema Bejerman (Módulo Docente)

Este documento detalla las diferencias técnicas, funcionales y operativas entre el módulo de liquidación docente de **Syncra Arg** y la solución estándar de mercado (**Sistema Bejerman** / Thomson Reuters).

## 1. Resumen Ejecutivo

| Característica | Sistema Bejerman (Legacy) | Syncra Arg (Moderno) |
| :--- | :--- | :--- |
| **Arquitectura** | Monolito On-Premise / Cloud Híbrido | Nube Nativa (Flutter/Supabase) + Offline First |
| **Configuración** | Definición manual de fórmulas y conceptos | Parámetros pre-configurados por jurisdicción |
| **Actualización** | Parches manuales o actualizaciones de versión | Actualización transparente en la nube |
| **UX/UI** | Grillas de datos tipo Excel/ERP clásico | Interfaz guiada por procesos y validaciones |
| **Validación** | Post-liquidación (al exportar) | Pre-liquidación (tiempo real) |

## 2. Análisis Detallado del Módulo Docente

### A. Gestión de Antigüedad y Escalas
*   **Bejerman:** Requiere configurar una tabla o matriz de antigüedad general. Para docentes, a menudo se debe crear una fórmula condicional compleja (`SI ANIOS > 10 ENTONCES ...`) o cargar manualmente los porcentajes.
*   **Syncra Arg:** Cuenta con un motor nativo de antigüedad docente (`AntiguedadService`) que aplica automáticamente las escalas vigentes (15%, 30%, 40%, etc.) según la jurisdicción y fecha de ingreso, sin que el usuario toque fórmulas.

### B. Conceptos Específicos (FONID, Conectividad)
*   **Bejerman:** Se tratan como conceptos "No Remunerativos" genéricos. El usuario debe crear el concepto, asignarle el código AFIP y actualizar el monto manualmente cada vez que cambia la paritaria nacional.
*   **Syncra Arg:** Estos conceptos son ciudadanos de primera clase. El sistema alerta cuando hay nuevos valores de paritaria y sugiere la actualización automática de los montos globales.

### C. Manejo de Cargos vs. Horas Cátedra
*   **Bejerman:** Generalmente usa el campo "Cantidad" del concepto. No distingue semánticamente entre un cargo (ej. Preceptor) y horas (ej. Profesor Historia), lo que suele causar errores en la exportación al LSD (Libro de Sueldos Digital).
*   **Syncra Arg:** Modelo de datos polimórfico que distingue `Cargo` (unidad) de `HorasCatedra` (cantidad). Esto permite que el validador de ARCA/LSD aplique reglas diferentes para cada uno automáticamente.

### D. Cálculo de Retroactivos
*   **Bejerman:** Proceso manual o semi-automático. El usuario debe calcular la diferencia por fuera o crear un concepto de "Ajuste" e ingresar el monto.
*   **Syncra Arg:** Módulo dedicado de `Retroactivos`. El sistema recalcula liquidaciones cerradas con los nuevos parámetros, genera la diferencia (delta) y crea automáticamente los ítems de ajuste en la liquidación actual con la trazabilidad completa.

## 3. Integración y Exportación (ARCA / LSD)

### Validación de Códigos
*   **Bejerman:** Permite exportar el TXT aunque falten mapeos. Los errores saltan al subir el archivo a la página de AFIP.
*   **Syncra Arg:** Validador preventivo (`LsdMappingService`). No permite generar el TXT si detecta conceptos sin asociar o asociaciones inválidas (ej. un concepto No Remunerativo asociado a un código Remunerativo).

### Interfaz ARCA
*   **Bejerman:** Dependencia de actualizaciones del proveedor para nuevos formatos.
*   **Syncra Arg:** Mapeo dinámico configurable desde la nube, permitiendo hot-fixes si AFIP cambia la estructura del archivo sin actualizar la app completa.

## 4. Herramienta de Migración y Comparación

Para facilitar la transición, Syncra Arg incluye un módulo de **"Comparación de Importación"** (en desarrollo):
1.  **Importación:** Lee archivos Excel exportados desde Bejerman.
2.  **Matching:** Asocia legajos por CUIL.
3.  **Diferencia:** Compara Neto, Bruto y Contribuciones, resaltando desvíos mayores a $10.

---
*Documento generado para análisis interno y validación de funcionalidades.*
