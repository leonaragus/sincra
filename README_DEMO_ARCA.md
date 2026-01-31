# Archivo de Demostración ARCA 2026

## Archivo: `demo_liquidacion_arca_2026.txt`

Este archivo contiene un ejemplo de liquidación en formato ARCA 2026 para pruebas.

### Estructura del Archivo

El archivo contiene **9 líneas** con exactamente **150 caracteres cada una**:

1. **Registro 1** (Línea 1): Datos básicos de la empresa
   - Identificador: `1`
   - CUIT Empresa: `20123456789`
   - Período: `202601` (Enero 2026)
   - Fecha de Pago: `20260115` (15/01/2026)
   - Razón Social: `EMPRESA DEMO S.A.`
   - Domicilio: `AV. CORRIENTES 1234 CABA ARGENTINA`

2. **Registros 2** (Líneas 2-7): Conceptos individuales
   - Estructura: Identificador(1) + CUIL(11) + Código AFIP(10) + Espacios(5) + Importe(15) + Descripción(108)
   - Línea 2: Sueldo Básico ($500.000,00) - Código: 011000
   - Línea 3: Presentismo 8.33% ($41.650,00) - Código: 012000
   - Línea 4: Horas Extras 50% ($100.000,00) - Código: 051000
   - Línea 5: Jubilación (SIPA) ($55.000,00) - Código: 810000
   - Línea 6: Ley 19.032 (PAMI) ($15.000,00) - Código: 810000
   - Línea 7: Obra Social ($15.000,00) - Código: 810000

3. **Registro 3** (Línea 8): Bases Imponibles F.931
   - Identificador: `3`
   - Base Jubilación: $500.000,00
   - Base Obra Social: $500.000,00
   - Base Ley 19.032: $500.000,00

4. **Registro 4** (Línea 9): Datos Complementarios
   - Identificador: `4`
   - CUIL Empleado: `20123456789`
   - Código Obra Social: `1234567890`

### Verificación

Cada línea debe tener **exactamente 150 caracteres**. Para verificar:

```bash
# En Windows PowerShell:
Get-Content demo_liquidacion_arca_2026.txt | ForEach-Object { Write-Host "$($_.Length) caracteres" }

# En Linux/Mac:
cat demo_liquidacion_arca_2026.txt | while read line; do echo "${#line} caracteres"; done
```

### Codificación

El archivo está codificado en **Latin-1 (ANSI)** como requiere ARCA.

### Notas

- Los importes están multiplicados por 100 (sin decimales visibles)
- Ejemplo: $500.000,00 se representa como `000000500000000` (15 dígitos)
- Todos los campos de texto están rellenados con espacios a la derecha
- Todos los campos numéricos están rellenados con ceros a la izquierda
- **Registro 2 (Conceptos)**: 
  - Código AFIP ocupa 10 caracteres (posiciones 13-22)
  - 5 espacios entre código e importe (posiciones 23-27)
  - Importe ocupa 15 caracteres (posiciones 28-42)
- Todas las líneas se ajustan automáticamente: se cortan si exceden 150 caracteres y se rellenan con espacios si son menores

### Uso

Este archivo puede subirse directamente a ARCA para verificar que el formato es correcto.
