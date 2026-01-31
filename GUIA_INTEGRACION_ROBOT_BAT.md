# 🤖 GUÍA DE INTEGRACIÓN DEL ROBOT BAT

## 📋 OBJETIVO

Integrar tus robots BAT existentes (sanidad y docentes) con el sistema de CCT para que las actualizaciones se sincronicen automáticamente en Supabase.

---

## 🎯 METODOLOGÍA (Igual que Paritarias)

### **Cómo funciona actualmente (Paritarias):**

1. ✅ Robot BAT actualiza datos en Supabase (tabla `maestro_paritarias`)
2. ✅ App Flutter sincroniza desde Supabase
3. ✅ Muestra banner: "Paritarias actualizadas al [fecha]"
4. ✅ Usuario puede hacer refresh manual

### **Cómo funcionará para CCT (NUEVA):**

1. ✅ Robot BAT actualiza CCT (ejecutas `actualizar_cct.bat`)
2. ✅ Robot guarda resultados en `cct_resultados.json`
3. ✅ App Flutter lee el JSON y sube a Supabase (`cct_master`)
4. ✅ Muestra banner: "CCT actualizados al [fecha] (X convenios)"
5. ✅ Todos los usuarios se sincronizan automáticamente

---

## 🔧 INTEGRACIÓN PASO A PASO

### **Paso 1: Ubicar tus scripts existentes**

Tus robots actuales deben estar en alguna ubicación como:

```
C:\robots\
  ├── actualizar_sanidad.bat
  ├── actualizar_sanidad.py (o .js, etc.)
  ├── actualizar_docentes.bat
  └── actualizar_docentes.py
```

**Necesitamos saber:**
1. ¿Dónde están ubicados? (ruta completa)
2. ¿Qué hacen exactamente? (¿de dónde descargan los datos?)
3. ¿En qué formato guardan los resultados?

---

### **Paso 2: Modificar tus scripts para generar JSON**

#### **Opción A: Si tus scripts ya generan salida**

Modifica tus scripts Python (o el lenguaje que uses) para que al final generen:

**Archivo:** `cct_resultados.json`

**Formato:**

```json
{
  "fecha_ejecucion": "2026-01-27T10:30:00",
  "exitosa": true,
  "ccts": [
    {
      "codigo": "122/75",
      "nombre": "FATSA - Federacion de Trabajadores de Sanidad",
      "sector": "sanidad",
      "subsector": "privado",
      "estructura": {
        "categorias": {
          "profesional": 850000,
          "tecnico": 680000,
          "servicios": 580000,
          "administrativo": 520000,
          "maestranza": 480000
        },
        "antiguedad_pct_anio": 2.0,
        "zona_patagonica_pct": 20.0,
        "titulo_auxiliar_pct": 5.0,
        "titulo_tecnico_pct": 7.0,
        "titulo_universitario_pct": 10.0
      },
      "descripcion": "Convenio Colectivo FATSA actualizado enero 2026",
      "fuente_oficial": "https://www.boletinoficial.gob.ar/..."
    },
    {
      "codigo": "130/75",
      "nombre": "CCT Docentes Privados",
      "sector": "docente",
      "subsector": "privado",
      "estructura": {
        "valor_indice": 210.50,
        "piso_salarial": 745311,
        "fonid_monto": 95000,
        "conectividad_monto": 12000
      },
      "descripcion": "CCT Docentes actualizado",
      "fuente_oficial": "https://..."
    }
  ]
}
```

#### **Ejemplo en Python:**

```python
import json
from datetime import datetime

# Tu lógica actual para obtener datos de CCT
# ...

# Al final, generar JSON
resultados = {
    "fecha_ejecucion": datetime.now().isoformat(),
    "exitosa": True,
    "ccts": [
        {
            "codigo": "122/75",
            "nombre": "FATSA",
            "sector": "sanidad",
            "estructura": {
                "categorias": {
                    "profesional": 850000,
                    # ... más datos
                }
            },
            "descripcion": "Actualizado desde Boletín Oficial",
            "fuente_oficial": "https://..."
        }
    ]
}

# Guardar JSON
with open('cct_resultados.json', 'w', encoding='utf-8') as f:
    json.dump(resultados, f, ensure_ascii=False, indent=2)

print("Resultados guardados en cct_resultados.json")
```

---

### **Paso 3: Editar actualizar_cct.bat**

Abre el archivo `actualizar_cct.bat` que creamos y reemplaza las líneas:

**ANTES:**
```batch
REM AQUI: Integrar tu script actual de sanidad
REM Ejemplo: python scripts\actualizar_fatsa.py

REM AQUI: Integrar tu script actual de docentes
REM Ejemplo: python scripts\actualizar_docentes.py
```

**DESPUÉS:**
```batch
REM Ejecutar tu script de sanidad
echo Actualizando FATSA...
python C:\ruta\a\tu\actualizar_sanidad.py
if %errorlevel% neq 0 (
    echo ERROR en script de sanidad
    goto ERROR
)

REM Ejecutar tu script de docentes
echo Actualizando Docentes...
python C:\ruta\a\tu\actualizar_docentes.py
if %errorlevel% neq 0 (
    echo ERROR en script de docentes
    goto ERROR
)
```

**Y elimina** la sección que genera JSON de ejemplo (líneas 41-69), porque tus scripts ya lo generarán.

---

### **Paso 4: Probar el Robot**

1. Ejecutar `actualizar_cct.bat` manualmente
2. Verificar que se generó `cct_resultados.json`
3. Verificar el contenido del JSON

**Verificar estructura:**
```bash
# Ver el archivo generado
notepad cct_resultados.json
```

Debe tener:
- ✅ Campo `fecha_ejecucion`
- ✅ Campo `exitosa`
- ✅ Array `ccts` con al menos 1 CCT
- ✅ Cada CCT con `codigo`, `nombre`, `sector`, `estructura`

---

### **Paso 5: Subir a Supabase desde la App**

#### **Opción A: Automático (Recomendado)**

La app detecta automáticamente el archivo y lo sube:

1. Abrir app Flutter
2. Ir a "Biblioteca CCT"
3. El banner mostrará: "CCT actualizados al [fecha]"
4. ¡Listo! Los CCT ya están en Supabase

#### **Opción B: Manual**

Agregar botón en la pantalla de CCT:

```dart
ElevatedButton.icon(
  onPressed: () async {
    // Ruta donde guardó el robot
    final rutaJson = 'C:\\elevar_liquidacion\\elevar_liquidacion\\cct_resultados.json';
    
    final resultado = await CCTCloudService.subirResultadosRobot(
      rutaArchivoResultados: rutaJson,
      ejecutadoPor: 'Usuario',
    );
    
    if (resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${resultado['cct_actualizados']} CCT subidos a Supabase'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Recargar
      _cargarCCTs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${resultado['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
  icon: const Icon(Icons.cloud_upload),
  label: const Text('Subir Resultados Robot'),
),
```

---

### **Paso 6: Verificar en Supabase**

1. Abrir Supabase Dashboard
2. Ir a Table Editor
3. Verificar tabla `cct_master`:
   - Debe tener los CCT actualizados
   - Fecha de actualización correcta
   - JSON estructura completo

4. Verificar tabla `cct_robot_ejecuciones`:
   - Debe tener registro de la ejecución
   - Log completo
   - Estadísticas

---

## 📝 EJEMPLO COMPLETO

### **Tu robot actual (sanidad):**

```python
# actualizar_sanidad.py
import requests
import json
from bs4 import BeautifulSoup

# 1. Descargar datos de fuente oficial
url = "https://fuente-oficial-fatsa.com/paritarias"
response = requests.get(url)
soup = BeautifulSoup(response.text, 'html.parser')

# 2. Parsear datos
profesional = soup.find('td', text='Profesional').find_next('td').text
tecnico = soup.find('td', text='Técnico').find_next('td').text
# ... etc

# 3. NUEVO: Generar JSON de salida
cct_fatsa = {
    "codigo": "122/75",
    "nombre": "FATSA",
    "sector": "sanidad",
    "estructura": {
        "categorias": {
            "profesional": float(profesional.replace(',', '').replace('$', '')),
            "tecnico": float(tecnico.replace(',', '').replace('$', '')),
            # ... más categorías
        }
    },
    "fuente_oficial": url
}

# 4. Guardar
with open('cct_sanidad_temp.json', 'w') as f:
    json.dump(cct_fatsa, f, indent=2)

print("FATSA actualizado correctamente")
```

### **Consolidador (nuevo):**

```python
# consolidar_resultados.py
import json
from datetime import datetime

# Leer resultados individuales
with open('cct_sanidad_temp.json', 'r') as f:
    sanidad = json.load(f)

with open('cct_docentes_temp.json', 'r') as f:
    docentes = json.load(f)

# Consolidar
resultado_final = {
    "fecha_ejecucion": datetime.now().isoformat(),
    "exitosa": True,
    "ccts": [sanidad, docentes]
}

# Guardar
with open('cct_resultados.json', 'w', encoding='utf-8') as f:
    json.dump(resultado_final, f, ensure_ascii=False, indent=2)

print("Resultados consolidados en cct_resultados.json")
```

### **actualizar_cct.bat (editado):**

```batch
@echo off
echo Actualizando CCT...

REM Ejecutar scripts
python actualizar_sanidad.py
python actualizar_docentes.py
python consolidar_resultados.py

echo.
echo CCT actualizados!
echo Ahora abre la app y ve a Biblioteca CCT
pause
```

---

## ⚡ VENTAJAS DE ESTA METODOLOGÍA

### **vs Actualización manual:**
- ✅ **Automático:** Un click ejecuta todo
- ✅ **Centralizado:** Todos usan los mismos CCT actualizados
- ✅ **Historial:** Se registran todas las actualizaciones
- ✅ **Sin errores:** No hay que re-tipear valores

### **vs Integrar el robot en la app:**
- ✅ **Más simple:** No hay que migrar código a Dart
- ✅ **Usa lo que ya funciona:** Tu robot ya está probado
- ✅ **Flexible:** Puedes mejorar el robot sin tocar la app

---

## 🚨 TROUBLESHOOTING

### **Problema 1: El JSON no se genera**

**Solución:**
- Verificar que tus scripts Python funcionen correctamente
- Ejecutar manualmente cada script desde CMD
- Verificar logs de error

### **Problema 2: La app no detecta el JSON**

**Solución:**
- Verificar ruta del archivo en el código
- Usar ruta absoluta: `C:\elevar_liquidacion\elevar_liquidacion\cct_resultados.json`
- Verificar permisos de lectura

### **Problema 3: Error al subir a Supabase**

**Solución:**
- Verificar conexión a internet
- Verificar que ejecutaste el SQL consolidado
- Verificar que la tabla `cct_master` existe
- Revisar formato del JSON (debe coincidir con el esquema)

---

## 📞 SOPORTE

Si necesitas ayuda con:
- Modificar tus scripts existentes
- Generar el JSON correcto
- Integrar con la app
- Verificar la sincronización

¡Avisa y te ayudo! 🚀

---

## ✅ CHECKLIST DE INTEGRACIÓN

- [ ] Ubicar tus scripts BAT actuales (sanidad y docentes)
- [ ] Modificar scripts para generar JSON de salida
- [ ] Probar scripts individualmente
- [ ] Crear script consolidador (opcional)
- [ ] Editar `actualizar_cct.bat` con rutas reales
- [ ] Ejecutar `actualizar_cct.bat` por primera vez
- [ ] Verificar que se genera `cct_resultados.json`
- [ ] Abrir app Flutter → Biblioteca CCT
- [ ] Verificar que aparece el banner
- [ ] Click en "Sincronizar"
- [ ] Verificar en Supabase que se subieron los CCT
- [ ] ✅ ¡Todo funcionando!

---

**¡Con esto, tendrás CCT siempre actualizados automáticamente!** 🎉
