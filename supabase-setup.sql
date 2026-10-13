-- =====================================================================
-- Stripmap Irigasi — setup database Supabase
-- Jalankan sekali di Supabase › SQL Editor › New query › Run.
-- Aman dijalankan ulang (memakai IF NOT EXISTS / ON CONFLICT).
-- =====================================================================

-- ---------- Tabel ----------
create table if not exists public.paket (
  id text primary key,
  nama text not null,
  urut double precision not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.kabupaten (
  id text primary key,
  paket_id text not null references public.paket(id) on delete cascade,
  nama text not null,
  urut double precision not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.di (
  id text primary key,
  kab_id text not null references public.kabupaten(id) on delete cascade,
  nama text not null,
  urut double precision not null default 0,
  updated_at timestamptz not null default now()
);

-- Satu baris per kode ruas. Kolom "jenis" menyimpan rentang STA dan segmen
-- tiap jenis pekerjaan: { "<jenisId>": { staAwal, staAkhir, items: { "<itemId>": [segmen...] } } }
create table if not exists public.ruas (
  id text primary key,
  di_id text not null references public.di(id) on delete cascade,
  kode text not null,
  ket text not null default '',
  urut double precision not null default 0,
  contoh boolean not null default false,
  jenis jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Pengaturan proyek (selalu satu baris, id = 1): nama proyek + daftar jenis & item pekerjaan
create table if not exists public.config (
  id int primary key default 1 check (id = 1),
  judul text not null default '',
  master jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

-- Daftar editor. Hanya email di tabel ini yang boleh mengubah data.
create table if not exists public.editors (
  email text primary key check (email = lower(email)),
  role text not null default 'editor' check (role in ('editor', 'admin')),
  added_at timestamptz not null default now()
);

-- updated_at otomatis
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
do $$
declare t text;
begin
  foreach t in array array['paket','kabupaten','di','ruas','config'] loop
    execute format('drop trigger if exists trg_touch on public.%I', t);
    execute format('create trigger trg_touch before update on public.%I for each row execute function public.touch_updated_at()', t);
  end loop;
end $$;

-- ---------- Fungsi cek peran ----------
-- Email hanya diakui bila akun login lewat Google (email sudah terverifikasi Google).
create or replace function public.current_email() returns text
language sql stable as $$
  select case
    when coalesce(auth.jwt() -> 'app_metadata' -> 'providers', '[]'::jsonb) ? 'google'
      or auth.jwt() -> 'app_metadata' ->> 'provider' = 'google'
    then lower(auth.jwt() ->> 'email')
  end
$$;

create or replace function public.is_editor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.editors where email = public.current_email())
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.editors where email = public.current_email() and role = 'admin')
$$;

-- ---------- Row Level Security ----------
-- Semua orang (termasuk yang belum login) boleh MELIHAT data stripmap.
-- Hanya editor yang boleh menambah, mengubah, dan menghapus.
do $$
declare t text;
begin
  foreach t in array array['paket','kabupaten','di','ruas','config'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "baca publik" on public.%I', t);
    execute format('drop policy if exists "editor tambah" on public.%I', t);
    execute format('drop policy if exists "editor ubah" on public.%I', t);
    execute format('drop policy if exists "editor hapus" on public.%I', t);
    execute format('create policy "baca publik" on public.%I for select using (true)', t);
    execute format('create policy "editor tambah" on public.%I for insert with check (public.is_editor())', t);
    execute format('create policy "editor ubah" on public.%I for update using (public.is_editor()) with check (public.is_editor())', t);
    execute format('create policy "editor hapus" on public.%I for delete using (public.is_editor())', t);
  end loop;
end $$;

-- Tabel editor: setiap orang hanya bisa melihat barisnya sendiri; admin melihat & mengelola semua.
alter table public.editors enable row level security;
drop policy if exists "lihat diri atau admin" on public.editors;
drop policy if exists "admin tambah" on public.editors;
drop policy if exists "admin ubah" on public.editors;
drop policy if exists "admin hapus" on public.editors;
create policy "lihat diri atau admin" on public.editors for select using (email = public.current_email() or public.is_admin());
create policy "admin tambah" on public.editors for insert with check (public.is_admin());
create policy "admin ubah" on public.editors for update using (public.is_admin()) with check (public.is_admin());
create policy "admin hapus" on public.editors for delete using (public.is_admin());

-- ---------- Realtime (perubahan langsung muncul di semua browser) ----------
do $$
declare t text;
begin
  foreach t in array array['paket','kabupaten','di','ruas','config'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- ---------- Admin ----------
insert into public.editors (email, role) values ('paluinpresiii@gmail.com', 'admin')
on conflict (email) do update set role = 'admin';

-- ---------- Data dari versi claude.ai (salinan per 9 Oktober 2026) ----------
insert into public.config (id, judul, master) values (1, '', $j$[{"id": "gst", "items": [{"id": "gst-1", "nama": "Galian Saluran Tanah"}], "nama": "Pekerjaan Galian Saluran Tanah"}, {"id": "pb", "items": [{"id": "pb-bkr", "nama": "Bongkaran"}, {"id": "pb-gtm", "nama": "Galian Tanah Mekanis"}, {"id": "pb-lt", "nama": "Pasangan Batu (Lantai)"}, {"id": "pb-dka", "nama": "Pasangan Batu (Dinding Kanan)"}, {"id": "pb-dki", "nama": "Pasangan Batu (Dinding Kiri)"}, {"id": "pb-pka", "nama": "Plesteran (Dinding Kanan)"}, {"id": "pb-pki", "nama": "Plesteran (Dinding Kiri)"}, {"id": "pb-aka", "nama": "Acian (Dinding Kanan)"}, {"id": "pb-aki", "nama": "Acian (Dinding Kiri)"}], "nama": "Pekerjaan Pasangan Batu"}, {"id": "gts", "items": [{"id": "gts-1", "nama": "Galian Tanah Sedimentasi"}], "nama": "Pekerjaan Galian Tanah Sedimentasi"}]$j$::jsonb)
on conflict (id) do update set judul = excluded.judul, master = excluded.master;

insert into public.paket (id, nama, urut) values ('p-2', 'Paket 2', 2.0) on conflict (id) do update set nama = excluded.nama, urut = excluded.urut;

insert into public.kabupaten (id, paket_id, nama, urut) values ('9cyu636pv5cv6gxjd6m5', 'p-2', 'Poso', 1791472633574.0) on conflict (id) do update set paket_id = excluded.paket_id, nama = excluded.nama, urut = excluded.urut;
insert into public.kabupaten (id, paket_id, nama, urut) values ('rhp50xvhxhvr0xvbnh86', 'p-2', 'Kab. Banggai', 1791445905941.0) on conflict (id) do update set paket_id = excluded.paket_id, nama = excluded.nama, urut = excluded.urut;
insert into public.kabupaten (id, paket_id, nama, urut) values ('wiy04ds466aak41l1zgx', 'p-2', 'D.I Wanga', 1791546820729.0) on conflict (id) do update set paket_id = excluded.paket_id, nama = excluded.nama, urut = excluded.urut;

insert into public.di (id, kab_id, nama, urut) values ('di-rata', 'rhp50xvhxhvr0xvbnh86', 'D.I. Rata', 1791468273232.0) on conflict (id) do update set kab_id = excluded.kab_id, nama = excluded.nama, urut = excluded.urut;
insert into public.di (id, kab_id, nama, urut) values ('hyk1mvxn4q56b71dqhne', '9cyu636pv5cv6gxjd6m5', 'Kilo Atas', 1791472644678.0) on conflict (id) do update set kab_id = excluded.kab_id, nama = excluded.nama, urut = excluded.urut;

insert into public.ruas (id, di_id, kode, ket, urut, contoh, jenis) values ('d2svh23r8ny2ek2bqk02', 'hyk1mvxn4q56b71dqhne', 'BK.1 Ka- BK.2 Ka', 'Saluran Sekunder', 1791546836428.0, false,
  $j${"pb": {"items": {}, "staAkhir": 1200, "staAwal": 0}}$j$::jsonb)
on conflict (id) do update set di_id = excluded.di_id, kode = excluded.kode, ket = excluded.ket, urut = excluded.urut, contoh = excluded.contoh, jenis = excluded.jenis;
insert into public.ruas (id, di_id, kode, ket, urut, contoh, jenis) values ('nrrfm830w394a5kjv0kp', 'hyk1mvxn4q56b71dqhne', 'BK.1 Ka- BK.2 Ka', '', 1791472649397.0, false,
  $j${"pb": {"items": {"pb-dka": [{"catatan": "", "dari": 20, "id": "ctr6xzm7", "sampai": 65, "status": "selesai", "tanggal": "2026-10-08"}, {"catatan": "", "dari": 100, "id": "jp1kg26n", "sampai": 160, "status": "selesai", "tanggal": "2026-10-08"}], "pb-gtm": [{"catatan": "", "dari": 0, "id": "ojgjm7wv", "sampai": 891.67, "status": "selesai", "tanggal": "2026-10-08"}], "pb-lt": [{"catatan": "", "dari": 20, "id": "pb8yg9pm", "sampai": 75, "status": "selesai", "tanggal": "2026-10-08"}]}, "staAkhir": 891.7, "staAwal": 0}}$j$::jsonb)
on conflict (id) do update set di_id = excluded.di_id, kode = excluded.kode, ket = excluded.ket, urut = excluded.urut, contoh = excluded.contoh, jenis = excluded.jenis;
insert into public.ruas (id, di_id, kode, ket, urut, contoh, jenis) values ('r-rata-1', 'di-rata', 'BRKi 2 - BGK 1', '', 1.0, false,
  $j${"pb": {"items": {"pb-bkr": [{"catatan": "9", "dari": 8, "id": "wf6czbyl", "pekerja": 0, "sampai": 725, "status": "selesai", "tanggal": "2026-10-09"}], "pb-dka": [{"catatan": "", "dari": 8, "id": "5crs95sp", "pekerja": null, "sampai": 145, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 147, "id": "ru2ekilu", "pekerja": null, "sampai": 156, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 164, "id": "96s1olat", "pekerja": null, "sampai": 225, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 240, "id": "vii65rtd", "pekerja": null, "sampai": 307, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 316, "id": "hvky3c8l", "pekerja": null, "sampai": 400, "status": "selesai", "tanggal": "2026-10-09"}], "pb-dki": [{"catatan": "", "dari": 8, "id": "idyek470", "pekerja": null, "sampai": 145, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 147, "id": "9etvt1q0", "pekerja": null, "sampai": 156, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 164, "id": "hmije1nw", "pekerja": null, "sampai": 307, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 316, "id": "ltuv97j5", "pekerja": null, "sampai": 375, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 395, "id": "m56jaekz", "pekerja": null, "sampai": 400, "status": "selesai", "tanggal": "2026-10-09"}], "pb-gtm": [{"catatan": "", "dari": 8, "id": "7goi1sqo", "pekerja": null, "sampai": 725, "status": "selesai", "tanggal": "2026-10-09"}], "pb-lt": [{"catatan": "", "dari": 8, "id": "qfw0ir0t", "pekerja": null, "sampai": 144, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 147, "id": "cbiyfupz", "pekerja": null, "sampai": 156, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 164, "id": "78lymch8", "pekerja": null, "sampai": 200, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 200, "id": "qafwojmv", "pekerja": null, "sampai": 300, "status": "selesai", "tanggal": "2026-10-09"}, {"catatan": "", "dari": 330, "id": "3y8aqyhv", "pekerja": null, "sampai": 375, "status": "selesai", "tanggal": "2026-10-09"}], "pb-pka": [{"catatan": "", "dari": 8, "id": "je6hrrle", "pekerja": 0, "sampai": 125, "status": "selesai", "tanggal": "2026-10-09"}], "pb-pki": [{"catatan": "", "dari": 8, "id": "1mn22ijd", "pekerja": null, "sampai": 125, "status": "selesai", "tanggal": "2026-10-09"}]}, "staAkhir": 740, "staAwal": 8}}$j$::jsonb)
on conflict (id) do update set di_id = excluded.di_id, kode = excluded.kode, ket = excluded.ket, urut = excluded.urut, contoh = excluded.contoh, jenis = excluded.jenis;

-- Selesai.
