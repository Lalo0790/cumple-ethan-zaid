-- Panel con PIN + bloqueo contra fuerza bruta. El hash del PIN se carga aparte (no vive en el repo).
drop function if exists public.cumple_lista(text);
drop function if exists public.cumple_borrar(text,bigint);
alter table public.cumple_cfg add column if not exists salt text;
alter table public.cumple_cfg add column if not exists pin_hash text;
alter table public.cumple_cfg alter column key_hash drop not null;
update public.cumple_cfg set key_hash = null where id = 1;

create table if not exists public.cumple_intentos (
  id bigserial primary key, ip text not null, at timestamptz not null default now());
create index if not exists cumple_intentos_at on public.cumple_intentos(at);
alter table public.cumple_intentos enable row level security;
revoke all on public.cumple_intentos from anon, authenticated;
revoke all on sequence public.cumple_intentos_id_seq from anon, authenticated;

-- Devuelve null si el PIN es correcto; si no, un json de error. Cuenta fallos (por IP y global).
create or replace function public.cumple_verificar(p_pin text) returns json
language plpgsql security definer set search_path = public as $$
declare v_ip text; fi int; fg int; c cumple_cfg%rowtype;
begin
  begin v_ip := coalesce(nullif(btrim(split_part((current_setting('request.headers',true)::json)->>'x-forwarded-for',',',1)),''),'?');
  exception when others then v_ip := '?'; end;
  delete from cumple_intentos where at < now() - interval '1 day';
  select count(*) into fi from cumple_intentos where ip = v_ip and at > now() - interval '15 minutes';
  select count(*) into fg from cumple_intentos where at > now() - interval '1 hour';
  if fi >= 5 or fg >= 30 then
    return json_build_object('ok',false,'error','bloqueado');
  end if;
  select * into c from cumple_cfg where id = 1;
  if c.pin_hash is not null and encode(sha256(convert_to(c.salt || coalesce(p_pin,''),'utf8')),'hex') = c.pin_hash then
    return null;
  end if;
  insert into cumple_intentos(ip) values (v_ip);
  return json_build_object('ok',false,'error','pin','restantes', greatest(0, 5 - fi - 1));
end $$;

create or replace function public.cumple_lista(p_pin text)
returns json language plpgsql security definer set search_path = public as $$
declare v json;
begin
  v := cumple_verificar(p_pin); if v is not null then return v; end if;
  return json_build_object('ok',true,
    'resumen', (select json_build_object(
        'familias_confirman', count(*) filter (where asiste),
        'adultos', coalesce(sum(adultos) filter (where asiste),0),
        'ninos', coalesce(sum(ninos) filter (where asiste),0),
        'total_asistentes', coalesce(sum(adultos+ninos) filter (where asiste),0),
        'no_asisten', count(*) filter (where not asiste)) from cumple_rsvp),
    'filas', coalesce((select json_agg(r order by r.updated_at desc) from (select id,nombre,asiste,adultos,ninos,mensaje,updated_at from cumple_rsvp) r),'[]'::json));
end $$;

create or replace function public.cumple_borrar(p_pin text, p_id bigint)
returns json language plpgsql security definer set search_path = public as $$
declare v json;
begin
  v := cumple_verificar(p_pin); if v is not null then return v; end if;
  delete from cumple_rsvp where id = p_id;
  return json_build_object('ok',true);
end $$;

revoke all on function public.cumple_verificar(text) from public, anon, authenticated;
revoke all on function public.cumple_lista(text), public.cumple_borrar(text,bigint) from public;
grant execute on function public.cumple_lista(text), public.cumple_borrar(text,bigint) to anon, authenticated;
