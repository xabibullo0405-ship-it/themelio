begin;
alter table public.reports add column photo_paths text[] not null default '{}' check(cardinality(photo_paths)<=5);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('report-photos','report-photos',false,5242880,array['image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=array['image/jpeg'];

-- Authenticated employees upload only to their own namespace. No public bucket URLs.
create policy report_photo_upload on storage.objects for insert to authenticated with check(
 bucket_id='report-photos' and (storage.foldername(name))[1]=auth.uid()::text and themelio_private.is_active()
);
create policy report_photo_read on storage.objects for select to authenticated using(
 bucket_id='report-photos' and (
  (storage.foldername(name))[1]=auth.uid()::text or
  (themelio_private.is_director() and exists(select 1 from public.reports where name=any(photo_paths)))
 )
);
-- Uploaded drafts may be cleaned up. Submitted photos are immutable through the client.
create policy report_photo_cleanup on storage.objects for delete to authenticated using(
 bucket_id='report-photos' and (storage.foldername(name))[1]=auth.uid()::text
 and not exists(select 1 from public.reports where name=any(photo_paths))
);

-- Restrictive guards keep this bucket private even when unrelated broad policies exist.
create policy report_photo_read_guard on storage.objects as restrictive for select to authenticated using(
 bucket_id<>'report-photos' or (storage.foldername(name))[1]=auth.uid()::text or
 (themelio_private.is_director() and exists(select 1 from public.reports where name=any(photo_paths)))
);
create policy report_photo_insert_guard on storage.objects as restrictive for insert to authenticated with check(
 bucket_id<>'report-photos' or ((storage.foldername(name))[1]=auth.uid()::text and themelio_private.is_active())
);
create policy report_photo_delete_guard on storage.objects as restrictive for delete to authenticated using(
 bucket_id<>'report-photos' or ((storage.foldername(name))[1]=auth.uid()::text and not exists(select 1 from public.reports where name=any(photo_paths)))
);
create policy report_photo_no_update on storage.objects as restrictive for update to authenticated using(bucket_id<>'report-photos') with check(bucket_id<>'report-photos');
create policy report_photo_no_anon on storage.objects as restrictive for all to anon using(bucket_id<>'report-photos') with check(bucket_id<>'report-photos');

create function public.submit_report_with_photos(p_id uuid,p_title text,p_body text,p_type text,p_date date,p_paths text[]) returns uuid language plpgsql security definer set search_path='' as $$
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
