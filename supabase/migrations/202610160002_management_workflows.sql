-- Management workflows. Run after all previous migrations. Retains existing data.
begin;
alter table public.members add column employment_status text not null default 'employed' check(employment_status in ('employed','dismissed','deleted'));
alter table public.members add column access_area text not null default 'operations' check(access_area in ('operations','sales'));
update public.members set access_area='sales' where app_role='employee' and lower(trim(position))='sotuvchi';
create table public.projects(
 id uuid primary key default gen_random_uuid(),name text not null check(length(trim(name)) between 1 and 120),
 city text not null check(length(trim(city)) between 1 and 120),address text not null default '' check(length(address)<=300),
 progress integer not null default 0 check(progress between 0 and 100),planned_finish date,
 created_by uuid not null references public.members(id),created_at timestamptz not null default now()
);
alter table public.members add column project_id uuid references public.projects(id);
alter table public.tasks add column project_id uuid references public.projects(id);
alter table public.reports add column project_id uuid references public.projects(id);
alter table public.reports add column rejection_reason text;
alter table public.reports drop constraint reports_status_check;
alter table public.reports add constraint reports_status_check check(status in ('review','accepted','rejected'));
alter table public.reports add constraint report_rejection_reason check(status<>'rejected' or (rejection_reason is not null and length(trim(rejection_reason)) between 1 and 2000));
create table public.sales(
 id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id),
 unit_label text not null check(length(trim(unit_label)) between 1 and 120),buyer_name text not null check(length(trim(buyer_name)) between 1 and 120),
 buyer_phone text not null check(length(regexp_replace(buyer_phone,'[^0-9]','','g')) between 9 and 15),
 price numeric(18,2) not null check(price>0),paid numeric(18,2) not null check(paid>=0 and paid<=price),
 seller_id uuid not null references public.members(id),sold_on date not null default (now() at time zone 'Asia/Tashkent')::date,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create unique index sales_project_unit on public.sales(project_id,lower(trim(unit_label)));
alter table public.projects enable row level security;
alter table public.sales enable row level security;
revoke all on public.projects,public.sales from anon,authenticated;
grant select on public.projects,public.sales to authenticated;
grant all on public.projects,public.sales to service_role;

create or replace function themelio_private.is_director() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where id=auth.uid() and app_role='director' and employment_status='employed');
$$;
create or replace function themelio_private.is_active() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where id=auth.uid() and status='active' and employment_status='employed');
$$;
create function themelio_private.can_sales() returns boolean language sql stable security definer set search_path='' as $$
 select themelio_private.is_director() or exists(select 1 from public.members where id=auth.uid() and status='active' and employment_status='employed' and access_area='sales');
$$;
revoke all on function themelio_private.can_sales() from public;
grant execute on function themelio_private.can_sales() to authenticated;
create policy project_read on public.projects for select to authenticated using(
 themelio_private.is_director() or (themelio_private.is_active() and (
  themelio_private.can_sales() or id=(select project_id from public.members where id=auth.uid()) or
  exists(select 1 from public.tasks t where t.project_id=projects.id and t.assignee_id=auth.uid()) or
  exists(select 1 from public.reports r where r.project_id=projects.id and r.author_id=auth.uid())
 ))
);
create policy sales_read on public.sales for select to authenticated using(themelio_private.can_sales());
drop policy report_read on public.reports;
create policy report_read on public.reports for select to authenticated using(themelio_private.is_director() or (themelio_private.is_active() and author_id=auth.uid()));
drop policy task_read on public.tasks;
create policy task_read on public.tasks for select to authenticated using(themelio_private.is_director() or (themelio_private.is_active() and assignee_id=auth.uid()));
drop policy message_read on public.messages;
create policy message_read on public.messages for select to authenticated using(themelio_private.is_director() and (sender_id=auth.uid() or recipient_id=auth.uid()) or (themelio_private.is_active() and (sender_id=auth.uid() or recipient_id=auth.uid())));

create or replace function themelio_private.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if coalesce(new.raw_app_meta_data->>'themelio_role','') not in ('director','employee') then return new;end if;
 if exists(select 1 from public.members where id=new.id) then return new;end if;
 perform pg_advisory_xact_lock(81810210);
 if exists(select 1 from public.members where id=new.id) then return new;end if;
 if (select count(*) from public.members where employment_status<>'deleted')>=10 then raise exception 'Themelio supports at most 10 accounts';end if;
 insert into public.members(id,login,app_role,position,access_area) values(new.id,new.raw_app_meta_data->>'login',new.raw_app_meta_data->>'themelio_role',new.raw_app_meta_data->>'position',
 case when new.raw_app_meta_data->>'themelio_role'='employee' and (new.raw_app_meta_data->>'access_area'='sales' or lower(trim(new.raw_app_meta_data->>'position'))='sotuvchi') then 'sales' else 'operations' end);
 return new;
end;
$$;
create function themelio_private.guard_profile_edit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid()=old.id and old.employment_status<>'employed' and not themelio_private.is_director() then raise exception 'Hisob faol emas';end if;
 return new;
end;
$$;
revoke all on function themelio_private.guard_profile_edit() from public;
create trigger themelio_profile_guard before update on public.members for each row execute function themelio_private.guard_profile_edit();
create function public.set_employee_state(p_id uuid,p_state text) returns void language plpgsql security definer set search_path='' as $$
declare target public.members;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if p_state is null or p_state not in ('employed','dismissed','deleted') then raise exception 'Invalid employee state';end if;
 select * into target from public.members where id=p_id and app_role='employee' for update;
 if not found then raise exception 'Employee not found';end if;
 if target.employment_status='deleted' then raise exception 'Deleted profiles cannot be restored';end if;
 update public.members set employment_status=p_state,
 name=case when p_state='deleted' then 'O‘chirilgan xodim' else name end,
 phone=case when p_state='deleted' then '' else phone end,contact_email=case when p_state='deleted' then '' else contact_email end,
 address=case when p_state='deleted' then '' else address end,birth_date=case when p_state='deleted' then null else birth_date end,
 project_id=case when p_state='deleted' then null else project_id end where id=p_id;
end;
$$;
create function public.save_project(p_id uuid,p_name text,p_city text,p_address text,p_progress integer,p_finish date) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if p_id is null then
  insert into public.projects(name,city,address,progress,planned_finish,created_by) values(trim(p_name),trim(p_city),trim(coalesce(p_address,'')),p_progress,p_finish,auth.uid()) returning id into result;
 else
  update public.projects set name=trim(p_name),city=trim(p_city),address=trim(coalesce(p_address,'')),progress=p_progress,planned_finish=p_finish where id=p_id returning id into result;
  if not found then raise exception 'Project not found';end if;
 end if;
 return result;
end;
$$;
create function public.assign_employee_project(p_id uuid,p_project uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 update public.members set project_id=p_project where id=p_id and app_role='employee' and employment_status<>'deleted';
 if not found then raise exception 'Employee not found';end if;
end;
$$;
create function themelio_private.report_project() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.project_id is null then select project_id into new.project_id from public.members where id=new.author_id;end if;
 return new;
end;
$$;
revoke all on function themelio_private.report_project() from public;
create trigger themelio_report_project before insert on public.reports for each row execute function themelio_private.report_project();
create function public.decide_report(p_id uuid,p_decision text,p_reason text default null) returns void language plpgsql security definer set search_path='' as $$
declare target public.reports;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if p_decision is null or p_decision not in ('accepted','rejected') then raise exception 'Invalid decision';end if;
 if p_decision='rejected' and (p_reason is null or length(trim(p_reason)) not between 1 and 2000) then raise exception 'Bekor qilish sababini yozing (1–2000 belgi)';end if;
 select * into target from public.reports where id=p_id for update;
 if not found then raise exception 'Report not found';end if;
 if target.status<>'review' then raise exception 'Hisobot allaqachon ko‘rib chiqilgan';end if;
 update public.reports set status=p_decision,rejection_reason=case when p_decision='rejected' then trim(p_reason) else null end,reviewed_by=auth.uid(),reviewed_at=now() where id=p_id;
end;
$$;
create or replace function public.review_report(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform public.decide_report(p_id,'accepted',null);end;
$$;
create function public.save_task(p_id uuid,p_title text,p_description text,p_assignee uuid,p_due date,p_priority text,p_progress integer,p_project uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;assignment public.members;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 select * into assignment from public.members where id=p_assignee and app_role='employee' and status='active' and employment_status='employed';
 if not found then raise exception 'An active employee is required';end if;
 if p_id is null then
  insert into public.tasks(title,description,assignee_id,created_by,due_date,priority,progress,status,project_id)
  values(trim(p_title),p_description,p_assignee,auth.uid(),p_due,p_priority,p_progress,case when p_progress=100 then 'done' else 'progress' end,coalesce(p_project,assignment.project_id)) returning id into result;
 else
  update public.tasks set title=trim(p_title),description=p_description,assignee_id=p_assignee,due_date=p_due,priority=p_priority,progress=p_progress,status=case when p_progress=100 then 'done' else 'progress' end,project_id=coalesce(p_project,assignment.project_id) where id=p_id returning id into result;
  if not found then raise exception 'Task not found';end if;
 end if;
 return result;
end;
$$;
create or replace function public.create_task(p_title text,p_description text,p_assignee uuid,p_due date,p_priority text) returns uuid language plpgsql security definer set search_path='' as $$
begin return public.save_task(null,p_title,p_description,p_assignee,p_due,p_priority,0,null);end;
$$;
create function public.delete_task(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 delete from public.tasks where id=p_id;
 if not found then raise exception 'Task not found';end if;
end;
$$;
create function public.save_sale(p_id uuid,p_project uuid,p_unit text,p_buyer text,p_phone text,p_price numeric,p_paid numeric,p_date date) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.can_sales() then raise exception 'Sotuvchi yoki direktor huquqi talab qilinadi';end if;
 if p_id is null then
  insert into public.sales(project_id,unit_label,buyer_name,buyer_phone,price,paid,seller_id,sold_on) values(p_project,trim(p_unit),trim(p_buyer),trim(p_phone),p_price,p_paid,auth.uid(),p_date) returning id into result;
 else
  update public.sales set project_id=p_project,unit_label=trim(p_unit),buyer_name=trim(p_buyer),buyer_phone=trim(p_phone),price=p_price,paid=p_paid,sold_on=p_date,updated_at=now() where id=p_id and (seller_id=auth.uid() or themelio_private.is_director()) returning id into result;
  if not found then raise exception 'Sotuv topilmadi yoki tahrirlashga ruxsat yo‘q';end if;
 end if;
 return result;
end;
$$;
-- Revoked employees must not keep using previously issued JWTs to read photos.
drop policy report_photo_read on storage.objects;
drop policy report_photo_read_guard on storage.objects;
create policy report_photo_read on storage.objects for select to authenticated using(bucket_id='report-photos' and (
 ((storage.foldername(name))[1]=auth.uid()::text and themelio_private.is_active()) or
 (themelio_private.is_director() and exists(select 1 from public.reports where name=any(photo_paths)))
));
create policy report_photo_read_guard on storage.objects as restrictive for select to authenticated using(bucket_id<>'report-photos' or
 ((storage.foldername(name))[1]=auth.uid()::text and themelio_private.is_active()) or
 (themelio_private.is_director() and exists(select 1 from public.reports where name=any(photo_paths)))
);
drop policy report_photo_cleanup on storage.objects;
drop policy report_photo_delete_guard on storage.objects;
create policy report_photo_cleanup on storage.objects for delete to authenticated using(bucket_id='report-photos' and themelio_private.is_active() and (storage.foldername(name))[1]=auth.uid()::text and not exists(select 1 from public.reports where name=any(photo_paths)));
create policy report_photo_delete_guard on storage.objects as restrictive for delete to authenticated using(bucket_id<>'report-photos' or (themelio_private.is_active() and (storage.foldername(name))[1]=auth.uid()::text and not exists(select 1 from public.reports where name=any(photo_paths))));

revoke all on function public.set_employee_state(uuid,text),public.save_project(uuid,text,text,text,integer,date),public.assign_employee_project(uuid,uuid),public.decide_report(uuid,text,text),public.save_task(uuid,text,text,uuid,date,text,integer,uuid),public.delete_task(uuid),public.save_sale(uuid,uuid,text,text,text,numeric,numeric,date) from public,anon;
grant execute on function public.set_employee_state(uuid,text),public.save_project(uuid,text,text,text,integer,date),public.assign_employee_project(uuid,uuid),public.decide_report(uuid,text,text),public.save_task(uuid,text,text,uuid,date,text,integer,uuid),public.delete_task(uuid),public.save_sale(uuid,uuid,text,text,text,numeric,numeric,date) to authenticated;
do $$begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.projects,public.sales;
 end if;
end $$;
commit;
select 'Boshqaruv imkoniyatlari o‘rnatildi' as status;
