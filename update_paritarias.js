const { createClient } = require('@supabase/supabase-js');
const axios = require('axios');
require('dotenv').config({ path: '.env.local' });

// Configuración de Supabase desde tus variables de entorno
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Error: No se encontraron las variables de Supabase en .env.local");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function runRobot() {
  console.log("🤖 Iniciando Robot de Actualización Federal...");

  let ipcMensual = null;
  let fuente = "";

  // FUENTE: API Oficial datos.gob.ar (Serie de tiempo IPC General)
  try {
    console.log("📡 Consultando API Oficial (datos.gob.ar)...");
    // ID 101.1_I2NG_2016_M_22: IPC Nivel General Nacional (Índice Base 2016)
    const res = await axios.get('https://apis.datos.gob.ar/series/api/series/?ids=101.1_I2NG_2016_M_22&limit=2&sort=desc&format=json', { timeout: 15000 });
    
    if (res.data && res.data.data && res.data.data.length >= 2) {
      const actual = res.data.data[0][1];
      const anterior = res.data.data[1][1];
      const fecha = res.data.data[0][0];
      
      // Calcular variación mensual
      ipcMensual = parseFloat(((actual / anterior - 1) * 100).toFixed(2));
      fuente = `Ajuste automático IPC INDEC (Oficial): ${ipcMensual}% (Mes: ${fecha})`;
      
      console.log(`✅ IPC detectado: ${ipcMensual}% (Mes base: ${fecha})`);
    } else {
      throw new Error("Formato de datos insuficiente");
    }
  } catch (e) {
    console.error("❌ Error consultando la API oficial:", e.message);
    return;
  }

  if (!ipcMensual) {
    console.error("❌ No se pudo obtener el IPC de ninguna fuente. Proceso abortado.");
    return;
  }

  try {
    // 2. Obtener todas las provincias de la base de datos
    const { data: provincias, error: errFetch } = await supabase
      .from('maestro_paritarias')
      .select('*');

    if (errFetch) throw errFetch;

    console.log(`📊 Actualizando ${provincias.length} jurisdicciones...`);

    // 3. Aplicar actualización
    for (const p of provincias) {
      let nuevoValor = p.valor_indice;
      let fuenteFinal = p.fuente_legal;

      if (p.metadata?.tipo_ajuste === 'ipc') {
        nuevoValor = p.valor_indice * (1 + (ipcMensual / 100));
        fuenteFinal = fuente;
      }

      await supabase
        .from('maestro_paritarias')
        .update({
          valor_indice: nuevoValor,
          updated_at: new Date().toISOString(),
          fuente_legal: fuenteFinal
        })
        .eq('jurisdiccion', p.jurisdiccion);
    }

    console.log("🚀 ¡Sincronización Federal Completada con éxito!");

  } catch (error) {
    console.error("❌ Error en Supabase:", error.message);
  }
}

runRobot();
