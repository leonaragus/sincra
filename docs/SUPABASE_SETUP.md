# Configuración de Supabase – Elevar Liquidación

## Setup en un solo paso

1. Abrí **Supabase Dashboard** → tu proyecto → **SQL Editor**.
2. Abrí el archivo **`docs/SETUP_SUPABASE_COMPLETO.sql`** del repo (o copiá su contenido).
3. Pegalo en el editor y hacé **Run**.
4. Listo: quedan creadas **todas** las tablas que usa la app (`empresas`, `empleados`, `liquidaciones`, `syncra_entities`) con el esquema correcto y RLS para `anon`.

Ese script **borra** las tablas existentes y las recrea. Si tenés datos que quieras conservar, hacé backup antes.

---

## .env.local

Creá `.env.local` en la raíz (o copiá desde `.env.local.example`) con:

- `NEXT_PUBLIC_SUPABASE_URL` = URL del proyecto (ej. `https://xxx.supabase.co`)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` = anon o publishable key

Sin comillas, sin espacios. Reiniciá el servidor después de cambiar.

## Probar conexión

Con el servidor corriendo, abrí `http://localhost:3000/api/supabase-diagnostic`.

## Anon key

Podés usar la clave **anon** (empieza con `eyJ`) o la **publishable** (`sb_publishable_...`). Ambas funcionan. No uses `service_role`.

---

## Opcional: Migraciones puntuales

Si en vez del setup completo solo querés agregar columnas faltantes (por ejemplo `domicilio` en `empresas`), usá:

```sql
-- docs/migrations/001_add_domicilio_empresas.sql
ALTER TABLE empresas ADD COLUMN IF NOT EXISTS domicilio TEXT;
```

Para un esquema limpio y alineado con la app, conviene usar **`SETUP_SUPABASE_COMPLETO.sql`** una sola vez.
