-- Supabase Auth Admin API INSERTs a user before UPDATEing custom app_metadata.
-- Run this entire file in SQL Editor; no accounts/passwords are deleted or reset.
begin;
create or replace function themelio_private.handle_new_user() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 -- Absence of a trusted role creates NO application membership or privileges.
 -- user_metadata is intentionally never consulted: users can edit it themselves.
 if coalesce(new.raw_app_meta_data->>'themelio_role','') not in ('director','employee') then
  return new;
 end if;
 if exists(select 1 from public.members where id=new.id) then return new; end if;
 perform pg_advisory_xact_lock(81810210);
 if exists(select 1 from public.members where id=new.id) then return new; end if;
 if (select count(*) from public.members)>=10 then
  raise exception 'Themelio supports at most 10 accounts';
 end if;
 insert into public.members(id,login,app_role,position)
 values(new.id,new.raw_app_meta_data->>'login',new.raw_app_meta_data->>'themelio_role',new.raw_app_meta_data->>'position');
 return new;
end;
$$;
revoke all on function themelio_private.handle_new_user() from public;
drop trigger if exists themelio_create_member on auth.users;
create trigger themelio_create_member
 after insert or update of raw_app_meta_data on auth.users
 for each row execute function themelio_private.handle_new_user();
-- An authenticated but unassigned Auth account must not read director profiles.
drop policy if exists member_read on public.members;
create policy member_read on public.members for select to authenticated using(
 id=auth.uid() or themelio_private.is_director() or
 (app_role='director' and themelio_private.is_active())
);
commit;
select 'Auth triggeri tuzatildi. Saytda lavozim yaratishni qayta sinang.' as status;
