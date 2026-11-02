-- Complete the pg_cron schedule for the retention jobs that already exist:
-- audit log (365 days) and WhatsApp history (90 days, sent/failed only).
-- The notifications-cron.sh fallback calls the same functions when pg_cron is
-- not available in the shipped image.

do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.schedule(
            'parking-purge-audit',
            '20 3 * * *',
            'select public.purge_audit_log(365)'
        );
        perform cron.schedule(
            'parking-purge-whatsapp',
            '30 3 * * *',
            'select public.purge_whatsapp_messages(90)'
        );
    else
        raise notice 'pg_cron missing: notifications-cron.sh keeps the retention jobs';
    end if;
exception when others then
    raise notice 'retention scheduling skipped: %', sqlerrm;
end $$;
