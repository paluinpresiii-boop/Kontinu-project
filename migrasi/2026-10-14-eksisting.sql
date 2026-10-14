-- =====================================================================
-- Migrasi 2026-10-14 — panjang eksisting per kode ruas
-- Jalankan sekali di Supabase › SQL Editor › New query › Run.
-- Aman dijalankan ulang.
--
-- Kolom "eksisting" menyimpan daftar rentang STA eksisting:
--   [ { "id": "...", "dari": 200, "sampai": 350, "ket": "Pasangan lama masih baik" }, ... ]
-- Panjang eksisting dikeluarkan dari target (100%) semua jenis pekerjaan di ruas tersebut.
-- =====================================================================
alter table public.ruas
  add column if not exists eksisting jsonb not null default '[]'::jsonb;
