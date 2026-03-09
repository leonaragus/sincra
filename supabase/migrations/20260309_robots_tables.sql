create table if not exists robot_jobs (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  schedule text,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists robot_runs (
  id uuid primary key default gen_random_uuid(),
  job_name text not null references robot_jobs(name) on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running',
  log text,
  rows_affected integer default 0
);

create index if not exists idx_robot_runs_job_time on robot_runs(job_name, started_at desc);

create or replace function robot_touch_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_robot_jobs_updated_at on robot_jobs;
create trigger trg_robot_jobs_updated_at before update on robot_jobs
for each row execute function robot_touch_updated_at();
