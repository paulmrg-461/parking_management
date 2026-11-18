-- Electronic invoicing — settings, numbering, issuance, the outbox and the
-- credit-note flow. No existing RPC is re-declared: issuance is a separate
-- call after check-out (or the cron sweeper), so `check_out` keeps its shape.
-- Every regulatory choice is data; `mode = 'off'` is the shipped default.

-- ---------------------------------------------------------------------------
-- Readers and validation helpers.
-- ---------------------------------------------------------------------------
create or replace function public.fiscal_settings_json(p_lot_id integer)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'mode', coalesce(fs.mode, 'off'),
        'issuer_nit', fs.issuer_nit,
        'issuer_legal_name', fs.issuer_legal_name,
        'tax_regime', coalesce(fs.tax_regime, 'responsable_iva'),
        'tax_rate_bps', coalesce(fs.tax_rate_bps, 1900),
        'municipality_code', fs.municipality_code,
        'started_at', fs.started_at,
        'updated_at', fs.updated_at
    )
      from (select p_lot_id as lot_id) l
      left join public.fiscal_settings fs on fs.lot_id = l.lot_id;
$$;

revoke all on function public.fiscal_settings_json(integer)
    from public, anon, authenticated;

create or replace function public.fiscal_resolution_json(
    p_resolution public.fiscal_resolutions
)
returns jsonb
language sql
immutable
set search_path = public
as $$
    select jsonb_build_object(
        'id', p_resolution.id,
        'doc_type', p_resolution.doc_type,
        'resolution_number', p_resolution.resolution_number,
        'prefix', p_resolution.prefix,
        'range_from', p_resolution.range_from,
        'range_to', p_resolution.range_to,
        'next_number', p_resolution.next_number,
        'valid_from', p_resolution.valid_from,
        'valid_to', p_resolution.valid_to,
        'active', p_resolution.active,
        'remaining', p_resolution.range_to - p_resolution.next_number + 1
    );
$$;

revoke all on function public.fiscal_resolution_json(public.fiscal_resolutions)
    from public, anon, authenticated;

create or replace function public.fiscal_customer(p_customer jsonb)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
    doc_type text;
    doc_number text;
    customer_name text;
    email text;
begin
    if p_customer is null or jsonb_typeof(p_customer) <> 'object' then
        return jsonb_build_object('present', false);
    end if;
    if coalesce(btrim(p_customer ->> 'document_type'), '') = ''
       and coalesce(btrim(p_customer ->> 'document_number'), '') = ''
       and coalesce(btrim(p_customer ->> 'name'), '') = ''
       and coalesce(btrim(p_customer ->> 'email'), '') = '' then
        return jsonb_build_object('present', false);
    end if;

    doc_type := upper(btrim(coalesce(p_customer ->> 'document_type', '')));
    doc_number := upper(regexp_replace(
        coalesce(p_customer ->> 'document_number', ''), '\s', '', 'g'));
    customer_name := btrim(coalesce(p_customer ->> 'name', ''));
    email := nullif(btrim(coalesce(p_customer ->> 'email', '')), '');

    if doc_type not in ('CC', 'NIT', 'CE', 'PP', 'TI', 'RC', 'TE', 'DIE')
       or doc_number !~ '^[A-Za-z0-9]{3,20}$'
       or length(customer_name) < 2 or length(customer_name) > 120
       or (email is not null and (
               length(email) > 120
               or email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')) then
        raise exception 'InvalidFiscalCustomerError';
    end if;

    return jsonb_build_object(
        'present', true,
        'document_type', doc_type,
        'document_number', doc_number,
        'name', customer_name,
        'email', email
    );
end;
$$;

revoke all on function public.fiscal_customer(jsonb)
    from public, anon, authenticated;

create or replace function public.fiscal_document_summary(p_document_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'document_id', d.id,
        'id', d.id,
        'doc_type', d.doc_type,
        'full_number', d.full_number,
        'status', d.status,
        'total', d.total,
        'tax_amount', d.tax_amount,
        'issued_at', d.issued_at,
        'cufe', d.cufe,
        'qr_data', d.qr_data
    )
      from public.fiscal_documents d
     where d.id = p_document_id;
$$;

revoke all on function public.fiscal_document_summary(bigint)
    from public, anon, authenticated;

create or replace function public.fiscal_notify_admins(
    p_lot_id integer,
    p_type text,
    p_title text,
    p_body text,
    p_data jsonb,
    p_dedupe_prefix text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    queued integer := 0;
begin
    insert into public.notifications (user_id, type, title, body, data, dedupe_key, lot_id)
    select u.id, p_type, p_title, p_body, p_data,
           p_dedupe_prefix || ':user:' || u.id, p_lot_id
      from public.lot_members lm
      join public.users u on u.id = lm.user_id
     where lm.lot_id = p_lot_id
       and lm.role = 'admin'
       and u.is_active
    on conflict (dedupe_key) do nothing;
    get diagnostics queued = row_count;
    return queued;
end;
$$;

revoke all on function public.fiscal_notify_admins(integer, text, text, text, jsonb, text)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Gap-free numbering under the resolution row lock.
-- ---------------------------------------------------------------------------
create or replace function public.next_fiscal_number(
    p_lot_id integer,
    p_doc_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    resolution public.fiscal_resolutions%rowtype;
    tz text;
    today date;
begin
    if p_doc_type not in ('pos', 'invoice', 'credit_note') then
        raise exception 'FiscalResolutionMissingError';
    end if;

    select * into resolution
      from public.fiscal_resolutions r
     where r.lot_id = p_lot_id
       and r.doc_type = p_doc_type
       and r.active
     for update;
    if not found then
        raise exception 'FiscalResolutionMissingError';
    end if;

    select coalesce(business_timezone, 'America/Bogota') into tz
      from public.parking_settings where lot_id = p_lot_id;
    tz := coalesce(tz, 'America/Bogota');
    today := (now() at time zone tz)::date;

    if resolution.valid_from > today or resolution.valid_to < today then
        raise exception 'FiscalResolutionExpiredError';
    end if;
    if resolution.next_number > resolution.range_to then
        raise exception 'FiscalResolutionExhaustedError';
    end if;

    update public.fiscal_resolutions
       set next_number = next_number + 1
     where id = resolution.id;

    return jsonb_build_object(
        'resolution_id', resolution.id,
        'prefix', resolution.prefix,
        'number', resolution.next_number
    );
end;
$$;

revoke all on function public.next_fiscal_number(integer, text)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Canonical, provider-neutral payload.
-- ---------------------------------------------------------------------------
create or replace function public.fiscal_document_payload(p_document_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    document public.fiscal_documents%rowtype;
    resolution public.fiscal_resolutions%rowtype;
    settings public.fiscal_settings%rowtype;
    lot public.parking_lots%rowtype;
    plate text;
    ticket text;
    description text;
    payments jsonb := '[]'::jsonb;
    online integer := 0;
    rest integer := 0;
    session public.parking_sessions%rowtype;
    payment public.monthly_pass_payments%rowtype;
    original public.fiscal_documents%rowtype;
    customer jsonb;
begin
    select * into document from public.fiscal_documents d where d.id = p_document_id;
    if not found then
        raise exception 'FiscalDocumentNotFoundError';
    end if;
    select * into resolution from public.fiscal_resolutions r where r.id = document.resolution_id;
    select * into settings from public.fiscal_settings fs where fs.lot_id = document.lot_id;
    select * into lot from public.parking_lots l where l.id = document.lot_id;

    if document.source_kind = 'session' then
        select * into session from public.parking_sessions s where s.id = document.source_id;
        select v.plate into plate from public.vehicles v where v.id = session.vehicle_id;
        ticket := session.ticket_number;
        description := 'Servicio de parqueadero ' || coalesce(plate, '');
        online := least(coalesce(session.online_paid_amount, 0), document.total);
        rest := greatest(document.total - online, 0);
        if online > 0 then
            payments := payments || jsonb_build_object('method', 'online', 'amount', online);
        end if;
        if rest > 0 then
            payments := payments || jsonb_build_object(
                'method', coalesce(session.payment_method, 'cash'),
                'amount', rest
            );
        end if;
    else
        select * into payment from public.monthly_pass_payments p where p.id = document.source_id;
        select v.plate into plate
          from public.monthly_passes mp
          join public.vehicles v on v.id = mp.vehicle_id
         where mp.id = payment.monthly_pass_id;
        ticket := null;
        description := 'Mensualidad de parqueadero ' || coalesce(plate, '');
        payments := jsonb_build_array(jsonb_build_object(
            'method', coalesce(payment.payment_method, 'cash'),
            'amount', document.total
        ));
    end if;

    if document.customer_doc_type is null then
        customer := jsonb_build_object(
            'is_final_consumer', true,
            'document_type', null,
            'document_number', null,
            'name', 'Consumidor final',
            'email', null
        );
    else
        customer := jsonb_build_object(
            'is_final_consumer', false,
            'document_type', document.customer_doc_type,
            'document_number', document.customer_doc_number,
            'name', document.customer_name,
            'email', document.customer_email
        );
    end if;

    if document.doc_type = 'credit_note' then
        select * into original from public.fiscal_documents d
         where d.id = document.related_document_id;
    end if;

    return jsonb_build_object(
        'lot_id', document.lot_id,
        'document', jsonb_build_object(
            'type', document.doc_type,
            'prefix', document.prefix,
            'number', document.number,
            'full_number', document.full_number,
            'issued_at', document.issued_at,
            'currency', document.currency,
            'environment', 'habilitacion'
        ),
        'resolution', jsonb_build_object(
            'number', resolution.resolution_number,
            'prefix', resolution.prefix,
            'range_from', resolution.range_from,
            'range_to', resolution.range_to,
            'valid_from', resolution.valid_from,
            'valid_to', resolution.valid_to
        ),
        'issuer', jsonb_build_object(
            'nit', settings.issuer_nit,
            'legal_name', settings.issuer_legal_name,
            'trade_name', lot.name,
            'address', lot.address,
            'municipality_code', settings.municipality_code,
            'tax_regime', settings.tax_regime
        ),
        'customer', customer,
        'lines', jsonb_build_array(jsonb_build_object(
            'description', description,
            'quantity', 1,
            'unit_price', document.tax_base,
            'tax_rate_bps', document.tax_rate_bps,
            'tax_amount', document.tax_amount,
            'line_total', document.total
        )),
        'totals', jsonb_build_object(
            'gross', document.gross_amount,
            'discount', document.discount_amount,
            'tax_base', document.tax_base,
            'tax_amount', document.tax_amount,
            'total', document.total
        ),
        'payments', payments,
        'reference', jsonb_build_object(
            'document_full_number', original.full_number,
            'cufe', original.cufe,
            'reason', document.credit_reason
        ),
        'source', jsonb_build_object(
            'kind', document.source_kind,
            'id', document.source_id,
            'ticket_number', ticket
        )
    );
end;
$$;

revoke all on function public.fiscal_document_payload(bigint)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Internal issuance (shared by the operator call and the cron sweeper).
-- ---------------------------------------------------------------------------
create or replace function public.fiscal_create_document(
    p_lot_id integer,
    p_source_kind text,
    p_source_id bigint,
    p_customer jsonb,
    p_actor integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    settings public.fiscal_settings%rowtype;
    existing public.fiscal_documents%rowtype;
    customer jsonb;
    doc_type text;
    total integer;
    discount integer;
    resolution jsonb;
    amounts jsonb;
    new_id bigint;
    summary jsonb;
begin
    select * into settings from public.fiscal_settings fs where fs.lot_id = p_lot_id;
    if not found then
        return null;
    end if;

    perform pg_advisory_xact_lock(hashtext('fiscal_source'), p_source_id::integer);

    select * into existing
      from public.fiscal_documents d
     where d.source_kind = p_source_kind
       and d.source_id = p_source_id
       and d.doc_type in ('pos', 'invoice')
       and d.voided_at is null
     order by d.id desc
     limit 1;
    if found then
        return public.fiscal_document_summary(existing.id)
            || jsonb_build_object('created', false);
    end if;

    if p_source_kind = 'session' then
        select s.amount_charged, s.discount_amount
          into total, discount
          from public.parking_sessions s
         where s.id = p_source_id and s.lot_id = p_lot_id;
    elsif p_source_kind = 'pass_payment' then
        select p.amount, 0 into total, discount
          from public.monthly_pass_payments p
         where p.id = p_source_id and p.lot_id = p_lot_id;
    else
        return null;
    end if;

    customer := public.fiscal_customer(p_customer);
    doc_type := case when (customer ->> 'present')::boolean then 'invoice' else 'pos' end;

    resolution := public.next_fiscal_number(p_lot_id, doc_type);
    amounts := public.fiscal_amounts(total, discount, settings.tax_rate_bps);

    insert into public.fiscal_documents (
        lot_id, doc_type, resolution_id, prefix, number, full_number,
        source_kind, source_id, currency,
        gross_amount, discount_amount, tax_rate_bps, tax_base, tax_amount, total,
        customer_doc_type, customer_doc_number, customer_name, customer_email,
        created_by
    )
    values (
        p_lot_id, doc_type, (resolution ->> 'resolution_id')::bigint,
        resolution ->> 'prefix', (resolution ->> 'number')::bigint,
        (resolution ->> 'prefix') || (resolution ->> 'number'),
        p_source_kind, p_source_id, 'COP',
        (amounts ->> 'gross')::integer,
        (amounts ->> 'discount')::integer,
        settings.tax_rate_bps,
        (amounts ->> 'tax_base')::integer,
        (amounts ->> 'tax_amount')::integer,
        (amounts ->> 'total')::integer,
        case when (customer ->> 'present')::boolean
             then customer ->> 'document_type' end,
        case when (customer ->> 'present')::boolean
             then customer ->> 'document_number' end,
        case when (customer ->> 'present')::boolean
             then customer ->> 'name' end,
        case when (customer ->> 'present')::boolean
             then customer ->> 'email' end,
        p_actor
    )
    returning id into new_id;

    summary := public.fiscal_document_summary(new_id);
    return summary || jsonb_build_object('created', true);
end;
$$;

revoke all on function public.fiscal_create_document(integer, text, bigint, jsonb, integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Admin configuration.
-- ---------------------------------------------------------------------------
create or replace function public.fiscal_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer;
    settings public.fiscal_settings%rowtype;
begin
    perform public.require_app_user();
    lot := public.current_lot_id();
    select * into settings from public.fiscal_settings fs where fs.lot_id = lot;
    return jsonb_build_object(
        'mode', coalesce(settings.mode, 'off'),
        'has_pos_resolution', exists (
            select 1 from public.fiscal_resolutions r
             where r.lot_id = lot and r.doc_type = 'pos' and r.active),
        'has_invoice_resolution', exists (
            select 1 from public.fiscal_resolutions r
             where r.lot_id = lot and r.doc_type = 'invoice' and r.active),
        'tax_rate_bps', coalesce(settings.tax_rate_bps, 1900)
    );
end;
$$;

revoke all on function public.fiscal_config() from public;
grant execute on function public.fiscal_config() to authenticated;

create or replace function public.get_fiscal_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
begin
    return public.fiscal_settings_json(lot);
end;
$$;

revoke all on function public.get_fiscal_settings() from public;
grant execute on function public.get_fiscal_settings() to authenticated;

create or replace function public.save_fiscal_settings(p_settings jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    current_settings public.fiscal_settings%rowtype;
    mode_value text;
    nit text;
    legal_name text;
    regime text;
    rate integer;
    municipality text;
    started timestamptz;
begin
    if p_settings is null or jsonb_typeof(p_settings) <> 'object' then
        raise exception 'FiscalSettingsIncompleteError';
    end if;
    select * into current_settings from public.fiscal_settings fs where fs.lot_id = lot;

    mode_value := case when p_settings ? 'mode'
        then lower(btrim(coalesce(p_settings ->> 'mode', 'off')))
        else coalesce(current_settings.mode, 'off') end;
    nit := case when p_settings ? 'issuer_nit'
        then nullif(btrim(coalesce(p_settings ->> 'issuer_nit', '')), '')
        else current_settings.issuer_nit end;
    legal_name := case when p_settings ? 'issuer_legal_name'
        then nullif(btrim(coalesce(p_settings ->> 'issuer_legal_name', '')), '')
        else current_settings.issuer_legal_name end;
    regime := case when p_settings ? 'tax_regime'
        then lower(btrim(coalesce(p_settings ->> 'tax_regime', '')))
        else coalesce(current_settings.tax_regime, 'responsable_iva') end;
    rate := case when p_settings ? 'tax_rate_bps'
        then (p_settings ->> 'tax_rate_bps')::integer
        else coalesce(current_settings.tax_rate_bps, 1900) end;
    municipality := case when p_settings ? 'municipality_code'
        then nullif(btrim(coalesce(p_settings ->> 'municipality_code', '')), '')
        else current_settings.municipality_code end;

    if mode_value not in ('off', 'on_request', 'always') then
        raise exception 'InvalidDataError';
    end if;
    if regime not in ('responsable_iva', 'no_responsable_iva', 'simple') then
        raise exception 'InvalidDataError';
    end if;
    if rate is null or rate < 0 or rate > 10000 then
        raise exception 'InvalidDataError';
    end if;
    if mode_value <> 'off'
       and (nit is null or legal_name is null or municipality is null) then
        raise exception 'FiscalSettingsIncompleteError';
    end if;

    started := current_settings.started_at;
    if mode_value <> 'off' and started is null then
        started := now();
    end if;

    insert into public.fiscal_settings (
        lot_id, mode, issuer_nit, issuer_legal_name, tax_regime,
        tax_rate_bps, municipality_code, started_at, updated_at
    )
    values (
        lot, mode_value, nit, legal_name, regime, rate, municipality,
        started, now()
    )
    on conflict (lot_id) do update
       set mode = excluded.mode,
           issuer_nit = excluded.issuer_nit,
           issuer_legal_name = excluded.issuer_legal_name,
           tax_regime = excluded.tax_regime,
           tax_rate_bps = excluded.tax_rate_bps,
           municipality_code = excluded.municipality_code,
           started_at = excluded.started_at,
           updated_at = now();

    return public.fiscal_settings_json(lot);
end;
$$;

revoke all on function public.save_fiscal_settings(jsonb) from public;
grant execute on function public.save_fiscal_settings(jsonb) to authenticated;

create or replace function public.save_fiscal_resolution(p_resolution jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    doc_kind text;
    resolution_number text;
    prefix text;
    range_from bigint;
    range_to bigint;
    valid_from date;
    valid_to date;
    saved public.fiscal_resolutions%rowtype;
begin
    if p_resolution is null or jsonb_typeof(p_resolution) <> 'object' then
        raise exception 'InvalidDataError';
    end if;
    doc_kind := lower(btrim(coalesce(p_resolution ->> 'doc_type', '')));
    resolution_number := btrim(coalesce(p_resolution ->> 'resolution_number', ''));
    prefix := coalesce(btrim(p_resolution ->> 'prefix'), '');
    range_from := (p_resolution ->> 'range_from')::bigint;
    range_to := (p_resolution ->> 'range_to')::bigint;
    valid_from := (p_resolution ->> 'valid_from')::date;
    valid_to := (p_resolution ->> 'valid_to')::date;

    if doc_kind not in ('pos', 'invoice', 'credit_note')
       or resolution_number = ''
       or prefix !~ '^[A-Za-z0-9]{0,6}$'
       or range_from is null or range_from <= 0
       or range_to is null or range_to < range_from
       or valid_from is null or valid_to is null or valid_to < valid_from then
        raise exception 'InvalidDataError';
    end if;

    update public.fiscal_resolutions r
       set active = false
     where r.lot_id = lot and r.doc_type = doc_kind and r.active;

    insert into public.fiscal_resolutions (
        lot_id, doc_type, resolution_number, prefix, range_from, range_to,
        next_number, valid_from, valid_to, active
    )
    values (
        lot, doc_kind, resolution_number, prefix, range_from, range_to,
        range_from, valid_from, valid_to, true
    )
    returning * into saved;

    return public.fiscal_resolution_json(saved);
end;
$$;

revoke all on function public.save_fiscal_resolution(jsonb) from public;
grant execute on function public.save_fiscal_resolution(jsonb) to authenticated;

create or replace function public.list_fiscal_resolutions()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
begin
    return coalesce((
        select jsonb_agg(public.fiscal_resolution_json(r) order by r.created_at desc, r.id desc)
          from public.fiscal_resolutions r
         where r.lot_id = lot
    ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_fiscal_resolutions() from public;
grant execute on function public.list_fiscal_resolutions() to authenticated;

-- ---------------------------------------------------------------------------
-- Issuance and reads.
-- ---------------------------------------------------------------------------
create or replace function public.issue_fiscal_document(
    p_source_kind text,
    p_source_id bigint,
    p_customer jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    uid integer := public.require_app_user();
    lot integer := public.current_lot_id();
    settings public.fiscal_settings%rowtype;
    source_lot integer;
    billable boolean := false;
begin
    if p_source_kind not in ('session', 'pass_payment') then
        raise exception 'FiscalSourceNotFoundError';
    end if;
    select * into settings from public.fiscal_settings fs where fs.lot_id = lot;
    if not found or coalesce(settings.mode, 'off') = 'off' then
        raise exception 'FiscalNotEnabledError';
    end if;

    if p_source_kind = 'session' then
        select s.lot_id,
               s.status = 'closed'
               and coalesce(s.amount_charged, 0) > 0
               and coalesce(s.payment_method, '') <> 'exempt'
               and s.closed_recorded_at is not null
               and settings.started_at is not null
               and s.closed_recorded_at >= settings.started_at
          into source_lot, billable
          from public.parking_sessions s where s.id = p_source_id;
    else
        select p.lot_id,
               p.status = 'paid'
               and coalesce(p.amount, 0) > 0
               and p.paid_at is not null
               and settings.started_at is not null
               and p.paid_at >= settings.started_at
          into source_lot, billable
          from public.monthly_pass_payments p where p.id = p_source_id;
    end if;
    if source_lot is null then
        raise exception 'FiscalSourceNotFoundError';
    end if;
    if source_lot <> lot then
        raise exception 'FiscalSourceNotFoundError';
    end if;
    if not coalesce(billable, false) then
        raise exception 'FiscalSourceNotBillableError';
    end if;

    perform public.fiscal_customer(p_customer);
    return public.fiscal_create_document(lot, p_source_kind, p_source_id, p_customer, uid);
end;
$$;

revoke all on function public.issue_fiscal_document(text, bigint, jsonb) from public;
grant execute on function public.issue_fiscal_document(text, bigint, jsonb)
    to authenticated;

create or replace function public.fiscal_document_for_session(p_session_id integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer;
    session public.parking_sessions%rowtype;
    document public.fiscal_documents%rowtype;
begin
    perform public.require_app_user();
    lot := public.current_lot_id();
    select * into session from public.parking_sessions s where s.id = p_session_id;
    if not found or session.lot_id <> lot then
        raise exception 'FiscalSourceNotFoundError';
    end if;

    select * into document
      from public.fiscal_documents d
     where d.source_kind = 'session'
       and d.source_id = p_session_id
       and d.doc_type in ('pos', 'invoice')
       and d.voided_at is null
     order by d.id desc
     limit 1;
    if not found then
        return null;
    end if;

    return jsonb_build_object(
        'document_id', document.id,
        'doc_type', document.doc_type,
        'full_number', document.full_number,
        'status', document.status,
        'cufe', document.cufe,
        'qr_data', document.qr_data,
        'total', document.total,
        'tax_amount', document.tax_amount,
        'issued_at', document.issued_at
    );
end;
$$;

revoke all on function public.fiscal_document_for_session(integer) from public;
grant execute on function public.fiscal_document_for_session(integer)
    to authenticated;

create or replace function public.list_fiscal_documents(
    p_status text default null,
    p_limit integer default 50,
    p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    status_filter text := nullif(lower(btrim(coalesce(p_status, ''))), '');
    max_rows integer := least(greatest(coalesce(p_limit, 50), 1), 200);
    skip_rows integer := greatest(coalesce(p_offset, 0), 0);
    total_rows bigint;
    items jsonb;
begin
    if status_filter is not null
       and status_filter not in ('pending', 'sent', 'accepted', 'rejected', 'failed') then
        raise exception 'InvalidDataError';
    end if;

    select count(*) into total_rows
      from public.fiscal_documents d
     where d.lot_id = lot
       and (status_filter is null or d.status = status_filter);

    select coalesce(jsonb_agg(jsonb_build_object(
               'id', d.id,
               'doc_type', d.doc_type,
               'full_number', d.full_number,
               'status', d.status,
               'total', d.total,
               'tax_amount', d.tax_amount,
               'issued_at', d.issued_at,
               'source_kind', d.source_kind,
               'source_id', d.source_id,
               'customer_name', d.customer_name,
               'customer_doc_type', d.customer_doc_type,
               'customer_doc_number', d.customer_doc_number,
               'cufe', d.cufe,
               'rejection_reason', d.rejection_reason,
               'last_error', d.last_error,
               'attempts', d.attempts,
               'voided_at', d.voided_at
           ) order by d.id desc), '[]'::jsonb)
      into items
      from (
          select * from public.fiscal_documents d
           where d.lot_id = lot
             and (status_filter is null or d.status = status_filter)
           order by d.id desc
           limit max_rows offset skip_rows
      ) d;

    return jsonb_build_object('total', total_rows, 'items', items);
end;
$$;

revoke all on function public.list_fiscal_documents(text, integer, integer) from public;
grant execute on function public.list_fiscal_documents(text, integer, integer)
    to authenticated;

create or replace function public.retry_fiscal_document(
    p_document_id bigint,
    p_customer jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    document public.fiscal_documents%rowtype;
    customer jsonb;
begin
    select * into document
      from public.fiscal_documents d
     where d.id = p_document_id and d.lot_id = lot
     for update;
    if not found then
        raise exception 'FiscalDocumentNotFoundError';
    end if;
    if document.status not in ('rejected', 'failed') then
        raise exception 'InvalidFiscalStatusError';
    end if;

    customer := public.fiscal_customer(p_customer);
    if (customer ->> 'present')::boolean then
        document.customer_doc_type := customer ->> 'document_type';
        document.customer_doc_number := customer ->> 'document_number';
        document.customer_name := customer ->> 'name';
        document.customer_email := customer ->> 'email';
    end if;

    update public.fiscal_documents
       set status = 'pending',
           attempts = 0,
           next_attempt_at = now(),
           locked_until = null,
           last_error = null,
           rejection_reason = null,
           provider_document_id = null,
           customer_doc_type = document.customer_doc_type,
           customer_doc_number = document.customer_doc_number,
           customer_name = document.customer_name,
           customer_email = document.customer_email
     where id = document.id;

    return public.fiscal_document_summary(document.id);
end;
$$;

revoke all on function public.retry_fiscal_document(bigint, jsonb) from public;
grant execute on function public.retry_fiscal_document(bigint, jsonb)
    to authenticated;

create or replace function public.request_credit_note(
    p_document_id bigint,
    p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    lot integer := public.require_lot_admin();
    uid integer := public.require_app_user();
    document public.fiscal_documents%rowtype;
    reason text := btrim(coalesce(p_reason, ''));
    resolution jsonb;
    new_id bigint;
begin
    if length(reason) < 3 or length(reason) > 200 then
        raise exception 'InvalidDataError';
    end if;
    select * into document
      from public.fiscal_documents d
     where d.id = p_document_id and d.lot_id = lot
     for update;
    if not found then
        raise exception 'FiscalDocumentNotFoundError';
    end if;
    if document.doc_type = 'credit_note'
       or document.status <> 'accepted'
       or document.voided_at is not null then
        raise exception 'FiscalDocumentNotAcceptedError';
    end if;
    if exists (
        select 1 from public.fiscal_documents d
         where d.related_document_id = document.id
           and d.doc_type = 'credit_note'
           and d.status not in ('rejected', 'failed')
    ) then
        raise exception 'FiscalDocumentAlreadyCreditedError';
    end if;

    resolution := public.next_fiscal_number(lot, 'credit_note');
    insert into public.fiscal_documents (
        lot_id, doc_type, resolution_id, prefix, number, full_number,
        source_kind, source_id, related_document_id, credit_reason, currency,
        gross_amount, discount_amount, tax_rate_bps, tax_base, tax_amount, total,
        customer_doc_type, customer_doc_number, customer_name, customer_email,
        created_by
    )
    values (
        lot, 'credit_note', (resolution ->> 'resolution_id')::bigint,
        resolution ->> 'prefix', (resolution ->> 'number')::bigint,
        (resolution ->> 'prefix') || (resolution ->> 'number'),
        document.source_kind, document.source_id, document.id, reason, 'COP',
        document.gross_amount, document.discount_amount, document.tax_rate_bps,
        document.tax_base, document.tax_amount, document.total,
        document.customer_doc_type, document.customer_doc_number,
        document.customer_name, document.customer_email, uid
    )
    returning id into new_id;

    return public.fiscal_document_summary(new_id);
end;
$$;

revoke all on function public.request_credit_note(bigint, text) from public;
grant execute on function public.request_credit_note(bigint, text)
    to authenticated;

-- ---------------------------------------------------------------------------
-- Cron sweeper: default POS documents and low-resolution notices.
-- ---------------------------------------------------------------------------
create or replace function public.enqueue_pending_fiscal_documents()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    settings public.fiscal_settings%rowtype;
    created integer := 0;
    row_id bigint;
    resolution public.fiscal_resolutions%rowtype;
    tz text;
    today date;
    remaining bigint;
begin
    for settings in
        select * from public.fiscal_settings fs
         where fs.mode = 'always' and fs.started_at is not null
    loop
        if not exists (
            select 1 from public.fiscal_resolutions r
             where r.lot_id = settings.lot_id
               and r.doc_type = 'pos'
               and r.active
        ) then
            continue;
        end if;

        for row_id in
            select s.id from public.parking_sessions s
             where s.lot_id = settings.lot_id
               and s.status = 'closed'
               and coalesce(s.amount_charged, 0) > 0
               and coalesce(s.payment_method, '') <> 'exempt'
               and s.closed_recorded_at is not null
               and s.closed_recorded_at >= settings.started_at
               and s.closed_recorded_at <= now() - interval '10 minutes'
               and not exists (
                   select 1 from public.fiscal_documents d
                    where d.source_kind = 'session' and d.source_id = s.id
                      and d.doc_type in ('pos', 'invoice') and d.voided_at is null)
             order by s.id
        loop
            begin
                perform public.fiscal_create_document(
                    settings.lot_id, 'session', row_id, null, null);
                created := created + 1;
            exception when others then
                null;
            end;
        end loop;

        for row_id in
            select p.id from public.monthly_pass_payments p
             where p.lot_id = settings.lot_id
               and p.status = 'paid'
               and coalesce(p.amount, 0) > 0
               and p.paid_at is not null
               and p.paid_at >= settings.started_at
               and p.paid_at <= now() - interval '10 minutes'
               and not exists (
                   select 1 from public.fiscal_documents d
                    where d.source_kind = 'pass_payment' and d.source_id = p.id
                      and d.doc_type in ('pos', 'invoice') and d.voided_at is null)
             order by p.id
        loop
            begin
                perform public.fiscal_create_document(
                    settings.lot_id, 'pass_payment', row_id, null, null);
                created := created + 1;
            exception when others then
                null;
            end;
        end loop;
    end loop;

    -- Warn before the authorization runs out (once per resolution, day and admin).
    for settings in
        select * from public.fiscal_settings fs where fs.mode <> 'off'
    loop
        select coalesce(business_timezone, 'America/Bogota') into tz
          from public.parking_settings where lot_id = settings.lot_id;
        tz := coalesce(tz, 'America/Bogota');
        today := (now() at time zone tz)::date;
        for resolution in
            select * from public.fiscal_resolutions r
             where r.lot_id = settings.lot_id and r.active
        loop
            remaining := resolution.range_to - resolution.next_number + 1;
            if remaining < 50 or resolution.valid_to - today <= 30 then
                perform public.fiscal_notify_admins(
                    settings.lot_id,
                    'fiscal_resolution_low',
                    'Resolución de numeración por agotarse',
                    'La resolución ' || resolution.resolution_number
                        || ' de ' || resolution.doc_type
                        || ' tiene ' || greatest(remaining, 0) || ' números.',
                    jsonb_build_object(
                        'resolution_id', resolution.id,
                        'doc_type', resolution.doc_type,
                        'remaining', greatest(remaining, 0),
                        'valid_to', resolution.valid_to
                    ),
                    'fiscal_res:' || resolution.id || ':' || today
                );
            end if;
        end loop;
    end loop;

    return created;
end;
$$;

revoke all on function public.enqueue_pending_fiscal_documents()
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The dispatcher (service role).
-- ---------------------------------------------------------------------------
create or replace function public.claim_fiscal_documents(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    max_rows integer := least(greatest(coalesce(p_limit, 20), 1), 100);
    document public.fiscal_documents%rowtype;
    items jsonb := '[]'::jsonb;
begin
    for document in
        select * from public.fiscal_documents d
         where d.status in ('pending', 'sent')
           and d.next_attempt_at <= now()
           and (d.locked_until is null or d.locked_until < now())
         order by d.id
         limit max_rows
         for update skip locked
    loop
        update public.fiscal_documents
           set locked_until = now() + interval '5 minutes',
               attempts = attempts + 1
         where id = document.id
         returning * into document;

        items := items || jsonb_build_object(
            'id', document.id,
            'status', document.status,
            'provider_document_id', document.provider_document_id,
            'payload', public.fiscal_document_payload(document.id)
        );
    end loop;
    return items;
end;
$$;

revoke all on function public.claim_fiscal_documents(integer)
    from public, anon, authenticated;
grant execute on function public.claim_fiscal_documents(integer) to service_role;

create or replace function public.record_fiscal_result(
    p_document_id bigint,
    p_result jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    document public.fiscal_documents%rowtype;
    outcome text := lower(btrim(coalesce(p_result ->> 'outcome', '')));
    backoff integer[] := array[1, 5, 15, 60, 240, 240, 240];
    wait_minutes integer;
    new_status text;
begin
    select * into document
      from public.fiscal_documents d
     where d.id = p_document_id
     for update;
    if not found then
        raise exception 'FiscalDocumentNotFoundError';
    end if;

    if outcome = 'accepted' then
        new_status := 'accepted';
        update public.fiscal_documents
           set status = 'accepted',
               cufe = coalesce(p_result ->> 'cufe', cufe),
               qr_data = coalesce(p_result ->> 'qr_data', qr_data),
               provider_document_id = coalesce(
                   p_result ->> 'provider_document_id', provider_document_id),
               accepted_at = now(),
               locked_until = null,
               last_error = null,
               rejection_reason = null
         where id = document.id;
        if document.doc_type = 'credit_note'
           and document.related_document_id is not null then
            update public.fiscal_documents
               set voided_at = now()
             where id = document.related_document_id;
        end if;
    elsif outcome = 'rejected' then
        new_status := 'rejected';
        update public.fiscal_documents
           set status = 'rejected',
               rejection_reason = coalesce(p_result ->> 'rejection_reason', 'Rejected'),
               provider_document_id = coalesce(
                   p_result ->> 'provider_document_id', provider_document_id),
               locked_until = null
         where id = document.id;
        perform public.fiscal_notify_admins(
            document.lot_id,
            'fiscal_document_failed',
            'Documento electrónico con problema',
            'El documento ' || document.full_number || ' fue rechazado.',
            jsonb_build_object(
                'document_id', document.id,
                'full_number', document.full_number,
                'status', 'rejected'
            ),
            'fiscal_fail:' || document.id || ':rejected'
        );
    elsif outcome = 'pending' then
        new_status := 'sent';
        update public.fiscal_documents
           set status = 'sent',
               provider_document_id = coalesce(
                   p_result ->> 'provider_document_id', provider_document_id),
               next_attempt_at = now() + interval '1 minute',
               locked_until = null
         where id = document.id;
    elsif outcome = 'transient_error' then
        if document.attempts >= 8 then
            new_status := 'failed';
            update public.fiscal_documents
               set status = 'failed',
                   last_error = left(coalesce(
                       p_result ->> 'error', 'Transient error'), 500),
                   locked_until = null
             where id = document.id;
            perform public.fiscal_notify_admins(
                document.lot_id,
                'fiscal_document_failed',
                'Documento electrónico con problema',
                'El documento ' || document.full_number || ' falló.',
                jsonb_build_object(
                    'document_id', document.id,
                    'full_number', document.full_number,
                    'status', 'failed'
                ),
                'fiscal_fail:' || document.id || ':failed'
            );
        else
            new_status := 'pending';
            wait_minutes := backoff[least(greatest(document.attempts, 1), 7)];
            update public.fiscal_documents
               set status = 'pending',
                   last_error = left(coalesce(
                       p_result ->> 'error', 'Transient error'), 500),
                   next_attempt_at = now() + make_interval(mins => wait_minutes),
                   locked_until = null
             where id = document.id;
        end if;
    else
        raise exception 'InvalidDataError';
    end if;

    return jsonb_build_object('status', new_status);
end;
$$;

revoke all on function public.record_fiscal_result(bigint, jsonb)
    from public, anon, authenticated;
grant execute on function public.record_fiscal_result(bigint, jsonb) to service_role;
