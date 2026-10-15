-- Themelio schema repair for a partially completed installation.
-- Run the ENTIRE file in Supabase SQL Editor. Existing user/report rows are retained.
-- Replaces only this app's named functions, trigger and policies; no DROP TABLE or CASCADE.
-- Includes both the core schema and camera-photo Storage setup. Safe to rerun on this schema.
begin;
-- Themelio: one company, up to 10 accounts (one director and nine employees).
create table if not exists public.members (
 id uuid primary key references auth.users(id) on delete cascade,
 login text not null unique check (login ~ '^[a-z0-9][a-z0-9._-]{2,49}$'),
 app_role text not null check (app_role in ('director','employee')),
 position text not null check (length(trim(position)) between 1 and 80),
 name text not null default '', phone text not null default '',
 contact_email text not null default '', address text not null default '', birth_date date,
 status text not null default 'pending' check (status in ('pending','active')),
 created_at timestamptz not null default now()
);
create unique index if not exists one_director on public.members(app_role) where app_role='director';
create table if not exists public.reports (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references public.members(id),
 title text not null check (length(trim(title)) between 1 and 160),
 body text not null check (length(trim(body)) between 1 and 10000),
 report_type text not null check (report_type in ('morning','evening')),
 report_date date not null default (now() at time zone 'Asia/Tashkent')::date,
 status text not null default 'review' check (status in ('review','accepted')),
 reviewed_by uuid references public.members(id), reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists reports_author_date on public.reports(author_id,report_date);
create table if not exists public.tasks (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) between 1 and 160),
 description text not null default '' check(length(description)<=5000),
 assignee_id uuid not null references public.members(id),
 created_by uuid not null references public.members(id),
 due_date date not null, priority text not null default 'O‘rtacha' check(priority in ('Yuqori','O‘rtacha','Past')),
 progress integer not null default 0 check(progress between 0 and 100),
 status text not null default 'progress' check(status in ('progress','done','late')),
 created_at timestamptz not null default now()
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.members(id),
 recipient_id uuid not null references public.members(id),
 body text not null check(length(trim(body)) between 1 and 5000),
 created_at timestamptz not null default now(),
 check(sender_id<>recipient_id)
);
create index if not exists messages_participants on public.messages(sender_id,recipient_id,created_at);
-- Private helper functions avoid RLS recursion and cannot be replaced by clients.
create schema if not exists themelio_private;
revoke all on schema themelio_private from public;
create or replace function themelio_private.is_director() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where id=auth.uid() and app_role='director');
$$;
create or replace function themelio_private.is_active() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where id=auth.uid() and status='active');
$$;
revoke all on all functions in schema themelio_private from public;
grant usage on schema themelio_private to authenticated;
grant execute on function themelio_private.is_director(),themelio_private.is_active() to authenticated;

create or replace function themelio_private.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Metadata is set only by the Auth Admin API, never by public sign-up metadata.
 if coalesce(new.raw_app_meta_data->>'themelio_role','') not in ('director','employee') then
  raise exception 'Themelio accounts must be created by an administrator';
 end if;
 -- Serialize provisioning so simultaneous requests cannot exceed the seat limit.
 perform pg_advisory_xact_lock(81810210);
 if (select count(*) from public.members)>=10 then raise exception 'Themelio supports at most 10 accounts'; end if;
 insert into public.members(id,login,app_role,position)
 values(new.id,new.raw_app_meta_data->>'login',new.raw_app_meta_data->>'themelio_role',new.raw_app_meta_data->>'position');
 return new;
end;
$$;
revoke all on function themelio_private.handle_new_user() from public;
drop trigger if exists themelio_create_member on auth.users;
create trigger themelio_create_member after insert on auth.users for each row execute function themelio_private.handle_new_user();

alter table public.members enable row level security;
alter table public.reports enable row level security;
alter table public.tasks enable row level security;
alter table public.messages enable row level security;
revoke all on public.members,public.reports,public.tasks,public.messages from anon,authenticated;
grant select on public.members,public.reports,public.tasks,public.messages to authenticated;
grant all on public.members,public.reports,public.tasks,public.messages to service_role;
drop policy if exists member_read on public.members;
create policy member_read on public.members for select to authenticated using(id=auth.uid() or app_role='director' or themelio_private.is_director());
drop policy if exists report_read on public.reports;
create policy report_read on public.reports for select to authenticated using(author_id=auth.uid() or themelio_private.is_director());
drop policy if exists task_read on public.tasks;
create policy task_read on public.tasks for select to authenticated using(assignee_id=auth.uid() or themelio_private.is_director());
drop policy if exists message_read on public.messages;
create policy message_read on public.messages for select to authenticated using(sender_id=auth.uid() or recipient_id=auth.uid());

create or replace function public.complete_profile(p_name text,p_phone text,p_email text,p_address text,p_birth_date date default null) returns void language plpgsql security definer set search_path='' as $$
declare current_member public.members;
begin
 select * into current_member from public.members where id=auth.uid();
 if not found then raise exception 'Not authorized'; end if;
 if length(trim(coalesce(p_name,''))) not between 1 and 100 or length(coalesce(p_email,''))>254 or coalesce(p_email,'') !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'Valid name and email are required'; end if;
 if length(coalesce(p_phone,''))>25 or length(coalesce(p_address,''))>250 then raise exception 'Profile fields too long'; end if;
 if current_member.app_role='employee' and (length(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'))<9 or length(trim(coalesce(p_address,'')))=0) then raise exception 'Phone and address are required'; end if;
 if p_birth_date>(now() at time zone 'Asia/Tashkent')::date then raise exception 'Birth date cannot be in the future'; end if;
 update public.members set name=trim(p_name),phone=trim(coalesce(p_phone,'')),contact_email=trim(p_email),address=trim(coalesce(p_address,'')),birth_date=p_birth_date,status='active' where id=auth.uid();
end;
$$;
create or replace function public.submit_report(p_title text,p_body text,p_type text,p_date date) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_active() then raise exception 'Complete your profile first'; end if;
 insert into public.reports(author_id,title,body,report_type,report_date) values(auth.uid(),trim(p_title),trim(p_body),p_type,p_date) returning id into result;
 return result;
end;
$$;
create or replace function public.review_report(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not themelio_private.is_director() then raise exception 'Director access required'; end if;
 update public.reports set status='accepted',reviewed_by=auth.uid(),reviewed_at=now() where id=p_id;
 if not found then raise exception 'Report not found'; end if;
end;
$$;
create or replace function public.create_task(p_title text,p_description text,p_assignee uuid,p_due date,p_priority text) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_director() then raise exception 'Director access required'; end if;
 if not exists(select 1 from public.members where id=p_assignee and status='active' and app_role='employee') then raise exception 'An active employee is required'; end if;
 insert into public.tasks(title,description,assignee_id,created_by,due_date,priority) values(trim(p_title),p_description,p_assignee,auth.uid(),p_due,p_priority) returning id into result;
 return result;
end;
$$;
create or replace function public.update_task_progress(p_id uuid,p_progress integer) returns void language plpgsql security definer set search_path='' as $$
begin
 update public.tasks set progress=p_progress,status=case when p_progress=100 then 'done' else 'progress' end
 where id=p_id and (themelio_private.is_director() or (assignee_id=auth.uid() and themelio_private.is_active()));
 if not found then raise exception 'Task not found or access denied'; end if;
end;
$$;
create or replace function public.send_message(p_recipient uuid,p_body text) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_active() then raise exception 'Complete your profile first'; end if;
 if not exists(select 1 from public.members where id=p_recipient and status='active' and (app_role='director' or themelio_private.is_director())) then raise exception 'Recipient unavailable'; end if;
 insert into public.messages(sender_id,recipient_id,body) values(auth.uid(),p_recipient,trim(p_body)) returning id into result;
 return result;
end;
$$;
revoke all on function public.complete_profile(text,text,text,text,date),public.submit_report(text,text,text,date),public.review_report(uuid),public.create_task(text,text,uuid,date,text),public.update_task_progress(uuid,integer),public.send_message(uuid,text) from public,anon;
grant execute on function public.complete_profile(text,text,text,text,date),public.submit_report(text,text,text,date),public.review_report(uuid),public.create_task(text,text,uuid,date,text),public.update_task_progress(uuid,integer),public.send_message(uuid,text) to authenticated;
-- Realtime is optional for correctness: the app also refreshes on focus and every 30s.
do $$
declare tab text;
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  foreach tab in array array['members','reports','tasks','messages'] loop
   if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=tab) then execute format('alter publication supabase_realtime add table public.%I',tab); end if;
  end loop;
 end if;
end $$;

alter table public.reports add column if not exists photo_paths text[] not null default '{}' check(cardinality(photo_paths)<=5);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('report-photos','report-photos',false,5242880,array['image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=array['image/jpeg'];

-- Authenticated employees upload only to their own namespace. No public bucket URLs.
drop policy if exists report_photo_upload on storage.objects;
create policy report_photo_upload on storage.objects for insert to authenticated with check(
 bucket_id='report-photos' and (storage.foldername(name))[1]=auth.uid()::text and themelio_private.is_active()
);
drop policy if exists report_photo_read on storage.objects;
create policy report_photo_read on storage.objects for select to authenticated using(
 bucket_id='report-photos' and (
  (storage.foldername(name))[1]=auth.uid()::text or
  (themelio_private.is_director() and exists(select 1 from public.reports where name=any(photo_paths)))
 )
);
-- Uploaded drafts may be cleaned up. Submitted photos are immutable through the client.
drop policy if exists report_photo_cleanup on storage.objects;
create policy report_photo_cleanup on storage.objects for delete to authenticated using(
 bucket_id='report-photos' and (storage.foldername(name))[1]=auth.uid()::text
 and not exists(select 1 from public.reports where name=any(photo_paths))
);

-- Restrictive guards keep this bucket private even when unrelated broad policies exist.
drop policy if exists report_photo_read_guard on storage.objects;
create policy report_photo_read_guard on storage.objects as restrictive for select to authenticated using(
 bucket_id<>'report-photos' or (storage.foldername(name))[1]=auth.uid()::text or
 (themelio_private.is_director() and exists(select 1 from public.reports where name=any(photo_paths)))
);
drop policy if exists report_photo_insert_guard on storage.objects;
create policy report_photo_insert_guard on storage.objects as restrictive for insert to authenticated with check(
 bucket_id<>'report-photos' or ((storage.foldername(name))[1]=auth.uid()::text and themelio_private.is_active())
);
drop policy if exists report_photo_delete_guard on storage.objects;
create policy report_photo_delete_guard on storage.objects as restrictive for delete to authenticated using(
 bucket_id<>'report-photos' or ((storage.foldername(name))[1]=auth.uid()::text and not exists(select 1 from public.reports where name=any(photo_paths)))
);
drop policy if exists report_photo_no_update on storage.objects;
create policy report_photo_no_update on storage.objects as restrictive for update to authenticated using(bucket_id<>'report-photos') with check(bucket_id<>'report-photos');
drop policy if exists report_photo_no_anon on storage.objects;
create policy report_photo_no_anon on storage.objects as restrictive for all to anon using(bucket_id<>'report-photos') with check(bucket_id<>'report-photos');

create or replace function public.submit_report_with_photos(p_id uuid,p_title text,p_body text,p_type text,p_date date,p_paths text[]) returns uuid language plpgsql security definer set search_path='' as $$
declare path text;existing_author uuid;
begin
 if not themelio_private.is_active() then raise exception 'Complete your profile first'; end if;
 select author_id into existing_author from public.reports where id=p_id;
 if found then
  if existing_author<>auth.uid() then raise exception 'Access denied'; end if;
  return p_id;
 end if;
 if p_paths is null or cardinality(p_paths)>5 then raise exception 'At most 5 photos are allowed'; end if;
 if cardinality(p_paths)<>(select count(distinct item) from unnest(p_paths) item) then raise exception 'Duplicate photo path'; end if;
 foreach path in array p_paths loop
  if split_part(path,'/',1)<>auth.uid()::text or split_part(path,'/',2)<>p_id::text then raise exception 'Photo does not belong to this report'; end if;
  if not exists(select 1 from storage.objects where bucket_id='report-photos' and name=path and metadata->>'mimetype'='image/jpeg' and (metadata->>'size')::bigint between 1 and 5242880) then raise exception 'Photo is missing or invalid'; end if;
 end loop;
 insert into public.reports(id,author_id,title,body,report_type,report_date,photo_paths)
 values(p_id,auth.uid(),trim(p_title),trim(p_body),p_type,p_date,p_paths) on conflict(id) do nothing;
 select author_id into existing_author from public.reports where id=p_id;
 if existing_author<>auth.uid() then raise exception 'Access denied'; end if;
 return p_id;
end;
$$;
revoke all on function public.submit_report_with_photos(uuid,text,text,text,date,text[]) from public,anon;
grant execute on function public.submit_report_with_photos(uuid,text,text,text,date,text[]) to authenticated;

commit;
select 'Baza tayyor' as status,
       (select count(*) from public.members) as accounts,
       (select count(*) from public.members where app_role='director') as director_accounts;
