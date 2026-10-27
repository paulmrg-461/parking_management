-- Default vehicle categories (same set as backend/scripts/seed_categories.py).
insert into public.categories (name)
values ('moto'), ('car'), ('camioneta'), ('camion'), ('bus')
on conflict (name) do nothing;
