-- Run once in a NEW Supabase Free project's SQL Editor. No paid extensions.
begin;
create extension if not exists pgcrypto with schema extensions;
create table public.officers(email text primary key, units text[] not null);
-- Add authorized officer accounts separately; never commit real account emails.
create table public.units(id text primary key,name text not null);
create sequence public.case_number;
create table public.cases (
 id text primary key default ('CASE-'||to_char(now() at time zone 'Asia/Bangkok','YYYY')||'-'||lpad(nextval('public.case_number')::text,6,'0')),
 unit text not null references public.units(id),name text not null check(length(name) between 1 and 200),phone text not null check(length(phone) between 8 and 40),email text not null default '' check(length(email)<=254),details text not null check(length(details) between 1 and 16000),
 status text not null default 'verifying' check(status in ('verifying','verified','in_progress','completed','additional_info')),
 message text not null default '',required text not null default '',created timestamptz not null default now(),updated timestamptz not null default now(),revision integer not null default 0,
 token_hash text not null,request_key uuid unique not null
);
create index cases_unit_created on public.cases(unit,created desc);
create table public.history(id uuid primary key default gen_random_uuid(),case_id text not null references public.cases(id),status text not null,message text not null,actor text not null,created timestamptz not null default now());
create index history_case_created on public.history(case_id,created);
create table public.intake_limits(day date primary key,n integer not null);
alter table public.officers enable row level security;
alter table public.units enable row level security;
alter table public.cases enable row level security;
alter table public.history enable row level security;
alter table public.intake_limits enable row level security;
revoke all on public.officers,public.cases,public.history,public.intake_limits from anon,authenticated;
grant select on public.units to anon,authenticated;
create policy units_read on public.units for select using(true);
-- SECURITY DEFINER functions have fixed search paths and never trust a supplied officer email.
create function public.can_access(p_unit text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.officers where email=lower(auth.jwt()->>'email') and ('*'=any(units) or p_unit=any(units)))
$$;
create function public.my_units() returns setof public.units language sql stable security definer set search_path=public,pg_temp as $$ select * from public.units where public.can_access(id) order by name $$;
create function public.officer_cases(p_unit text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not public.can_access(p_unit) then raise exception 'ไม่มีสิทธิ์เข้าถึงหน่วยงานนี้'; end if;
 return coalesce((select jsonb_agg(to_jsonb(c)-'token_hash'-'request_key' order by created desc) from public.cases c where unit=p_unit),'[]'::jsonb);
end $$;
create function public.officer_case(p_id text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare c public.cases;
begin
 select * into c from public.cases where id=p_id;
 if c.id is null or not public.can_access(c.unit) then raise exception 'ไม่พบคำขอหรือไม่มีสิทธิ์';end if;
 return jsonb_build_object('case',to_jsonb(c)-'token_hash'-'request_key','history',coalesce((select jsonb_agg(to_jsonb(h) order by created desc) from public.history h where case_id=p_id),'[]'::jsonb),'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',name,'name',split_part(name,'/',4),'size',metadata->>'size','created',created_at)) from storage.objects where bucket_id='case-documents' and split_part(name,'/',1)=p_id),'[]'::jsonb));
end $$;
create function public.update_case(p_id text,p_revision integer,p_status text,p_message text,p_required text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.cases;
begin
 select * into c from public.cases where id=p_id for update;
 if c.id is null or not public.can_access(c.unit) then raise exception 'ไม่พบคำขอหรือไม่มีสิทธิ์';end if;
 if c.revision<>p_revision then raise exception 'ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดข้อมูลล่าสุด';end if;
 if p_status not in ('verifying','verified','in_progress','completed','additional_info') or p_status is null then raise exception 'สถานะไม่ถูกต้อง';end if;
 if length(coalesce(p_message,''))>4000 or length(coalesce(p_required,''))>4000 then raise exception 'ข้อความยาวเกินกำหนด';end if;
 if p_status='additional_info' and (length(trim(coalesce(p_message,'')))=0 or length(trim(coalesce(p_required,'')))=0) then raise exception 'กรุณาระบุข้อความและรายการข้อมูลที่ต้องการเพิ่มเติม';end if;
 update public.cases set status=p_status,message=coalesce(p_message,''),required=case when p_status='additional_info' then p_required else '' end,revision=revision+1,updated=now() where id=p_id;
 insert into public.history(case_id,status,message,actor) values(p_id,p_status,concat_ws(E'\n',p_message,case when p_status='additional_info' then p_required end),lower(auth.jwt()->>'email'));
end $$;
create function public.submit_case(p_request_key uuid,p_token text,p_unit text,p_name text,p_phone text,p_email text,p_details text) returns text language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare existing public.cases;new_id text;total integer;
begin
 if p_token is null or p_token!~'^[a-f0-9]{64}$' then raise exception 'รหัสติดตามไม่ถูกต้อง';end if;
 -- Serialize duplicate submissions; retry returns the same ID, no duplicate cases.
 perform pg_advisory_xact_lock(hashtextextended(p_request_key::text,0));
 select * into existing from public.cases where request_key=p_request_key;
 if existing.id is not null then
  if existing.token_hash<>encode(extensions.digest(p_token,'sha256'),'hex') then raise exception 'รหัสคำขอซ้ำ';end if;
  return existing.id;
 end if;
 if length(trim(coalesce(p_name,'')))=0 or length(trim(coalesce(p_details,'')))=0 then raise exception 'กรอกชื่อและรายละเอียด';end if;
 insert into public.intake_limits values(current_date,1) on conflict(day) do update set n=intake_limits.n+1 returning n into total;
 if total>200 then raise exception 'ถึงจำนวนคำขอสูงสุดต่อวัน กรุณาลองใหม่วันถัดไป';end if;
 insert into public.cases(unit,name,phone,email,details,token_hash,request_key) values(p_unit,trim(p_name),p_phone,coalesce(p_email,''),trim(p_details),encode(extensions.digest(p_token,'sha256'),'hex'),p_request_key) returning id into new_id;
 insert into public.history(case_id,status,message,actor) values(new_id,'verifying','รับคำขอจากเว็บไซต์ประชาชน','ผู้ยื่นคำขอ');
 return new_id;
end $$;
create function public.valid_tracking(p_id text,p_token text) returns boolean language sql stable security definer set search_path=public,extensions,pg_temp as $$
 select length(p_token)=64 and exists(select 1 from public.cases where id=p_id and token_hash=encode(extensions.digest(p_token,'sha256'),'hex'))
$$;
create function public.track_case(p_id text,p_token text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare c public.cases;
begin
 if not public.valid_tracking(p_id,p_token) then raise exception 'ไม่พบคำขอหรือรหัสติดตามไม่ถูกต้อง';end if;
 select * into c from public.cases where id=p_id;
 return jsonb_build_object('id',c.id,'unit',c.unit,'unitName',(select name from public.units where id=c.unit),'status',c.status,'updated',c.updated,'message',c.message,'required',c.required,'history',coalesce((select jsonb_agg(jsonb_build_object('status',status,'message',message,'created',created) order by created desc) from public.history where case_id=p_id),'[]'::jsonb));
end $$;
create function public.reply_case(p_id text,p_token text,p_message text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.cases;recent integer;
begin
 select * into c from public.cases where id=p_id for update;
 if not public.valid_tracking(p_id,p_token) then raise exception 'ไม่พบคำขอหรือรหัสติดตามไม่ถูกต้อง';end if;
 if c.status<>'additional_info' then raise exception 'คำขอนี้ไม่ได้อยู่ระหว่างรอข้อมูลเพิ่มเติม';end if;
 if length(trim(coalesce(p_message,''))) not between 1 and 4000 then raise exception 'กรอกข้อความไม่เกิน 4,000 ตัวอักษร';end if;
 select count(*) into recent from public.history where case_id=p_id and actor='ผู้ยื่นคำขอ' and created>now()-interval '1 day';
 if recent>=30 then raise exception 'ส่งข้อมูลถี่เกินไป กรุณาลองภายหลัง';end if;
 insert into public.history(case_id,status,message,actor) values(p_id,c.status,'ข้อมูลเพิ่มเติมจากผู้ยื่น: '||p_message,'ผู้ยื่นคำขอ');
 update public.cases set updated=now(),revision=revision+1 where id=p_id;
end $$;
-- Private bucket: no public document URLs; no anonymous reads or overwrites.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('case-documents','case-documents',false,16777216,array['application/pdf','image/jpeg','image/png','video/mp4','video/webm']);
create function public.can_upload(p_path text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare total integer;
begin
 if not public.valid_tracking(split_part(p_path,'/',1),split_part(p_path,'/',2)) then return false;end if;
 if array_length(string_to_array(p_path,'/'),1)<>4 then return false;end if;
 select count(*) into total from storage.objects where bucket_id='case-documents' and split_part(name,'/',1)=split_part(p_path,'/',1);
 return total<20;
end $$;
create function public.can_read_file(p_path text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$ select exists(select 1 from public.cases where id=split_part(p_path,'/',1) and public.can_access(unit)) $$;
create policy case_upload on storage.objects for insert to anon,authenticated with check(bucket_id='case-documents' and public.can_upload(name));
create policy officer_download on storage.objects for select to authenticated using(bucket_id='case-documents' and public.can_read_file(name));
-- Explicit grants: PostgreSQL otherwise grants function execution to PUBLIC.
revoke execute on function public.can_access(text),public.my_units(),public.officer_cases(text),public.officer_case(text),public.update_case(text,integer,text,text,text),public.submit_case(uuid,text,text,text,text,text,text),public.valid_tracking(text,text),public.track_case(text,text),public.reply_case(text,text,text),public.can_upload(text),public.can_read_file(text) from public;
grant execute on function public.can_access(text),public.my_units(),public.officer_cases(text),public.officer_case(text),public.update_case(text,integer,text,text,text),public.can_read_file(text) to authenticated;
grant execute on function public.submit_case(uuid,text,text,text,text,text,text),public.valid_tracking(text,text),public.track_case(text,text),public.reply_case(text,text,text),public.can_upload(text) to anon,authenticated;
commit;

INSERT INTO public.units(id,name) VALUES
('bma-1','สถานีตำรวจนครบาลโคกคราม'),
('bma-2','สถานีตำรวจนครบาลมีนบุรี'),
('bma-3','สถานีตำรวจนครบาลเตาปูน'),
('bma-4','สถานีตำรวจนครบาลบางโพ'),
('bma-5','สถานีตำรวจนครบาลบางชัน'),
('bma-6','สถานีตำรวจนครบาลสุทธิสาร'),
('bma-7','สถานีตำรวจนครบาลบางซื่อ'),
('bma-8','สถานีตำรวจนครบาลบึงกุ่ม'),
('bma-9','สถานีตำรวจนครบาลสามเสน'),
('bma-10','สถานีตำรวจนครบาลตลิ่งชัน'),
('bma-11','สถานีตำรวจนครบาลห้วยขวาง'),
('bma-12','สถานีตำรวจนครบาลดุสิต'),
('bma-13','สถานีตำรวจนครบาลบวรมงคล'),
('bma-14','สถานีตำรวจนครบาลดินแดง'),
('bma-15','สถานีตำรวจนครบาลวังทองหลาง'),
('bma-16','สถานีตำรวจนครบาลลาดพร้าว'),
('bma-17','สถานีตำรวจนครบาลบางยี่ขัน'),
('bma-18','สถานีตำรวจนครบาลร่มเกล้า'),
('bma-19','สถานีตำรวจนครบาลหัวหมาก'),
('bma-20','สถานีตำรวจนครบาลชนะสงคราม'),
('bma-21','สถานีตำรวจนครบาลบางกอกน้อย'),
('bma-22','สถานีตำรวจนครบาลพญาไท'),
('bma-23','สถานีตำรวจนครบาลนางเลิ้ง'),
('bma-24','สถานีตำรวจนครบาลบางขุนนนท์'),
('bma-25','สถานีตำรวจนครบาลฉลองกรุง'),
('bma-26','สถานีตำรวจนครบาลสำราญราษฎร์'),
('bma-27','สถานีตำรวจนครบาลมักกะสัน'),
('bma-28','สถานีตำรวจนครบาลพลับพลาไชย 1'),
('bma-29','สถานีตำรวจนครบาลพระราชวัง'),
('bma-30','สถานีตำรวจนครบาลบางเสาธง'),
('bma-31','สถานีตำรวจนครบาลบางกอกใหญ่'),
('bma-32','สถานีตำรวจนครบาลคลองตัน'),
('bma-33','สถานีตำรวจนครบาลจักรวรรดิ'),
('bma-34','สถานีตำรวจนครบาลทองหล่อ'),
('bma-35','สถานีตำรวจนครบาลบุปผาราม'),
('bma-36','สถานีตำรวจนครบาลท่าพระ'),
('bma-37','สถานีตำรวจนครบาลลุมพินี'),
('bma-38','สถานีตำรวจนครบาลสมเด็จเจ้าพระย'),
('bma-39','สถานีตำรวจนครบาลบางรัก'),
('bma-40','สถานีตำรวจนครบาลบางยี่เรือ'),
('bma-41','สถานีตำรวจนครบาลประเวศ'),
('bma-42','สถานีตำรวจนครบาลสำเหร่'),
('bma-43','สถานีตำรวจนครบาลตลาดพลู'),
('bma-44','สถานีตำรวจนครบาลยานนาวา'),
('bma-45','สถานีตำรวจนครบาลทุ่งมหาเมฆ'),
('bma-46','สถานีตำรวจนครบาลบางโพงพาง'),
('bma-47','สถานีตำรวจนครบาลภาษีเจริญ'),
('bma-48','สถานีตำรวจนครบาลวัดพระยาไกร'),
('bma-49','สถานีตำรวจนครบาลบุคคโล'),
('bma-50','สถานีตำรวจนครบาลบางคอแหลม'),
('bma-51','สถานีตำรวจนครบาลราษฎร์บูรณะ'),
('bma-52','สถานีตำรวจนครบาลท่าข้าม'),
('bma-53','สถานีตำรวจนครบาลทุ่งครุ'),
('bma-54','สถานีตำรวจนครบาลเทียนทะเล'),
('bma-55','สถานีตำรวจนครบาลสายไหม'),
('bma-56','สถานีตำรวจนครบาลบางเขน'),
('bma-57','สถานีตำรวจนครบาลพหลโยธิน'),
('bma-58','สถานีตำรวจนครบาลบางมด'),
('bma-59','สถานีตำรวจนครบาลบางขุนเทียน'),
('bma-60','สถานีตำรวจนครบาลบางบอน'),
('bma-61','สถานีตำรวจนครบาลหลักสอง'),
('bma-62','สถานีตำรวจนครบาลเพชรเกษม'),
('bma-63','สถานีตำรวจนครบาลหนองแขม'),
('bma-64','สถานีตำรวจนครบาลศาลาแดง'),
('bma-65','สถานีตำรวจนครบาลหนองค้างพลู'),
('bma-66','สถานีตำรวจนครบาลลำหิน'),
('bma-67','สถานีตำรวจนครบาลหนองจอก'),
('bma-68','สถานีตำรวจนครบาลดอนเมือง'),
('bma-69','สถานีตำรวจนครบาลทุ่งสองห้อง'),
('bma-70','สถานีตำรวจนครบาลบางพลัด'),
('bma-71','สถานีตำรวจนครบาลลาดกระบัง'),
('bma-72','สถานีตำรวจนครบาลบางนา'),
('bma-73','สถานีตำรวจนครบาลพระโขนง'),
('bma-74','สถานีตำรวจนครบาลอุดมสุข'),
('bma-75','สถานีตำรวจนครบาลธรรมศาลา'),
('bma-76','สถานีตำรวจนครบาลคันนายาว'),
('bma-77','สถานีตำรวจนครบาลนิมิตรใหม่'),
('bma-78','สถานีตำรวจนครบาลโชคชัย'),
('bma-79','สถานีตำรวจนครบาลแสมดำ'),
('bma-80','สถานีตำรวจนครบาลท่าเรือ'),
('bma-81','สถานีตำรวจนครบาลลำผักชี'),
('bma-82','สถานีตำรวจนครบาลประชาชื่น'),
('bma-83','สถานีตำรวจนครบาลปากคลองสาน'),
('bma-84','สถานีตำรวจนครบาลสุวินทวงศ์'),
('bma-85','สถานีตำรวจนครบาลปทุมวัน'),
('bma-86','สถานีตำรวจนครบาลจรเข้น้อย'),
('bma-87','สถานีตำรวจนครบาลประชาสำราญ'),
('bma-88','สถานีตำรวจนครบาลพลับพลาไชย 2'),
('other','หน่วยงานอื่น ๆ');
