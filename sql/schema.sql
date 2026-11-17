-- Invitación Ethan y Zaid: RSVP + conteo. Acceso solo vía funciones.
create table if not exists public.cumple_cfg (id int primary key default 1 check (id=1), key_hash text not null);
create table if not exists public.cumple_rsvp (
  id bigserial primary key,
  nombre text not null,
  nombre_norm text not null unique,
  asiste boolean not null,
  adultos int not null default 0 check (adultos between 0 and 20),
  ninos int not null default 0 check (ninos between 0 and 20),
  mensaje text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.cumple_cfg enable row level security;
alter table public.cumple_rsvp enable row level security;
revoke all on public.cumple_cfg, public.cumple_rsvp from anon, authenticated;
revoke all on sequence public.cumple_rsvp_id_seq from anon, authenticated;
insert into public.cumple_cfg(id,key_hash) values (1, encode(sha256(convert_to('__ADMIN_KEY__','utf8')),'hex'))
  on conflict (id) do update set key_hash=excluded.key_hash;

create or replace function public.cumple_enviar(p_nombre text, p_asiste boolean, p_adultos int, p_ninos int, p_mensaje text)
returns json language plpgsql security definer set search_path = public as $$
declare n text := btrim(coalesce(p_nombre,'')); a int; k int;
begin
  if length(n) < 2 or length(n) > 80 then raise exception 'nombre invalido'; end if;
  if p_asiste is null then raise exception 'asistencia invalida'; end if;
  a := case when p_asiste then greatest(0,least(coalesce(p_adultos,0),20)) else 0 end;
  k := case when p_asiste then greatest(0,least(coalesce(p_ninos,0),20)) else 0 end;
  if p_asiste and a + k < 1 then raise exception 'indica cuantas personas'; end if;
  if (select count(*) from cumple_rsvp) >= 400 then raise exception 'limite'; end if;
  insert into cumple_rsvp(nombre,nombre_norm,asiste,adultos,ninos,mensaje)
  values (n, lower(regexp_replace(n,'\s+',' ','g')), p_asiste, a, k, nullif(left(btrim(coalesce(p_mensaje,'')),300),''))
  on conflict (nombre_norm) do update set asiste=excluded.asiste, adultos=excluded.adultos, ninos=excluded.ninos,
    mensaje=excluded.mensaje, updated_at=now();
  return json_build_object('ok',true);
end $$;

create or replace function public.cumple_lista(p_key text)
returns json language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from cumple_cfg where key_hash = encode(sha256(convert_to(coalesce(p_key,''),'utf8')),'hex')) then
    raise exception 'no autorizado'; end if;
  return json_build_object(
    'resumen', (select json_build_object(
        'familias_confirman', count(*) filter (where asiste),
        'adultos', coalesce(sum(adultos) filter (where asiste),0),
        'ninos', coalesce(sum(ninos) filter (where asiste),0),
        'total_asistentes', coalesce(sum(adultos+ninos) filter (where asiste),0),
        'no_asisten', count(*) filter (where not asiste)) from cumple_rsvp),
    'filas', coalesce((select json_agg(r order by r.updated_at desc) from (select id,nombre,asiste,adultos,ninos,mensaje,updated_at from cumple_rsvp) r),'[]'::json));
end $$;

create or replace function public.cumple_borrar(p_key text, p_id bigint)
returns json language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from cumple_cfg where key_hash = encode(sha256(convert_to(coalesce(p_key,''),'utf8')),'hex')) then
    raise exception 'no autorizado'; end if;
  delete from cumple_rsvp where id = p_id;
  return json_build_object('ok',true);
end $$;

revoke all on function public.cumple_enviar(text,boolean,int,int,text), public.cumple_lista(text), public.cumple_borrar(text,bigint) from public;
grant execute on function public.cumple_enviar(text,boolean,int,int,text), public.cumple_lista(text), public.cumple_borrar(text,bigint) to anon, authenticated;
