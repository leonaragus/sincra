import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dataUrl = Deno.env.get("NOMENCLADOR_DOCENTE_URL") || "";

const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

async function hasRunning(job: string) {
  const { data } = await supabase.from("robot_runs").select("id").eq("job_name", job).eq("status", "running").limit(1);
  return (data?.length || 0) > 0;
}

async function startRun(job: string) {
  const { data, error } = await supabase.from("robot_runs").insert({ job_name: job, status: "running" }).select("id").single();
  if (error) throw error;
  return data.id as string;
}

async function finishRun(id: string, status: "success" | "failed", log: string, rows: number) {
  await supabase.from("robot_runs").update({ status, finished_at: new Date().toISOString(), log, rows_affected: rows }).eq("id", id);
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

async function upsertNomenclador(items: any[]) {
  if (items.length === 0) return 0;
  const mapped = items.map((x) => ({
    jurisdiccion: String(x.jurisdiccion || x.provincia || "").trim(),
    valor_indice: Number(x.valorIndice ?? x.valor_indice ?? 0),
    piso_salarial: Number(x.pisoSalarial ?? x.piso_salarial ?? 0),
    periodo: String(x.periodo || x.mes || "").replaceAll("/", "").trim(),
    fuente: String(x.fuente || dataUrl || "").trim(),
  }));
  const { data, error } = await supabase
    .from("maestro_paritarias")
    .upsert(mapped, { onConflict: "jurisdiccion,periodo" })
    .select("jurisdiccion");
  if (error) throw error;
  return data?.length || 0;
}

serve(async () => {
  const job = "nomenclador_docente";
  if (await hasRunning(job)) {
    return new Response(JSON.stringify({ ok: true, message: "locked" }), { headers: { "content-type": "application/json" } });
  }
  const runId = await startRun(job);
  try {
    const items = await fetchData();
    const rows = await upsertNomenclador(items);
    await finishRun(runId, "success", `rows:${rows}`, rows);
    return new Response(JSON.stringify({ ok: true, rows }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    await finishRun(runId, "failed", String(e?.message || e), 0);
    return new Response(JSON.stringify({ ok: false, error: String(e?.message || e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
