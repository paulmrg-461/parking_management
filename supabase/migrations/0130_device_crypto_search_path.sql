-- Device keys are generated and hashed with pgcrypto. Supabase installs it in
-- the `extensions` schema, and these two functions were created with
-- `search_path = public` only, so `register_lot_device` and
-- `rotate_lot_device_key` failed on the real stack with
-- `function gen_random_bytes(integer) does not exist` (the SQL suite only saw
-- a database where pgcrypto resolved from `public`).
--
-- Keep the bodies as they are and widen the search path: pgcrypto is the only
-- extra schema these functions read from, and the app schema stays first.

alter function public.register_lot_device(text, text)
    set search_path = public, extensions;

alter function public.rotate_lot_device_key(integer)
    set search_path = public, extensions;
