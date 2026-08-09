-- Maarch Courrier sends dates as DD-MM-YYYY. Align the Postgres datestyle so runtime
-- inserts don't fail with "date/time field value out of range".
ALTER DATABASE maarch_courrier SET datestyle = 'ISO, DMY';
