-- Electronic invoicing — fiscal settings, numbering resolutions and the
-- document outbox. Everything is inert until the lot switches `mode` away from
-- `off`. Every DIAN rule (document types, codes, tax rate, CUFE/CUDE, QR) is an
-- ASSUMPTION pending the owner's and accountant's confirmation; see
-- openspec/changes/add-electronic-invoicing/design.md.
--
--   * `fiscal_settings`: issuer, tax regime, one tax rate (prices are
--     tax-inclusive) and the switch.
--   * `fiscal_resolutions`: authorized range per document type; one active per
--     (lot, type), numbers allocated gap-free under a row lock.
--   * `fiscal_documents`: the outbox and the record. Numbered documents are
--     immutable except for the delivery state and (only while rejected or
--     failed) the customer data.
-- Tax is extracted from the amount already charged: totals always equal what
-- the customer paid.

create table if not exists public.fiscal_settings (
    lot_id             integer primary key references public.parking_lots(id),
    mode               text    not null default 'off'
        check (mode in ('off', 'on_request', 'always')),
    issuer_nit         text,
    issuer_legal_name  text,
    tax_regime         text    not null default 'responsable_iva'
        check (tax_regime in ('responsable_iva', 'no_responsable_iva', 'simple')),
    tax_rate_bps       integer not null default 1900
        check (tax_rate_bps between 0 and 10000),
    municipality_code  text,
    started_at         timestamptz,
    updated_at         timestamptz not null default now(),
    check (mode = 'off' or (issuer_nit is not null and issuer_legal_name is not null
                            and municipality_code is not null))
);

create table if not exists public.fiscal_resolutions (
    id                bigserial primary key,
    lot_id            integer not null references public.parking_lots(id),
    doc_type          text    not null check (doc_type in ('pos', 'invoice', 'credit_note')),
    resolution_number text    not null,
    prefix            text    not null default '' check (prefix ~ '^[A-Za-z0-9]{0,6}$'),
    range_from        bigint  not null check (range_from > 0),
    range_to          bigint  not null,
    next_number       bigint  not null,
    valid_from        date    not null,
    valid_to          date    not null,
    active            boolean not null default true,
    created_at        timestamptz not null default now(),
    check (range_to >= range_from and next_number >= range_from and valid_to >= valid_from)
);
create unique index if not exists uq_fiscal_resolution_active
    on public.fiscal_resolutions(lot_id, doc_type) where active;

create table if not exists public.fiscal_documents (
    id                    bigserial primary key,
    lot_id                integer not null references public.parking_lots(id),
    doc_type              text    not null check (doc_type in ('pos', 'invoice', 'credit_note')),
    resolution_id         bigint  not null references public.fiscal_resolutions(id),
    prefix                text    not null default '',
    number                bigint  not null,
    full_number           text    not null,
    source_kind           text    not null check (source_kind in ('session', 'pass_payment')),
    source_id             bigint  not null,
    related_document_id   bigint  references public.fiscal_documents(id),
    credit_reason         text,
    currency              text    not null default 'COP' check (currency = 'COP'),
    gross_amount          integer not null check (gross_amount >= 0),
    discount_amount       integer not null default 0 check (discount_amount >= 0),
    tax_rate_bps          integer not null check (tax_rate_bps between 0 and 10000),
    tax_base              integer not null check (tax_base >= 0),
    tax_amount            integer not null check (tax_amount >= 0),
    total                 integer not null check (total > 0),
    customer_doc_type     text check (customer_doc_type in ('CC', 'NIT', 'CE', 'PP', 'TI', 'RC', 'TE', 'DIE')),
    customer_doc_number   text,
    customer_name         text,
    customer_email        text,
    status                text    not null default 'pending'
        check (status in ('pending', 'sent', 'accepted', 'rejected', 'failed')),
    attempts              integer not null default 0,
    next_attempt_at       timestamptz not null default now(),
    locked_until          timestamptz,
    last_error            text,
    provider_document_id  text,
    cufe                  text,
    qr_data               text,
    rejection_reason      text,
    issued_at             timestamptz not null default now(),
    accepted_at           timestamptz,
    voided_at             timestamptz,
    created_by            integer references public.users(id),
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now(),
    unique (lot_id, doc_type, prefix, number),
    check ((customer_doc_type is null) = (customer_doc_number is null)),
    check (doc_type <> 'credit_note' or related_document_id is not null)
);
create unique index if not exists uq_fiscal_source_active
    on public.fiscal_documents(source_kind, source_id)
    where doc_type in ('pos', 'invoice') and voided_at is null;
create unique index if not exists uq_fiscal_credit_note_per_document
    on public.fiscal_documents(related_document_id)
    where doc_type = 'credit_note' and status not in ('rejected', 'failed');
create index if not exists ix_fiscal_queue
    on public.fiscal_documents(next_attempt_at) where status in ('pending', 'sent');
create index if not exists ix_fiscal_lot on public.fiscal_documents(lot_id, created_at desc);

alter table public.fiscal_settings enable row level security;
alter table public.fiscal_resolutions enable row level security;
alter table public.fiscal_documents enable row level security;
revoke all on public.fiscal_settings from anon, authenticated;
revoke all on public.fiscal_resolutions from anon, authenticated;
revoke all on public.fiscal_documents from anon, authenticated;
grant select on public.fiscal_settings to authenticated;
grant select on public.fiscal_resolutions to authenticated;
grant select on public.fiscal_documents to authenticated;

drop policy if exists fiscal_settings_admin_read on public.fiscal_settings;
create policy fiscal_settings_admin_read on public.fiscal_settings for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
drop policy if exists fiscal_resolutions_admin_read on public.fiscal_resolutions;
create policy fiscal_resolutions_admin_read on public.fiscal_resolutions for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));
drop policy if exists fiscal_documents_admin_read on public.fiscal_documents;
create policy fiscal_documents_admin_read on public.fiscal_documents for select to authenticated
    using (lot_id = public.current_lot_id() and public.is_lot_admin(lot_id));

-- ---------------------------------------------------------------------------
-- Tax extraction: prices are tax-inclusive, so the tax is derived from the
-- amount already charged and `gross = total + discount`.
-- ---------------------------------------------------------------------------
create or replace function public.fiscal_amounts(
    p_total integer,
    p_discount integer,
    p_rate_bps integer
)
returns jsonb
language sql
immutable
set search_path = public
as $$
    select jsonb_build_object(
        'gross', greatest(coalesce(p_total, 0), 0) + greatest(coalesce(p_discount, 0), 0),
        'discount', greatest(coalesce(p_discount, 0), 0),
        'total', greatest(coalesce(p_total, 0), 0),
        'tax_base', round(
            greatest(coalesce(p_total, 0), 0) * 10000.0
            / (10000 + greatest(coalesce(p_rate_bps, 0), 0))
        )::integer,
        'tax_amount', greatest(coalesce(p_total, 0), 0) - round(
            greatest(coalesce(p_total, 0), 0) * 10000.0
            / (10000 + greatest(coalesce(p_rate_bps, 0), 0))
        )::integer
    );
$$;

revoke all on function public.fiscal_amounts(integer, integer, integer)
    from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- A numbered document never changes its identity or its money.
-- ---------------------------------------------------------------------------
create or replace function public.guard_fiscal_document()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.doc_type is distinct from old.doc_type
       or new.number is distinct from old.number
       or new.prefix is distinct from old.prefix
       or new.full_number is distinct from old.full_number
       or new.lot_id is distinct from old.lot_id
       or new.source_kind is distinct from old.source_kind
       or new.source_id is distinct from old.source_id
       or new.related_document_id is distinct from old.related_document_id
       or new.gross_amount is distinct from old.gross_amount
       or new.discount_amount is distinct from old.discount_amount
       or new.tax_rate_bps is distinct from old.tax_rate_bps
       or new.tax_base is distinct from old.tax_base
       or new.tax_amount is distinct from old.tax_amount
       or new.total is distinct from old.total
       or new.issued_at is distinct from old.issued_at then
        raise exception 'FiscalDocumentImmutableError';
    end if;
    if old.status not in ('rejected', 'failed')
       and (new.customer_doc_type is distinct from old.customer_doc_type
            or new.customer_doc_number is distinct from old.customer_doc_number
            or new.customer_name is distinct from old.customer_name
            or new.customer_email is distinct from old.customer_email) then
        raise exception 'FiscalDocumentImmutableError';
    end if;
    new.updated_at := now();
    return new;
end;
$$;

revoke all on function public.guard_fiscal_document()
    from public, anon, authenticated;

drop trigger if exists trg_fiscal_documents_immutable on public.fiscal_documents;
create trigger trg_fiscal_documents_immutable
    before update on public.fiscal_documents
    for each row execute function public.guard_fiscal_document();
