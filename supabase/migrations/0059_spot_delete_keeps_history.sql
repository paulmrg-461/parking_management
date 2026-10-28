-- Removing a bay from the map must not block on old (closed) sessions: the
-- reference is cleared instead, so the visit history survives the layout edit.

alter table public.parking_sessions
    drop constraint if exists parking_sessions_spot_id_fkey;
alter table public.parking_sessions
    add constraint parking_sessions_spot_id_fkey
    foreign key (spot_id) references public.parking_spots(id) on delete set null;
