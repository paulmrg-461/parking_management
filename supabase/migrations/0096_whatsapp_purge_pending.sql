-- WhatsApp queue, retention: a message that has been waiting for months will
-- never be sent (the lot had no credentials or the dispatch was off), so the
-- purge now drops pending rows too. Otherwise a site with `whatsapp_auto` on
-- and no token would grow the queue forever, one row per receipt, booking and
-- reminder.

create or replace function public.purge_whatsapp_messages(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    delete from public.whatsapp_messages m
     where m.created_at < now() - make_interval(days => greatest(coalesce(p_days, 1), 1));
    get diagnostics changed = row_count;
    return changed;
end;
$$;

grant execute on function public.purge_whatsapp_messages(integer) to authenticated;
