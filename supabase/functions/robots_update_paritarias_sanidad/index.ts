import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dataUrl = Deno.env.get("PARITARIAS_SANIDAD_URL") || "";

const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

async function hasRunning(job: string) {
  const { data, error } = await supabase
    .from("robot_runs")
    .select("id")
    .eq("job_name", job)
    .eq("status", "running")
    .gte("started_at", new Date(Date.now() - 60 * 60 * 1000).toISOString())
    .limit(1);
  if (error) return false;
  return (data?.length || 0) > 0;
}

async function startRun(job: string) {
  const { data, error } = await supabase
    .from("robot_runs")
    .insert({ job_name: job, status: "running" })
    .select("id")
    .single();
  if (error) throw error;
  return data.id as string;
}

async function finishRun(id: string, status: "success" | "failed", log: string, rows: number) {
  await supabase
    .from("robot_runs")
    .update({ status, finished_at: new Date().toISOString(), log, rows_affected: rows })
    .eq("id", id);
}

async function fetchData(): Promise<any[]> {
  if (!dataUrl) return [];
  const res = await fetch(dataUrl, { headers: { "accept": "application/json" } });
  if (!res.ok) throw new Error(`fetch ${res.status}`);
  const json = await res.json();
  if (Array.isArray(json)) return json;
  if (Array.isArray(json?.items)) return json.items;
  return [];
}

async function upsertParitarias(items: any[]): Promise<number> {
  if (items.length === 0) return 0;
  const mapped = items.map((x) => ({
    jurisdiccion: String(x.jurisdiccion || x.provincia || "").trim(),
    periodo: String(x.periodo || x.mes || "").replaceAll("/", "").trim(),
    basico_profesional: Number(x.basicoProfesional ?? x.basico_profesional ?? 0),
    basico_tecnico: Number(x.basicoTecnico ?? x.basico_tecnico ?? 0),
    basico_servicios: Number(x.basicoServicios ?? x.basico_servicios ?? 0),
    basico_administrativo: Number(x.basicoAdministrativo ?? x.basico_administrativo ?? 0),
    basico_maestranza: Number(x.basicoMaestranza ?? x.basico_maestranza ?? 0),
    titulo_auxiliar_pct: Number(x.tituloAuxiliarPct ?? x.titulo_auxiliar_pct ?? 5),
    titulo_tecnico_pct: Number(x.tituloTecnicoPct ?? x.titulo_tecnico_pct ?? 7),
    titulo_universitario_pct: Number(x.tituloUniversitarioPct ?? x.titulo_universitario_pct ?? 10),
    plus_patagonia_pct: Number(x.plusPatagoniaPct ?? x.plus_patagonia_pct ?? 20),
    fuente: String(x.fuente || dataUrl || "").trim(),
    hash: crypto.subtle ? "" : "",
  }));
  const { data, error } = await supabase
    .from("paritarias_sanidad")
    .upsert(mapped, { onConflict: "jurisdiccion,periodo" })
    .select("jurisdiccion");
  if (error) throw error;
  return data?.length || 0;
}

serve(async (req) => {
  try {
    const job = "paritarias_sanidad";
    if (await hasRunning(job)) {
      return new Response(JSON.stringify({ ok: true, message: "locked" }), { headers: { "content-type": "application/json" } });
    }
    const runId = await startRun(job);
    try {
      const items = await fetchData();
      const rows = await upsertParitarias(items);
      await finishRun(runId, "success", `rows:${rows}`, rows);
      return new Response(JSON.stringify({ ok: true, rows }), { headers: { "content-type": "application/json" } });
    } catch (e) {
      await finishRun(runId, "failed", String(e?.message || e), 0);
      return new Response(JSON.stringify({ ok: false, error: String(e?.message || e) }), { status: 500, headers: { "content-type": "application/json" } });
    }
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e?.message || e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
