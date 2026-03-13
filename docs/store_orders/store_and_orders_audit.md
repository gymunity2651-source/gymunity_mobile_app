# Store And Orders Audit

## Scope
This audit covers the store, cart, favorites, checkout, orders, and seller order-management flows that existed before the productionization work completed in this repository.

## Current production truth
- Product catalog is backend-driven from `products`.
- Product images are resolved from `products.image_paths` through the `product-images` bucket.
- Cart is persisted in `store_carts` and `store_cart_items`.
- Favorites are persisted in `product_favorites`.
- Shipping addresses are persisted in `shipping_addresses`.
- Checkout is server-trusted through `public.create_store_order(uuid, text)`.
- Orders are normalized through `orders` plus `order_items`.
- Seller order updates are gated by `public.update_store_order_status(...)`.

## Issues found and fixed

| Issue | Severity | Impacted role | Exact files involved | Frontend impact | Backend / data-model impact | Security / consistency impact | Recommended fix | Fully fixed in repo |
|---|---|---|---|---|---|---|---|---|
| Cart was local-only Riverpod state | Critical | Member | `lib/features/store/presentation/providers/store_providers.dart`, `lib/features/store/presentation/screens/cart_screen.dart`, old store repository implementation | Cart was lost on relaunch and across devices | No durable source of truth | Client-only state could diverge from backend stock and pricing | Move cart to `store_carts` and `store_cart_items` and load through repository-backed async notifiers | Yes |
| Favorites / wishlist was local-only | High | Member | `lib/features/store/presentation/providers/store_providers.dart`, store screens, old store repository implementation | Favorite state was not persistent or truthful | No backend ownership model | Favorite state diverged across sessions | Add `product_favorites` and repository-backed favorite toggles | Yes |
| Checkout was a preview-only flow | Critical | Member | `lib/features/store/presentation/screens/checkout_preview_screen.dart`, old store repository implementation | Checkout looked real but did not behave like a trusted order pipeline | Client drove order creation inputs and order summary | Risk of fake success and inconsistent orders | Replace with persisted address selection plus trusted backend checkout RPC | Yes |
| Orders still relied on client cart JSON and `items_json` during creation | Critical | Member, Seller | old `public.create_store_order(jsonb, jsonb)`, `supabase/sql/phase1_dashboard_setup.sql`, store repository | Order detail truth was weak and tied to client payloads | `order_items` existed but was not the only authoritative source | Historical integrity and fulfillment correctness were weaker than required | Make `order_items` authoritative and create them on the server from persisted cart rows | Yes |
| Stock validation happened before decrement without row locking | Critical | Member, Seller | old checkout RPC in SQL | Users could see successful checkout attempts that should fail under concurrency | Backend was vulnerable to race conditions | Overselling was possible under concurrent checkout | Lock product rows with `FOR UPDATE`, validate and decrement in one trusted transaction path | Yes |
| Seller dashboard metrics were partly placeholder / misnamed for old statuses | High | Seller | `lib/features/seller/presentation/screens/seller_dashboard_screen.dart`, old seller repository, SQL summary function | Dashboard counts were not aligned with final order lifecycle | Metrics still referenced `pending_payment` semantics | Seller decisions could rely on wrong numbers | Rebuild summary RPC and screen on `pending|paid|processing|shipped|delivered|cancelled` | Yes |
| Seller Orders route was placeholder-level | High | Seller | `lib/app/routes.dart`, seller screens, seller repository | Seller could not manage real fulfillment from the app | No normalized detailed order read path in UI | Seller order control surface was incomplete | Add real seller orders list, details, and status updates | Yes |
| My Orders was not a real normalized order history | High | Member | `lib/app/routes.dart`, store screens, store repository | Buyer order history was incomplete or fake | Order details were not enriched with line items and status history | Members could not verify real order state | Add member order list and detail flow backed by `orders`, `order_items`, and `order_status_history` | Yes |
| Shipping addresses were missing as a persistent model | Critical | Member | checkout UI, store repository, SQL | Checkout could not require a durable valid address | No address table or selection model | Orders risked incomplete shipping snapshots | Add `shipping_addresses`, validation, default selection, and snapshotting during checkout | Yes |
| Product read policy hid inactive products even when needed for cart / favorites / order history | Medium | Member, Seller | `products_read_active_or_own` policy in SQL | Invalid cart or favorite items could disappear instead of rendering actionable states | Product access was too narrow for archived-but-owned-by-user commerce contexts | Users could not reliably inspect unavailable items already tied to their account | Broaden product select policy for cart, favorite, and order-linked products | Yes |
| Direct `orders` update paths bypassed lifecycle rules | High | Seller, Member | old order policies from base schema | UI could not rely on one trusted state machine | Order transition rules were bypassable | Invalid status transitions were possible through direct table writes | Drop broad direct-update policy and route state changes through RPC only | Yes |
| Product images were not explicitly optimized before upload in seller flows | Medium | Seller | `lib/features/seller/data/repositories/seller_repository_impl.dart` | Large uploads could hurt mobile UX | Storage objects could be larger than needed | Not a direct security risk, but wasteful and brittle | Resize/compress client-side before upload and render safe fallbacks | Yes |

## Existing models and screens audited
- Product entity and catalog:
  - `lib/features/store/domain/entities/product_entity.dart`
  - `lib/features/store/presentation/screens/store_home_screen.dart`
  - `lib/features/store/presentation/screens/store_catalog_screen.dart`
  - `lib/features/store/presentation/screens/product_details_screen.dart`
- Cart:
  - `lib/features/store/domain/entities/cart_entity.dart`
  - `lib/features/store/presentation/screens/cart_screen.dart`
  - `lib/features/store/presentation/providers/store_providers.dart`
- Favorites:
  - `lib/features/store/presentation/screens/favorites_screen.dart`
  - `lib/features/store/presentation/providers/store_providers.dart`
- Checkout:
  - `lib/features/store/presentation/screens/checkout_preview_screen.dart`
  - `lib/features/store/data/repositories/store_repository_impl.dart`
- Orders:
  - `lib/features/store/domain/entities/order_entity.dart`
  - `lib/features/store/presentation/screens/my_orders_screen.dart`
  - `lib/features/store/presentation/screens/order_details_screen.dart`
- Seller order management:
  - `lib/features/seller/presentation/screens/seller_dashboard_screen.dart`
  - `lib/features/seller/presentation/screens/seller_orders_screen.dart`
  - `lib/features/seller/data/repositories/seller_repository_impl.dart`

## Existing backend assets audited
- `supabase/migrations/20260307_000001_init_gymunity.sql`
- `supabase/migrations/20260312_000006_core_role_flows.sql`
- `supabase/migrations/20260312_000007_store_orders_hardening.sql`
- `supabase/sql/phase1_dashboard_setup.sql`

## Missing pieces identified before implementation
- Persisted cart
- Persisted favorites
- Persisted shipping addresses
- Server-trusted checkout using backend cart state
- Anti-oversell protection
- Real member order history
- Real seller order management
- Finalized status lifecycle
- Correct seller metrics
- Tests that reflected the hardened auth/config boot flow and the new commerce API surfaces

## Result
All store/order issues listed above were fully fixed inside the repository, except external concerns documented in `open_items_and_manual_steps.md`, mainly payment-provider integration and environment/storage setup verification.
