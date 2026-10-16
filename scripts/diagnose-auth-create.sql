-- Supabase SQL Editor, as project administrator. Run the whole file.
-- Simulates the employee Auth write as supabase_auth_admin, captures the real SQL error,
-- then rolls the entire probe back. Never disables triggers or retains a test account.
create temporary table if not exists themelio_probe_scope(marker integer) on commit drop;
create or replace function pg_temp.themelio_diagnose_auth_create()
returns table(error_code text,error_message text,error_function text,auth_trigger_functions text)
language plpgsql security invoker set search_path='' as $$
declare
 v_id uuid:=gen_random_uuid();
 v_login text:='tm-probe-'||replace(gen_random_uuid()::text,'-','');
 v_hash text;
 v_code text;
 v_message text;
 v_context text;
 v_triggers text;
begin
 select string_agg(n.nspname||'.'||p.proname,', ' order by t.tgname) into v_triggers
 from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace n on n.oid=p.pronamespace
 where t.tgrelid='auth.users'::regclass and not t.tgisinternal and t.tgenabled<>'D';
 -- Auth normally hashes in its server process, so prepare this before assuming its DB role.
 v_hash:=extensions.crypt(encode(extensions.gen_random_bytes(24),'hex'),extensions.gen_salt('bf'));
 begin
  execute 'set local role supabase_auth_admin';
  insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
                        raw_app_meta_data,raw_user_meta_data,created_at,updated_at,
                        confirmation_token,recovery_token,email_change_token_new,email_change,
                        email_change_token_current,reauthentication_token)
  values('00000000-0000-0000-0000-000000000000',v_id,'authenticated','authenticated',
   v_login||'@accounts.themelio.invalid',v_hash,now(),
   jsonb_build_object('provider','email','providers',jsonb_build_array('email'),
                     'themelio_role','employee','login',v_login,'position','Prorab'),
   '{}'::jsonb,now(),now(),'','','','','','');
  insert into auth.identities(id,provider_id,user_id,identity_data,provider,created_at,updated_at)
  values(gen_random_uuid(),v_id::text,v_id,jsonb_build_object('sub',v_id::text,'email',v_login||'@accounts.themelio.invalid','email_verified',true),'email',now(),now());
  -- The exception block is a subtransaction: this also undoes the role change and triggers.
  raise exception using errcode='PZ001',message='THEMELIO_PROBE_ROLLBACK';
 exception when others then
  get stacked diagnostics v_code=returned_sqlstate,v_message=message_text,v_context=pg_exception_context;
 end;
 if v_code='PZ001' and v_message='THEMELIO_PROBE_ROLLBACK' then
  return query select 'OK'::text,
   'Sinov yozuvi va triggerlar ishladi. Sinov hisobi saqlanmadi; Auth server logidagi boshqa bosqichni tekshirish kerak.'::text,
   null::text,v_triggers;
 else
  -- Do not return SQL details, row data, hashes or complete function definitions.
  return query select v_code,v_message,substring(v_context from 'function ([^\n]+)'),v_triggers;
 end if;
end;
$$;
select * from pg_temp.themelio_diagnose_auth_create();
