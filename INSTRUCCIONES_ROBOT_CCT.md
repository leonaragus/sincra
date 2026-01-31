# 🤖 ROBOT CCT - INSTRUCCIONES DE USO

## 📋 ¿Qué hace este robot?

El Robot CCT actualiza automáticamente los convenios colectivos de trabajo en Supabase sin necesidad de modificar código.

---

## 🚀 INSTALACIÓN (SOLO UNA VEZ)

### **Paso 1: Crear acceso directo en el escritorio**

1. **Haz clic derecho** en `ACTUALIZAR_CCT.bat`
2. Selecciona **"Enviar a" → "Escritorio (crear acceso directo)"**
3. Renombra el acceso directo a: **"🤖 Actualizar CCT"**

### **Paso 2: Verificar configuración de Supabase**

El archivo `lib/config/supabase_config.dart` ya tiene configurado:

```dart
url: 'https://stxhajsclwfktyvawmr.supabase.co'
anonKey: 'sb_publishable_BLRB7OgEcoA0TWZIiPNn-Q_vW7VovCZ'
```

✅ **Ya está listo para usar**

---

## 📝 USO DIARIO

### **1. Editar el archivo JSON**

Abre `convenios_update.json` y modifica según necesites:

```json
{
  "updates": [
    {
      "cct_codigo": "CCT_122/75",
      "version": 2,
      "fecha_vigencia": "2026-02-01",
      "cambios": {
        "tipo": "actualizacion_salarial",
        "descripcion": "Aumento paritario febrero 2026",
        "porcentaje": 15.5,
        "categorias_afectadas": [
          {
            "codigo": "A",
            "nombre": "Enfermero Profesional",
            "sueldo_basico_anterior": 850000,
            "sueldo_basico_nuevo": 982250
          }
        ]
      }
    }
  ]
}
```

### **2. Ejecutar el robot**

- **Doble clic** en el icono del escritorio **"🤖 Actualizar CCT"**
- O ejecuta directamente `ACTUALIZAR_CCT.bat`

### **3. Verificar resultado**

El robot mostrará:
- ✅ Validación del JSON
- ✅ Conexión a Supabase
- ✅ Procesamiento de cada CCT
- ✅ Resumen final

---

## 📊 ESTRUCTURA DEL JSON

### **Campos obligatorios:**

| Campo | Descripción | Ejemplo |
|-------|-------------|---------|
| `cct_codigo` | Código del CCT | `"CCT_122/75"` |
| `version` | Número de versión | `2` |
| `fecha_vigencia` | Fecha de inicio | `"2026-02-01"` |
| `cambios` | Objeto con los cambios | `{...}` |

### **Tipos de cambios soportados:**

1. **Actualización salarial**: Incremento de sueldos básicos
2. **Nuevo adicional**: Agregar nuevos conceptos
3. **Modificación adicional**: Cambiar valores existentes
4. **Eliminación adicional**: Quitar conceptos

---

## 🔍 PRUEBA DE FUNCIONAMIENTO

### **Ejecuta esto en Supabase SQL Editor:**

```sql
-- Ver todas las actualizaciones registradas
SELECT * FROM cct_actualizaciones ORDER BY created_at DESC LIMIT 10;

-- Ver ejecuciones del robot
SELECT * FROM cct_robot_ejecuciones ORDER BY created_at DESC LIMIT 5;
```

---

## ❓ SOLUCIÓN DE PROBLEMAS

### **Error: "No se encontró convenios_update.json"**
- Verifica que el archivo existe en la misma carpeta que `ACTUALIZAR_CCT.bat`

### **Error: "El archivo JSON tiene errores de formato"**
- Usa un validador JSON online (jsonlint.com)
- Verifica que todas las llaves y corchetes estén cerrados
- Verifica que todas las comillas sean dobles `"` (no simples `'`)

### **Error: "No se pudo conectar a Supabase"**
- Verifica tu conexión a Internet
- Verifica que la URL y anonKey en `supabase_config.dart` sean correctas

---

## 📁 ARCHIVOS DEL SISTEMA

| Archivo | Descripción |
|---------|-------------|
| `ACTUALIZAR_CCT.bat` | Script principal (ejecutable) |
| `robot_cct_updater.ps1` | Script PowerShell de actualización |
| `convenios_update.json` | Datos de actualización (editable) |
| `PRUEBA_SUPABASE.sql` | Prueba de funcionamiento de BD |

---

## ✅ VERIFICACIÓN POST-ACTUALIZACIÓN

Después de ejecutar el robot:

1. **En Supabase**: Verifica que aparezcan los registros en `cct_actualizaciones`
2. **En la App**: Los cambios se sincronizan automáticamente en el próximo inicio
3. **En Liquidaciones**: Los nuevos valores se aplican en liquidaciones futuras

---

## 🎯 EJEMPLO COMPLETO

**Escenario:** Actualizar sueldos de Sanidad CCT 122/75 con 15% de aumento

1. Edita `convenios_update.json`:
```json
{
  "updates": [
    {
      "cct_codigo": "CCT_122/75",
      "version": 2,
      "fecha_vigencia": "2026-02-01",
      "cambios": {
        "tipo": "actualizacion_salarial",
        "porcentaje": 15.0,
        "categorias_afectadas": [
          {"codigo": "A", "sueldo_basico_nuevo": 980000}
        ]
      }
    }
  ]
}
```

2. Ejecuta el BAT
3. Verifica en Supabase
4. Listo ✅

---

**¿Dudas?** Revisa `GUIA_INTEGRACION_ROBOT_BAT.md` para más detalles técnicos.
