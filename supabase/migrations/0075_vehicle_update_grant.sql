-- The admin vehicle editor PATCHes color/brand/category directly (the RLS
-- policy `vehicles_admin_write` already restricts it to admins). The UPDATE
-- grant was missing, so the repository update path failed with a permission
-- error.

grant update on public.vehicles to authenticated;
