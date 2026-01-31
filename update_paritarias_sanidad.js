/**
 * =============================================================================
 * ROBOT DE ACTUALIZACIÓN DE PARITARIAS - SANIDAD (FATSA CCT 122/75, 108/75)
 * =============================================================================
 * 
 * Actualiza automáticamente las escalas salariales de las 24 jurisdicciones
 * basándose en el IPC oficial de INDEC.
 * 
 * Uso:
 *   node update_paritarias_sanidad.js
 * 
 * Requiere:
 *   - Variables de entorno en .env.local (NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY)
 *   - npm install @supabase/supabase-js axios dotenv
 * 
 * =============================================================================
 */

const { createClient } = require('@supabase/supabase-js');
const axios = require('axios');
require('dotenv').config({ path: '.env.local' });

// Configuración de Supabase
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Error: No se encontraron las variables de Supabase en .env.local");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Las 24 jurisdicciones argentinas con configuración inicial
const JURISDICCIONES_DEFAULT = [
  { key: 'buenosAires', nombre: 'Buenos Aires', esPatagonica: false },
  { key: 'caba', nombre: 'Ciudad Autónoma de Buenos Aires', esPatagonica: false },
  { key: 'catamarca', nombre: 'Catamarca', esPatagonica: false },
  { key: 'chaco', nombre: 'Chaco', esPatagonica: false },
  { key: 'chubut', nombre: 'Chubut', esPatagonica: true },
  { key: 'cordoba', nombre: 'Córdoba', esPatagonica: false },
  { key: 'corrientes', nombre: 'Corrientes', esPatagonica: false },
  { key: 'entreRios', nombre: 'Entre Ríos', esPatagonica: false },
  { key: 'formosa', nombre: 'Formosa', esPatagonica: false },
  { key: 'jujuy', nombre: 'Jujuy', esPatagonica: false },
  { key: 'laPampa', nombre: 'La Pampa', esPatagonica: true },
  { key: 'laRioja', nombre: 'La Rioja', esPatagonica: false },
  { key: 'mendoza', nombre: 'Mendoza', esPatagonica: false },
  { key: 'misiones', nombre: 'Misiones', esPatagonica: false },
  { key: 'neuquen', nombre: 'Neuquén', esPatagonica: true },
  { key: 'rioNegro', nombre: 'Río Negro', esPatagonica: true },
  { key: 'salta', nombre: 'Salta', esPatagonica: false },
  { key: 'sanJuan', nombre: 'San Juan', esPatagonica: false },
  { key: 'sanLuis', nombre: 'San Luis', esPatagonica: false },
  { key: 'santaCruz', nombre: 'Santa Cruz', esPatagonica: true },
  { key: 'santaFe', nombre: 'Santa Fe', esPatagonica: false },
  { key: 'santiagoDelEstero', nombre: 'Santiago del Estero', esPatagonica: false },
  { key: 'tierraDelFuego', nombre: 'Tierra del Fuego', esPatagonica: true },
  { key: 'tucuman', nombre: 'Tucumán', esPatagonica: false },
];

// Básicos por defecto (normal y patagónico)
const BASICOS_NORMAL = {
  profesional: 850000,
  tecnico: 680000,
  servicios: 580000,
  administrativo: 520000,
  maestranza: 480000,
};

const BASICOS_PATAGONICA = {
  profesional: 1020000,  // +20%
  tecnico: 816000,
  servicios: 696000,
  administrativo: 624000,
  maestranza: 576000,
};

// Genera el registro completo para una jurisdicción
function generarRegistroJurisdiccion(j, basicos) {
  return {
    jurisdiccion: j.key,
    nombre_mostrar: j.nombre,
    basico_profesional: basicos.profesional,
    basico_tecnico: basicos.tecnico,
    basico_servicios: basicos.servicios,
    basico_administrativo: basicos.administrativo,
    basico_maestranza: basicos.maestranza,
    antiguedad_pct_por_ano: 2.0,
    titulo_auxiliar_pct: 5.0,
    titulo_tecnico_pct: 7.0,
    titulo_universitario_pct: 10.0,
    tarea_critica_riesgo_pct: 10.0,
    zona_patagonica_pct: j.esPatagonica ? 20.0 : 0.0,
    nocturnas_pct: 15.0,
    monto_fallo_caja: 20000,
    jubilacion_pct: 11.0,
    ley_19032_pct: 3.0,
    obra_social_pct: 3.0,
    cuota_sindical_atsa_pct: 2.0,
    seguro_sepelio_pct: 1.0,
    aporte_solidario_fatsa_pct: 1.0,
    tope_base_previsional: 2500000,
    fuente_legal: 'FATSA CCT 122/75 - Paritarias 2026',
    updated_at: new Date().toISOString(),
    metadata: {
      tipo_ajuste: 'ipc',
      es_patagonica: j.esPatagonica,
    },
  };
}

async function runRobot() {
  console.log("🏥 Iniciando Robot de Actualización Sanidad (FATSA)...");
  console.log("📋 24 Jurisdicciones Federales - CCT 122/75, 108/75");
  console.log("");

  let ipcMensual = null;
  let fuente = "";

  // =========================================================================
  // 1. OBTENER IPC DESDE API OFICIAL (datos.gob.ar - INDEC)
  // =========================================================================
  try {
    console.log("📡 Consultando API Oficial (datos.gob.ar)...");
    // ID 101.1_I2NG_2016_M_22: IPC Nivel General Nacional (Índice Base 2016)
    const res = await axios.get(
      'https://apis.datos.gob.ar/series/api/series/?ids=101.1_I2NG_2016_M_22&limit=2&sort=desc&format=json',
      { timeout: 15000 }
    );

    if (res.data && res.data.data && res.data.data.length >= 2) {
      const actual = res.data.data[0][1];
      const anterior = res.data.data[1][1];
      const fecha = res.data.data[0][0];

      // Calcular variación mensual
      ipcMensual = parseFloat(((actual / anterior - 1) * 100).toFixed(2));
      fuente = `Ajuste automático IPC INDEC: ${ipcMensual}% (Mes: ${fecha})`;

      console.log(`✅ IPC detectado: ${ipcMensual}% (Mes base: ${fecha})`);
    } else {
      throw new Error("Formato de datos insuficiente");
    }
  } catch (e) {
    console.error("⚠️  Error consultando API oficial:", e.message);
    console.log("📊 Continuando sin actualización por IPC...");
    ipcMensual = 0;
    fuente = "Sin ajuste IPC - Valores base";
  }

  // =========================================================================
  // 2. VERIFICAR SI EXISTE LA TABLA O USAR syncra_entities
  // =========================================================================
  let usarEntities = false;
  let paritariasExistentes = [];

  try {
    // Intentar leer desde tabla dedicada
    const { data, error } = await supabase
      .from('maestro_paritarias_sanidad')
      .select('*');

    if (error) {
      console.log("ℹ️  Tabla maestro_paritarias_sanidad no existe, usando syncra_entities...");
      usarEntities = true;
    } else {
      paritariasExistentes = data || [];
      console.log(`📊 Encontradas ${paritariasExistentes.length} jurisdicciones en tabla dedicada`);
    }
  } catch (e) {
    console.log("ℹ️  Usando syncra_entities como storage...");
    usarEntities = true;
  }

  // Si usamos entities, leer de ahí
  if (usarEntities) {
    try {
      const { data: entitiesData } = await supabase
        .from('syncra_entities')
        .select('data')
        .eq('type', 'maestro_paritarias_sanidad')
        .eq('key', '')
        .single();

      if (entitiesData?.data && Array.isArray(entitiesData.data)) {
        paritariasExistentes = entitiesData.data;
        console.log(`📊 Encontradas ${paritariasExistentes.length} jurisdicciones en entities`);
      }
    } catch (e) {
      console.log("ℹ️  No hay datos previos, se crearán las 24 jurisdicciones...");
    }
  }

  // =========================================================================
  // 3. GENERAR/ACTUALIZAR DATOS DE TODAS LAS JURISDICCIONES
  // =========================================================================
  const paritariasActualizadas = [];

  for (const j of JURISDICCIONES_DEFAULT) {
    // Buscar si ya existe
    const existente = paritariasExistentes.find(p => p.jurisdiccion === j.key);
    const basicos = j.esPatagonica ? BASICOS_PATAGONICA : BASICOS_NORMAL;

    if (existente && ipcMensual > 0) {
      // Actualizar con IPC
      const factor = 1 + (ipcMensual / 100);
      
      const actualizado = {
        ...existente,
        basico_profesional: Math.round(existente.basico_profesional * factor),
        basico_tecnico: Math.round(existente.basico_tecnico * factor),
        basico_servicios: Math.round(existente.basico_servicios * factor),
        basico_administrativo: Math.round(existente.basico_administrativo * factor),
        basico_maestranza: Math.round(existente.basico_maestranza * factor),
        monto_fallo_caja: Math.round(existente.monto_fallo_caja * factor),
        tope_base_previsional: Math.round(existente.tope_base_previsional * factor),
        fuente_legal: fuente,
        updated_at: new Date().toISOString(),
      };
      
      paritariasActualizadas.push(actualizado);
      console.log(`   📈 ${j.nombre}: Actualizado +${ipcMensual}%`);
    } else if (existente) {
      // Mantener sin cambios
      paritariasActualizadas.push({
        ...existente,
        updated_at: new Date().toISOString(),
      });
      console.log(`   ✓ ${j.nombre}: Sin cambios`);
    } else {
      // Crear nuevo
      const nuevo = generarRegistroJurisdiccion(j, basicos);
      nuevo.fuente_legal = fuente || 'FATSA CCT 122/75 - Paritarias 2026';
      paritariasActualizadas.push(nuevo);
      console.log(`   🆕 ${j.nombre}: Creado ${j.esPatagonica ? '(Patagónica)' : ''}`);
    }
  }

  // =========================================================================
  // 4. GUARDAR EN SUPABASE
  // =========================================================================
  console.log("");
  console.log("💾 Guardando en Supabase...");

  try {
    if (usarEntities) {
      // Guardar en syncra_entities
      await supabase.from('syncra_entities').upsert({
        type: 'maestro_paritarias_sanidad',
        key: '',
        data: paritariasActualizadas,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'type,key' });
      
      console.log("✅ Guardado en syncra_entities");
    } else {
      // Guardar en tabla dedicada
      for (const p of paritariasActualizadas) {
        await supabase
          .from('maestro_paritarias_sanidad')
          .upsert(p, { onConflict: 'jurisdiccion' });
      }
      console.log("✅ Guardado en maestro_paritarias_sanidad");
    }

    console.log("");
    console.log("🚀 ¡Sincronización Sanidad Completada!");
    console.log(`   📊 ${paritariasActualizadas.length} jurisdicciones procesadas`);
    console.log(`   📈 IPC aplicado: ${ipcMensual || 0}%`);
    console.log(`   📅 Fecha: ${new Date().toLocaleString('es-AR')}`);

  } catch (error) {
    console.error("❌ Error guardando en Supabase:", error.message);
    process.exit(1);
  }
}

// =========================================================================
// EJECUCIÓN
// =========================================================================
runRobot().catch(err => {
  console.error("❌ Error fatal:", err);
  process.exit(1);
});
