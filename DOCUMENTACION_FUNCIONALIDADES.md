# 📋 DOCUMENTACIÓN COMPLETA - ELEVAR LIQUIDACIÓN
## Sistema de Gestión de Nómina para Argentina

---

## 🏠 PANTALLA PRINCIPAL (Home Screen)

### Funcionalidades:
1. **Header con Logo y Ayuda**
   - Muestra el título "LIKIDADOR"
   - Botón de ayuda (ícono de interrogación)
   - Diseño glassmorphism

2. **Tres Botones Principales:**
   - **"Tu Empresa"**: Navega a la pantalla de creación/edición de empresas
   - **"Liquidador Final"**: Navega a la pantalla de liquidación de sueldos
   - **"Convenios"**: Navega a la pantalla de visualización de convenios colectivos

3. **Sección de Empresas Guardadas:**
   - Lista todas las empresas creadas
   - Muestra: Razón Social, CUIT, Domicilio
   - **Botón de Editar** (lápiz): Permite editar la empresa
   - **Botón de Empleados** (ícono de personas): Muestra la lista de empleados de esa empresa
   - **Botón de Eliminar** (papelera): Elimina la empresa con confirmación

4. **Notificaciones:**
   - Muestra un SnackBar cuando los convenios se actualizan desde el servidor

---

## 🏢 PANTALLA DE EMPRESA (Empresa Screen)

### Funcionalidades:

1. **Datos Básicos de la Empresa:**
   - **Razón Social**: Campo obligatorio, texto libre
   - **CUIT**: Campo obligatorio, formato automático XX-XXXXXXXX-X
   - **Domicilio**: Campo obligatorio, texto libre

2. **Selección de Convenios Colectivos:**
   - **Múltiples Convenios**: Permite seleccionar varios convenios (checkbox)
   - **Opción "Fuera de Convenio"**: Checkbox para empresas sin convenio
   - Lista todos los convenios disponibles de Argentina
   - Muestra: Nombre del convenio y número de CCT
   - Los convenios seleccionados se guardan como lista JSON

3. **Logo de la Empresa:**
   - Selector de imagen desde galería o cámara
   - Vista previa del logo seleccionado
   - Opción de eliminar el logo

4. **Firma Digital / Sello:**
   - Selector de imagen desde galería o cámara
   - Vista previa de la firma/sello
   - Opción de eliminar la firma

5. **Formato de Recibo:**
   - Selector de formato de recibo de sueldos
   - Formatos disponibles: Clásico LCT, Moderno, Compacto, etc.
   - Descripción de cada formato

6. **Guardado:**
   - Botón "Crear Empresa" o "Actualizar Empresa"
   - Valida que todos los campos obligatorios estén completos
   - Guarda en SharedPreferences
   - Compatibilidad con formato antiguo (un solo convenio)

---

## 👤 PANTALLA DE EMPLEADO (Empleado Screen)

### Funcionalidades:

1. **Datos del Empleado (Obligatorios para Recibo Oficial):**
   - **Nombre**: Campo obligatorio
   - **Apellido**: Campo obligatorio
   - **CUIL**: Campo obligatorio, formato automático XX-XXXXXXXX-X (11 dígitos)
   - **Fecha de Ingreso**: 
     - Date Picker con calendario
     - Validación: Solo permite fechas que correspondan a personas mayores de 18 años
     - Formato: DD/MM/YYYY
     - Campo de solo lectura que abre el calendario al tocar
   - **Cargo**: Campo obligatorio, texto libre

2. **Convenio y Categoría:**
   - **Selector de Convenio**:
     - Opción "Fuera de Convenio"
     - Lista de convenios seleccionados por la empresa
     - Muestra nombre y número CCT
   - **Selector de Categoría**:
     - Se carga dinámicamente según el convenio seleccionado
     - Muestra nombre de categoría, descripción (quiénes están incluidos) y salario base
     - Solo aparece si se selecciona un convenio (no para "Fuera de Convenio")

3. **Validaciones:**
   - CUIL debe tener exactamente 11 dígitos
   - Fecha de ingreso debe ser válida y corresponder a mayor de 18 años
   - Todos los campos obligatorios deben estar completos

4. **Guardado:**
   - Botón "Guardar Empleado" o "Actualizar Empleado"
   - Guarda en SharedPreferences asociado a la empresa (por razón social)
   - Después de guardar: Pregunta si desea agregar otro empleado
   - Si edita: Solo muestra "Empleado actualizado"

5. **Modo Edición:**
   - Carga automáticamente los datos del empleado existente
   - Pre-llena todos los campos
   - Formatea CUIL y fecha correctamente

---

## 📋 PANTALLA DE LISTA DE EMPLEADOS (Lista Empleados Screen)

### Funcionalidades:

1. **Visualización de Empleados:**
   - Lista todos los empleados de la empresa seleccionada
   - Muestra para cada empleado:
     - Inicial del nombre en círculo
     - Nombre completo
     - CUIL formateado
     - Cargo
     - Convenio asignado

2. **Acciones por Empleado:**
   - **Botón de Historial** (ícono de reloj): Muestra el histórico de recibos generados
   - **Botón de Editar** (lápiz): Edita el empleado
   - **Botón de Eliminar** (papelera): Elimina el empleado con confirmación

3. **Historial de Recibos:**
   - Se abre al tocar un empleado o presionar el botón de historial
   - Muestra diálogo con:
     - Lista de recibos ordenados por fecha descendente (más recientes primero)
     - Para cada recibo: Período, Fecha de generación, Sueldo Neto
     - Botón de descarga para abrir el PDF
   - Si no hay recibos: Muestra mensaje "No hay recibos generados"

4. **Agregar Empleado:**
   - Botón "+" en el AppBar
   - Navega a la pantalla de creación de empleado

5. **Estado Vacío:**
   - Si no hay empleados: Muestra mensaje y botón para agregar

---

## 💰 PANTALLA LIQUIDADOR FINAL (Liquidador Final Screen)

### Funcionalidades:

1. **Selección de Empresa:**
   - Dropdown con todas las empresas creadas
   - Si no hay empresas: Muestra botón "Crear Empresa" que navega a la pantalla de creación
   - Al seleccionar empresa: Carga automáticamente sus empleados

2. **Selección de Empleado:**
   - Dropdown con empleados de la empresa seleccionada
   - Si no hay empleados: Muestra botón "Crear Empleado" que navega a la pantalla de creación
   - Muestra solo nombre en el campo seleccionado (evita texto sobreescrito)
   - En el menú desplegable muestra: Nombre y CUIL formateado
   - Altura máxima del menú: 300px (evita overflow)

3. **Datos de Liquidación:**
   - **Sueldo Básico**: Campo numérico con decimales
   - **Período**: Texto libre (ej: "Enero 2026")
   - **Fecha de Pago**: Texto libre formato DD/MM/YYYY

4. **Novedades:**
   - **Horas Extras 50%**: Campo numérico con decimales
   - **Horas Extras 100%**: Campo numérico con decimales
   - **Premios**: Campo numérico con decimales
   - **Conceptos No Remunerativos**: Campo numérico con decimales
   - **Afiliado Sindical**: Checkbox (afecta el cálculo de cuota sindical)
   - **Impuesto a las Ganancias**: Campo numérico para ingreso manual

6. **Tabla de Detalles de Liquidación:**
   - **4 Columnas:**
     - Concepto
     - Remunerativo (Débito)
     - No Remunerativo (Crédito)
     - Deducciones (Crédito)
   - Muestra todos los conceptos:
     - Sueldo Básico
     - Horas Extras 50% (si > 0)
     - Horas Extras 100% (si > 0)
     - Premios (si > 0)
     - **Cada concepto no remunerativo agregado** (se muestra individualmente con su nombre)
     - Jubilación (SIPA) - 11%
     - Ley 19.032 (PAMI) - 3%
     - Obra Social - 3%
     - Cuota Sindical - 2.5% (solo si está afiliado)
     - Impuesto a las Ganancias (si > 0)

6. **Totales Destacados:**
   - **Sueldo Bruto**: Suma de todos los conceptos remunerativos
   - **Total No Remunerativo**: Suma de conceptos no remunerativos
   - **Total Deducciones**: Suma de todos los aportes e impuestos
   - **SUELDO NETO A COBRAR**: Sueldo Bruto - Deducciones + No Remunerativo

7. **Cálculos Automáticos (Argentina 2026):**
   - **Jubilación (SIPA)**: 11% sobre sueldo bruto
   - **Ley 19.032 (PAMI)**: 3% sobre sueldo bruto
   - **Obra Social**: 3% sobre sueldo bruto
   - **Cuota Sindical**: 2.5% sobre sueldo bruto (solo si está afiliado)
   - **Impuesto a las Ganancias**: Ingreso manual (stub para futura implementación)

8. **Generación de Recibo PDF:**
   - Botón "Generar Recibo PDF"
   - Valida que todos los datos estén completos
   - Genera PDF con formato seleccionado en la empresa
   - Guarda el archivo PDF en el directorio de documentos
   - **Guarda información del recibo** en SharedPreferences asociado al CUIL del empleado
   - Muestra diálogo de éxito con opción de abrir el PDF
   - El recibo queda registrado en el histórico del empleado

---

## 📄 PANTALLA DE CONVENIOS (Convenios Screen)

### Funcionalidades:

1. **Lista de Convenios Colectivos:**
   - Muestra todos los convenios de Argentina disponibles
   - Búsqueda por nombre o número CCT
   - Cada tarjeta muestra:
     - Nombre del convenio
     - Número CCT
     - Actividad (si aplica)
     - Descripción
     - Cantidad de categorías, descuentos y zonas

2. **Detalle de Convenio:**
   - Al tocar un convenio: Abre diálogo con detalles completos
   - **Categorías**: 
     - Lista todas las categorías del convenio
     - Muestra: Nombre, Descripción (quiénes están incluidos), Salario Base
   - **Descuentos**: Lista descuentos con porcentajes
   - **Zonas**: Lista zonas con adicionales porcentuales
   - **Adicionales**: Presentismo y Antigüedad

3. **Edición de Convenios:**
   - Modo edición para modificar convenios
   - Agregar/editar/eliminar categorías, descuentos y zonas
   - Los cambios se guardan localmente

4. **Sincronización:**
   - Indicador de estado de sincronización
   - Muestra si los datos están actualizados al día o son locales

---

## 💾 ALMACENAMIENTO DE DATOS (SharedPreferences)

### Estructura de Datos Guardados:

1. **Empresas:**
   - Clave: `empresas` (List<String>)
   - Formato: `razonSocial|CUIT|domicilio|convenio|logoPath|firmaPath|formatoRecibo`
   - Clave adicional: `empresa_convenios_[razonSocial]` (JSON List<String>)

2. **Empleados:**
   - Clave: `empleados_[razonSocial]` (JSON)
   - Formato: Lista de Map con:
     - nombre, apellido, cuil, fechaIngreso, cargo
     - convenioId, convenioNombre, categoriaId, categoriaNombre

3. **Recibos Generados:**
   - Clave: `recibos_[CUIL]` (JSON)
   - Formato: Lista de Map con:
     - fechaGeneracion (ISO8601)
     - periodo, fechaPago
     - ruta (path del archivo PDF)
     - sueldoNeto

---

## 🎨 DISEÑO Y UX

### Características:
- **Tema Oscuro**: Diseño glassmorphism con colores pastel
- **Navegación Intuitiva**: Flujo lógico entre pantallas
- **Validaciones en Tiempo Real**: Formateo automático de CUIT/CUIL
- **Feedback Visual**: SnackBars, diálogos de confirmación
- **Responsive**: Adaptable a diferentes tamaños de pantalla

---

## 📊 FLUJO DE TRABAJO COMPLETO

### 1. Crear Empresa:
   - Home → "Tu Empresa" → Ingresar datos → Seleccionar convenios → Guardar

### 2. Agregar Empleados:
   - Home → Seleccionar empresa → Botón empleados → "+" → Ingresar datos → Guardar

### 3. Generar Recibo:
   - Home → "Liquidador Final" → Seleccionar empresa → Seleccionar empleado
   - **Se cargan automáticamente**: Datos del empleado (solo lectura), convenio, categoría
   - **Sueldo básico**: Se carga automáticamente desde la categoría (si está disponible), o se ingresa manualmente
   - Ingresar período y fecha de pago
   - Agregar novedades (horas extras, premios, etc.)
   - **Agregar conceptos no remunerativos**: Usar el botón "+" para agregar múltiples conceptos con nombre y monto
   - Ver tabla de liquidación con cálculos automáticos (incluye cada concepto no remunerativo individualmente)
   - Generar PDF

### 4. Ver Historial:
   - Home → Seleccionar empresa → Botón empleados → Tocar empleado o botón historial
   - Ver lista de recibos → Descargar PDF

---

## ✅ VALIDACIONES Y SEGURIDAD

- CUIT/CUIL: Formato automático y validación de longitud
- Fecha de Ingreso: Solo mayores de 18 años
- Campos Obligatorios: Validación antes de guardar
- Confirmaciones: Diálogos para eliminar empresas/empleados
- Manejo de Errores: Try-catch en operaciones críticas
- Verificación de Montaje: Checks `mounted` antes de setState

---

## 🔧 TECNOLOGÍAS Y DEPENDENCIAS

- **Flutter**: Framework principal
- **SharedPreferences**: Almacenamiento local
- **PDF**: Generación de recibos
- **Image Picker**: Selección de logos y firmas
- **Open File**: Abrir PDFs generados
- **Path Provider**: Gestión de rutas de archivos
- **Intl**: Formateo de fechas y números

---

## 📝 NOTAS IMPORTANTES

- Los datos se guardan localmente en el dispositivo
- Los recibos PDF se guardan en el directorio de documentos de la app
- Compatibilidad con formato antiguo de empresas (un solo convenio)
- Los cálculos siguen la legislación argentina vigente 2026
- El impuesto a las ganancias requiere ingreso manual (stub para futura implementación)

---

---

## 🆕 FUNCIONALIDADES RECIENTES (Última Actualización)

### Pantalla Liquidador Final - Mejoras:

1. **Carga Automática de Datos del Empleado:**
   - Al seleccionar un empleado, se muestra automáticamente una sección con todos sus datos en solo lectura
   - Incluye: Nombre, CUIL, Cargo, Fecha de Ingreso, Convenio y Categoría
   - Estos datos no se pueden editar desde el liquidador, solo desde la pantalla de empleados

2. **Sueldo Básico Automático:**
   - Si el empleado tiene una categoría asignada con salario base, se carga automáticamente
   - Si no hay categoría o salario base, el campo queda en 0 y se puede ingresar manualmente

3. **Gestión de Múltiples Conceptos No Remunerativos:**
   - Sistema mejorado que permite agregar, editar y eliminar múltiples conceptos no remunerativos
   - Cada concepto tiene un nombre personalizado y un monto
   - Se muestran individualmente en la tabla de liquidación
   - Botones intuitivos para agregar (+), editar (lápiz) y eliminar (papelera) cada concepto

---

**Versión**: 1.0.0+2  
**Última actualización**: Enero 2026
