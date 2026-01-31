# Guía: actualización de convenios desde la nube

## Archivo de ejemplo

Usa `convenios_update_template.json` como guía para escribir los datos en la nube.

## Estructura del JSON

El archivo debe ser un **array de objetos**. Cada objeto tiene:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | string | Identificador único del ítem |
| `nombreCCT` | string | Nombre del convenio (ej. "Empleados de Comercio") |
| `categoria` | string | Categoría (ej. "Administrativo A") |
| `sueldoBasico` | number | Sueldo base |
| `adicionales` | object | Mapa de valores: `"clave": número` (ej. presentismo, antigüedad, zonas) |
| `ultimaActualizacion` | string | Fecha ISO 8601 (ej. `"2024-06-01T00:00:00.000Z"`) |

## Dónde publicar

1. **GitHub Raw**: sube el JSON a un repo y usa la URL Raw, por ejemplo:
   `https://raw.githubusercontent.com/USUARIO/REPO/main/convenios_update.json`

2. Configura esa URL en la app (por defecto se usa un ejemplo en `ApiService`).

## Comportamiento de la app

- Al abrir la app, intenta descargar el JSON desde la URL.
- Si hay conexión y la descarga es correcta, guarda los datos en el teléfono y muestra **"Escalas actualizadas al día"** en Convenios.
- Si falla (sin señal, error, etc.), carga los datos guardados localmente y muestra **"Usando datos locales"**.
