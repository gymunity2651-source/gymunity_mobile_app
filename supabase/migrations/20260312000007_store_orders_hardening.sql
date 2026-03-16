alter table public.products
  add column if not exists currency text not null default 'USD';

update public.products
set currency = 'USD'
where currency is null or btrim(currency) = '';

update public.orders
set status = 'pending'
where status = 'pending_payment';

update public.orders
set status = 'paid'
where status = 'payment_confirmed';

update public.order_status_history
set status = 'pending'
where status = 'pending_payment';

update public.order_status_history
set status = 'paid'
where status = 'payment_confirmed';

alter table public.orders
  alter column status set default 'pending';

alter table public.orders
  drop constraint if exists orders_status_allowed;

alter table public.orders
  add constraint orders_status_allowed check (
    status in ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled')
  );

alter table public.order_status_history
  drop constraint if exists order_status_history_status_allowed;

alter table public.order_status_history
  add constraint order_status_history_status_allowed check (
    status in ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled')
  );

create table if not exists public.store_carts (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null unique references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.store_cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.store_carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (cart_id, product_id)
);

create table if not exists public.product_favorites (
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (member_id, product_id)
);

create table if not exists public.shipping_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  recipient_name text not null,
  phone text not null,
  line1 text not null,
  line2 text,
  city text not null,
  state_region text not null,
  postal_code text not null,
  country_code text not null,
  delivery_notes text,
  is_default boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (btrim(recipient_name) <> ''),
  check (btrim(phone) <> ''),
  check (btrim(line1) <> ''),
  check (btrim(city) <> ''),
  check (btrim(state_region) <> ''),
  check (btrim(postal_code) <> ''),
  check (btrim(country_code) <> '')
);

create table if not exists public.store_checkout_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  idempotency_key text not null,
  order_ids_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  unique (member_id, idempotency_key),
  check (btrim(idempotency_key) <> '')
);

create unique index if not exists idx_shipping_addresses_default_per_user
  on public.shipping_addresses(user_id)
  where is_default = true;

create index if not exists idx_store_cart_items_cart
  on public.store_cart_items(cart_id, created_at desc);

create index if not exists idx_store_cart_items_product
  on public.store_cart_items(product_id);

create index if not exists idx_product_favorites_member_created
  on public.product_favorites(member_id, created_at desc);

create index if not exists idx_shipping_addresses_user_updated
  on public.shipping_addresses(user_id, is_default desc, updated_at desc);

create index if not exists idx_checkout_requests_member_created
  on public.store_checkout_requests(member_id, created_at desc);

create index if not exists idx_orders_member_status_created
  on public.orders(member_id, status, created_at desc);

create index if not exists idx_orders_seller_status_created
  on public.orders(seller_id, status, created_at desc);

alter table public.store_carts enable row level security;
alter table public.store_cart_items enable row level security;
alter table public.product_favorites enable row level security;
alter table public.shipping_addresses enable row level security;
alter table public.store_checkout_requests enable row level security;

drop policy if exists products_read_active_or_own on public.products;
create policy products_read_active_or_own
on public.products for select
to authenticated
using (
  is_active = true
  or seller_id = auth.uid()
  or exists (
    select 1
    from public.store_carts sc
    join public.store_cart_items sci on sci.cart_id = sc.id
    where sc.member_id = auth.uid()
      and sci.product_id = products.id
  )
  or exists (
    select 1
    from public.product_favorites pf
    where pf.member_id = auth.uid()
      and pf.product_id = products.id
  )
  or exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.product_id = products.id
      and (o.member_id = auth.uid() or o.seller_id = auth.uid())
  )
);

drop policy if exists store_carts_read_own on public.store_carts;
create policy store_carts_read_own
on public.store_carts for select
to authenticated
using (member_id = auth.uid());

drop policy if exists store_carts_insert_own on public.store_carts;
create policy store_carts_insert_own
on public.store_carts for insert
to authenticated
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists store_carts_update_own on public.store_carts;
create policy store_carts_update_own
on public.store_carts for update
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists store_carts_delete_own on public.store_carts;
create policy store_carts_delete_own
on public.store_carts for delete
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists store_cart_items_read_own on public.store_cart_items;
create policy store_cart_items_read_own
on public.store_cart_items for select
to authenticated
using (
  exists (
    select 1
    from public.store_carts sc
    where sc.id = store_cart_items.cart_id
      and sc.member_id = auth.uid()
  )
);

drop policy if exists store_cart_items_manage_own on public.store_cart_items;
create policy store_cart_items_manage_own
on public.store_cart_items for all
to authenticated
using (
  exists (
    select 1
    from public.store_carts sc
    where sc.id = store_cart_items.cart_id
      and sc.member_id = auth.uid()
      and public.current_role() = 'member'
  )
)
with check (
  exists (
    select 1
    from public.store_carts sc
    where sc.id = store_cart_items.cart_id
      and sc.member_id = auth.uid()
      and public.current_role() = 'member'
  )
);

drop policy if exists product_favorites_read_own on public.product_favorites;
create policy product_favorites_read_own
on public.product_favorites for select
to authenticated
using (member_id = auth.uid());

drop policy if exists product_favorites_insert_own on public.product_favorites;
create policy product_favorites_insert_own
on public.product_favorites for insert
to authenticated
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists product_favorites_delete_own on public.product_favorites;
create policy product_favorites_delete_own
on public.product_favorites for delete
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists shipping_addresses_read_own on public.shipping_addresses;
create policy shipping_addresses_read_own
on public.shipping_addresses for select
to authenticated
using (user_id = auth.uid());

drop policy if exists shipping_addresses_manage_own on public.shipping_addresses;
create policy shipping_addresses_manage_own
on public.shipping_addresses for all
to authenticated
using (user_id = auth.uid() and public.current_role() = 'member')
with check (user_id = auth.uid() and public.current_role() = 'member');

drop policy if exists store_checkout_requests_read_own on public.store_checkout_requests;
create policy store_checkout_requests_read_own
on public.store_checkout_requests for select
to authenticated
using (member_id = auth.uid());

drop policy if exists orders_insert_member on public.orders;
drop policy if exists orders_update_owner_side on public.orders;

drop trigger if exists touch_store_carts_updated_at on public.store_carts;
create trigger touch_store_carts_updated_at
before update on public.store_carts
for each row execute function public.touch_updated_at();

drop trigger if exists touch_store_cart_items_updated_at on public.store_cart_items;
create trigger touch_store_cart_items_updated_at
before update on public.store_cart_items
for each row execute function public.touch_updated_at();

drop trigger if exists touch_shipping_addresses_updated_at on public.shipping_addresses;
create trigger touch_shipping_addresses_updated_at
before update on public.shipping_addresses
for each row execute function public.touch_updated_at();

drop function if exists public.create_store_order(jsonb, jsonb);
drop function if exists public.seller_dashboard_summary();

create function public.seller_dashboard_summary()
returns table (
  total_products integer,
  active_products integer,
  low_stock_products integer,
  pending_orders integer,
  in_progress_orders integer,
  delivered_orders integer,
  gross_revenue numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid()), 0)::integer as total_products,
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid() and p.is_active = true and p.deleted_at is null), 0)::integer as active_products,
    coalesce((select count(*) from public.products p where p.seller_id = auth.uid() and p.is_active = true and p.stock_qty <= p.low_stock_threshold and p.deleted_at is null), 0)::integer as low_stock_products,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status = 'pending'), 0)::integer as pending_orders,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status in ('paid', 'processing', 'shipped')), 0)::integer as in_progress_orders,
    coalesce((select count(*) from public.orders o where o.seller_id = auth.uid() and o.status = 'delivered'), 0)::integer as delivered_orders,
    coalesce((select sum(o.total_amount) from public.orders o where o.seller_id = auth.uid() and o.status in ('paid', 'processing', 'shipped', 'delivered')), 0)::numeric as gross_revenue;
$$;

create or replace function public.create_store_order(
  target_shipping_address_id uuid,
  client_idempotency_key text
)
returns table (
  order_id uuid,
  seller_id uuid,
  status text,
  total_amount numeric,
  currency text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  cart_record public.store_carts%rowtype;
  shipping_record public.shipping_addresses%rowtype;
  checkout_record public.store_checkout_requests%rowtype;
  seller_record record;
  item_record record;
  created_order_id uuid;
  created_order_ids uuid[] := '{}'::uuid[];
  expected_stock_rows integer;
  updated_stock_rows integer;
  shipping_snapshot jsonb;
begin
  if requester is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'member' then
    raise exception 'Only members can create store orders.';
  end if;

  if target_shipping_address_id is null then
    raise exception 'Shipping address is required.';
  end if;

  if btrim(coalesce(client_idempotency_key, '')) = '' then
    raise exception 'Checkout request key is required.';
  end if;

  select *
  into shipping_record
  from public.shipping_addresses
  where id = target_shipping_address_id
    and user_id = requester;

  if shipping_record.id is null then
    raise exception 'Shipping address was not found.';
  end if;

  if btrim(coalesce(shipping_record.recipient_name, '')) = ''
      or btrim(coalesce(shipping_record.phone, '')) = ''
      or btrim(coalesce(shipping_record.line1, '')) = ''
      or btrim(coalesce(shipping_record.city, '')) = ''
      or btrim(coalesce(shipping_record.state_region, '')) = ''
      or btrim(coalesce(shipping_record.postal_code, '')) = ''
      or btrim(coalesce(shipping_record.country_code, '')) = '' then
    raise exception 'Shipping address is incomplete.';
  end if;

  select *
  into cart_record
  from public.store_carts
  where member_id = requester;

  if cart_record.id is null then
    raise exception 'Your cart is empty.';
  end if;

  if not exists (
    select 1
    from public.store_cart_items sci
    where sci.cart_id = cart_record.id
  ) then
    raise exception 'Your cart is empty.';
  end if;

  insert into public.store_checkout_requests (
    member_id,
    idempotency_key
  )
  values (
    requester,
    btrim(client_idempotency_key)
  )
  on conflict (member_id, idempotency_key)
  do update set
    member_id = excluded.member_id
  returning * into checkout_record;

  if checkout_record.completed_at is not null
      and jsonb_typeof(checkout_record.order_ids_json) = 'array'
      and jsonb_array_length(checkout_record.order_ids_json) > 0 then
    return query
    select
      o.id,
      o.seller_id,
      o.status,
      o.total_amount,
      o.currency
    from public.orders o
    join jsonb_array_elements_text(checkout_record.order_ids_json) as ids(order_id_text)
      on o.id = ids.order_id_text::uuid
    order by o.created_at asc;
    return;
  end if;

  perform 1
  from public.products p
  join public.store_cart_items sci on sci.product_id = p.id
  where sci.cart_id = cart_record.id
  order by p.id
  for update;

  if exists (
    select 1
    from public.store_cart_items sci
    left join public.products p on p.id = sci.product_id
    where sci.cart_id = cart_record.id
      and (
        sci.quantity <= 0
        or p.id is null
        or p.is_active = false
        or p.deleted_at is not null
        or p.stock_qty < sci.quantity
        or p.currency is null
        or btrim(p.currency) = ''
      )
  ) then
    raise exception 'One or more products are unavailable or out of stock.';
  end if;

  shipping_snapshot := jsonb_build_object(
    'shipping_address_id', shipping_record.id,
    'recipient_name', shipping_record.recipient_name,
    'phone', shipping_record.phone,
    'line1', shipping_record.line1,
    'line2', shipping_record.line2,
    'city', shipping_record.city,
    'state_region', shipping_record.state_region,
    'postal_code', shipping_record.postal_code,
    'country_code', shipping_record.country_code,
    'delivery_notes', shipping_record.delivery_notes
  );

  for seller_record in
    select
      p.seller_id,
      p.currency,
      jsonb_agg(
        jsonb_build_object(
          'product_id', p.id,
          'title', p.title,
          'quantity', sci.quantity,
          'unit_price', p.price,
          'line_total', p.price * sci.quantity
        )
        order by p.created_at desc
      ) as items_json,
      sum(p.price * sci.quantity)::numeric as total_amount
    from public.store_cart_items sci
    join public.products p on p.id = sci.product_id
    where sci.cart_id = cart_record.id
    group by p.seller_id, p.currency
  loop
    insert into public.orders (
      member_id,
      seller_id,
      status,
      total_amount,
      currency,
      payment_method,
      items_json,
      shipping_address_json
    )
    values (
      requester,
      seller_record.seller_id,
      'pending',
      seller_record.total_amount,
      seller_record.currency,
      'manual',
      seller_record.items_json,
      shipping_snapshot
    )
    returning id into created_order_id;

    insert into public.order_status_history (
      order_id,
      status,
      actor_user_id,
      note
    )
    values (
      created_order_id,
      'pending',
      requester,
      'Order created by member.'
    );

    for item_record in
      select
        p.id as product_id,
        p.title,
        p.price,
        sci.quantity,
        (p.price * sci.quantity)::numeric as line_total
      from public.store_cart_items sci
      join public.products p on p.id = sci.product_id
      where sci.cart_id = cart_record.id
        and p.seller_id = seller_record.seller_id
        and p.currency = seller_record.currency
    loop
      insert into public.order_items (
        order_id,
        product_id,
        seller_id,
        product_title_snapshot,
        unit_price,
        quantity,
        line_total
      )
      values (
        created_order_id,
        item_record.product_id,
        seller_record.seller_id,
        item_record.title,
        item_record.price,
        item_record.quantity,
        item_record.line_total
      );
    end loop;

    select count(*)::integer
    into expected_stock_rows
    from (
      select sci.product_id
      from public.store_cart_items sci
      join public.products p on p.id = sci.product_id
      where sci.cart_id = cart_record.id
        and p.seller_id = seller_record.seller_id
        and p.currency = seller_record.currency
      group by sci.product_id
    ) grouped_items;

    update public.products p
    set stock_qty = p.stock_qty - source.quantity,
        updated_at = timezone('utc', now())
    from (
      select
        sci.product_id,
        sum(sci.quantity)::integer as quantity
      from public.store_cart_items sci
      join public.products p2 on p2.id = sci.product_id
      where sci.cart_id = cart_record.id
        and p2.seller_id = seller_record.seller_id
        and p2.currency = seller_record.currency
      group by sci.product_id
    ) as source
    where p.id = source.product_id
      and p.stock_qty >= source.quantity;

    get diagnostics updated_stock_rows = row_count;

    if updated_stock_rows <> expected_stock_rows then
      raise exception 'One or more products are unavailable or out of stock.';
    end if;

    insert into public.notifications (
      user_id,
      type,
      title,
      body,
      data
    )
    values (
      seller_record.seller_id,
      'orders',
      'New order request',
      'A new order was placed and is awaiting payment confirmation.',
      jsonb_build_object('order_id', created_order_id, 'status', 'pending')
    );

    insert into public.notifications (
      user_id,
      type,
      title,
      body,
      data
    )
    values (
      requester,
      'orders',
      'Order submitted',
      'Your order was created and is awaiting manual payment confirmation.',
      jsonb_build_object('order_id', created_order_id, 'status', 'pending')
    );

    created_order_ids := array_append(created_order_ids, created_order_id);
  end loop;

  if array_length(created_order_ids, 1) is null then
    raise exception 'Your cart is empty.';
  end if;

  delete from public.store_cart_items
  where cart_id = cart_record.id;

  update public.store_checkout_requests
  set order_ids_json = to_jsonb(created_order_ids),
      completed_at = timezone('utc', now())
  where id = checkout_record.id;

  return query
  select
    o.id,
    o.seller_id,
    o.status,
    o.total_amount,
    o.currency
  from public.orders o
  where o.id = any(created_order_ids)
  order by o.created_at asc;
end;
$$;

create or replace function public.update_store_order_status(
  target_order_id uuid,
  new_status text,
  note text default null
)
returns table (
  order_id uuid,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_order public.orders%rowtype;
  allowed boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if public.current_role() <> 'seller' then
    raise exception 'Only sellers can update order status.';
  end if;

  if new_status not in ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled') then
    raise exception 'The requested status transition is not allowed.';
  end if;

  select *
  into existing_order
  from public.orders
  where id = target_order_id
    and seller_id = auth.uid();

  if existing_order.id is null then
    raise exception 'Order not found for this seller.';
  end if;

  allowed := (
    (existing_order.status = 'pending' and new_status in ('paid', 'cancelled'))
    or (existing_order.status = 'paid' and new_status in ('processing', 'cancelled'))
    or (existing_order.status = 'processing' and new_status in ('shipped', 'cancelled'))
    or (existing_order.status = 'shipped' and new_status = 'delivered')
  );

  if not allowed then
    raise exception 'The requested status transition is not allowed.';
  end if;

  if new_status = 'cancelled' then
    update public.products p
    set stock_qty = p.stock_qty + oi.quantity,
        updated_at = timezone('utc', now())
    from public.order_items oi
    where oi.order_id = existing_order.id
      and p.id = oi.product_id;
  end if;

  update public.orders
  set status = new_status,
      updated_at = timezone('utc', now())
  where id = existing_order.id;

  insert into public.order_status_history (
    order_id,
    status,
    actor_user_id,
    note
  )
  values (
    existing_order.id,
    new_status,
    auth.uid(),
    coalesce(note, 'Order status updated by seller.')
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    data
  )
  values (
    existing_order.member_id,
    'orders',
    'Order status updated',
    'Your order is now ' || replace(new_status, '_', ' ') || '.',
    jsonb_build_object('order_id', existing_order.id, 'status', new_status)
  );

  order_id := existing_order.id;
  status := new_status;
  return next;
end;
$$;

revoke all on function public.create_store_order(uuid, text) from public;
revoke all on function public.create_store_order(uuid, text) from anon;
grant execute on function public.create_store_order(uuid, text) to authenticated;

revoke all on function public.seller_dashboard_summary() from public;
grant execute on function public.seller_dashboard_summary() to authenticated;

grant execute on function public.update_store_order_status(uuid, text, text) to authenticated;
