# Coach and Client Relationship Map

This document describes how the coach and client move through the coaching product together. It covers the visible UI actions, the main buttons, the backend objects that change, the states that can happen, and the expected edge cases.

Source of truth used for this map: Flutter screens, route definitions, repositories, and local Supabase migrations in this project. Remote Supabase access was not needed because the local schema and RPC definitions already describe the relationship.

## 1. Relationship Summary

The coach-client relationship starts before the two people ever message each other. A coach first creates a public coaching supply: profile, offers, starter plan preview, availability, program templates, resources, and optional onboarding flows. A client discovers that public supply in the marketplace, compares coach details and offers, starts paid checkout, submits payment proof when manual payment is required, and waits for coach verification.

The relationship becomes operational when the subscription becomes active. At that point the app can create or reuse one `coach_member_threads` row for the subscription. That thread becomes the shared messaging space. Weekly check-ins, coach feedback, programs, habits, resources, bookings, billing events, and privacy visibility all attach back to the same subscription.

The most important rule is that the subscription is the relationship anchor:

- One coach and one client are connected through a `subscriptions` row.
- One active coaching relationship usually has one `coach_member_threads` row.
- Check-ins, messages, bookings, resources, payment receipts, CRM notes, and privacy settings all reference the subscription.
- Coach-only management data, such as private notes and pipeline tags, belongs to the coach.
- Client-owned personal data is private by default and only becomes visible to the coach when the client enables specific visibility toggles.

## 2. Main Data Objects

| Object | Created or edited by | Visible to | What it represents |
| --- | --- | --- | --- |
| `coach_profiles` | Coach | Public marketplace, coach | Coach identity, bio, specialties, delivery mode, pricing, language, location, trial settings. |
| `coach_packages` | Coach | Public only when published | The paid offer the client can buy. Includes price, billing cycle, promise, included features, FAQ, starter plan preview, and visibility status. |
| `coach_availability_slots` | Coach | Public details and coach calendar | Weekly availability windows by weekday, start time, end time, and timezone. |
| `subscriptions` | Client checkout or coach activation flow | Coach and client | The actual coach-client commercial relationship. Holds status, checkout status, amount, billing cycle, activation dates, renewal date, notes, and intake snapshot. |
| `coach_checkout_requests` | Checkout RPC | Coach and client through subscription context | Payment request metadata for a coaching offer. |
| `coach_payment_receipts` | Client submits proof, coach reviews | Coach and client | Manual payment proof, receipt storage path, amount, status, payment reference, review result, failure reason. |
| `coach_payment_audit_events` | Payment RPCs | Coach and client | Billing history for manual verification and follow-up. |
| `coach_member_threads` | Activation, check-in, or onboarding flow | Coach and client | One shared conversation thread per subscription. |
| `coach_messages` | Coach, client, or system | Coach and client | Text, system message, check-in prompt, or check-in feedback inside the thread. |
| `weekly_checkins` | Client submits, coach replies | Coach and client | Weekly progress check-in with weight, waist, adherence, energy, sleep, wins, blockers, questions, and coach reply. |
| `progress_photos` | Client check-in upload | Coach and client if tied to check-in access | Optional check-in photos by angle and storage path. |
| `coach_client_records` | Coach | Coach only | CRM stage, risk status, internal status, tags, private coach note, preferred language, follow-up date. |
| `coach_client_notes` | Coach | Coach only | Private notes about the client relationship. |
| `coach_automation_events` | System or coach dismissal | Coach | Action items such as pending payment, renewal soon, no recent check-in, unread message, or inactive client. |
| `coach_program_templates` | Coach | Coach, assigned client through generated plan | Reusable program template with weeks, difficulty, goal, location, tags, and weekly structure. |
| `workout_plans`, `workout_plan_days`, `workout_plan_tasks` | Coach assignment | Client and coach if consented | The actual assigned plan generated from an offer preview or program template. |
| `coach_exercise_library` | Coach | Coach | Exercise library used to build program templates. |
| `member_habit_assignments` | Coach | Client and coach | Assigned habits with target, unit, frequency, and start date. |
| `coach_resources` | Coach | Coach, assigned clients | Files or links uploaded by coach. |
| `coach_resource_assignments` | Coach | Coach and assigned client | Resource shared with a specific subscription. |
| `coach_onboarding_templates` | Coach | Coach | Reusable onboarding flow with welcome message, starter program, habits, nutrition tasks, and resources. |
| `coach_onboarding_applications` | Coach | Coach and client through resulting effects | Record that a flow was applied to a subscription. |
| `coach_session_types` | Coach | Coach calendar, booking flow | Session definition such as consultation, weekly call, video coaching, or in-person training. |
| `coach_bookings` | Coach | Coach and client context | Scheduled session between coach and client with status and note. |
| `coach_member_visibility_settings` | Client | Client, coach read-only for active subscription | Consent switches for what aggregated data the coach can see. |
| `coach_member_visibility_audit` | Visibility RPC | Client | Audit history of consent grants, updates, and revocations. |

## 3. Lifecycle From First Setup To Ongoing Coaching

### 3.1 Coach prepares the offer

1. Coach completes onboarding or opens coach profile.
2. Coach saves identity and expertise data.
3. Coach creates at least one package or offer.
4. Coach publishes the offer.
5. Coach optionally creates availability slots, session types, program templates, resources, and onboarding flows.
6. Published coach profile and published packages become discoverable by clients.

Backend movement:

- `upsertCoachProfile` writes `coach_profiles` and marks the coach profile as onboarding-completed.
- `saveCoachPackage` writes `coach_packages`.
- `saveAvailabilitySlot` writes `coach_availability_slots`.
- Program, session, resource, and onboarding screens call their coach RPCs and store reusable coach assets.

### 3.2 Client discovers a coach

1. Client opens the Coach Marketplace.
2. Client searches by coach name, specialty, or city.
3. Client uses filters for specialty, city, language, budget, and coach gender.
4. Client opens the coach details page.
5. Client reviews bio, service model, proof, offer preview, availability, reviews, and packages.
6. Client opens full offers.

Backend movement:

- Marketplace loads public coach directory RPCs.
- Coach details load public profile, packages, availability, and reviews.
- Only published and active offers should be shown for purchase.

### 3.3 Client starts checkout

1. Client selects `Start paid checkout` on an offer.
2. Checkout dialog collects goal, experience, days per week, session minutes, budget, city, equipment, limitations, optional note, and payment rail.
3. Client taps `Submit request`.
4. App calls `create_coach_checkout`.
5. A `subscriptions` row is created with `status = checkout_pending` and `checkout_status = checkout_pending`.
6. A `coach_checkout_requests` row is created.
7. Coach receives a notification that a paid checkout started.
8. Client receives a notification to complete payment.

Important validation:

- Only members can start checkout.
- Package must be published.
- Payment rail must be one of `card`, `instapay`, `wallet`, or `manual_fallback`.
- The selected payment rail must be allowed by the offer unless it is `manual_fallback`.
- A member cannot create a duplicate open relationship for the same offer when an existing relationship is checkout pending, pending payment, pending activation, active, or paused.

### 3.4 Client submits manual payment proof

1. Client opens `My Coaching`.
2. If the subscription is waiting for payment, the card shows `Submit payment proof`.
3. Client enters a payment reference.
4. Client optionally uploads a receipt file.
5. Client taps `Submit for verification`.
6. The file is uploaded to the `coach-payment-receipts` bucket when present.
7. App calls `submit_coach_payment_receipt`.
8. Receipt status becomes `submitted` when there is only a reference, or `receipt_uploaded` when a file path exists.
9. Subscription `checkout_status` is updated to match the receipt state.
10. Coach receives a payment-proof notification.

Backend movement:

- `coach_payment_receipts` receives the proof.
- `coach_payment_audit_events` records the state movement.
- `subscriptions.payment_reference` and `coach_checkout_requests.payment_reference` can be updated.

### 3.5 Coach reviews payment

The coach opens Billing from the coach shell, dashboard metric cards, or a client workspace billing tab.

Coach can:

- Tap `Details` to inspect member, package, billing state, receipt status, amount, reference, receipt path, failure reason, and audit trail.
- Tap `Approve` to verify the payment.
- Tap the follow-up icon labeled `Needs follow-up` to enter a reason and mark payment as failed.

Approve movement:

1. App calls `verify_coach_payment`.
2. Receipt status becomes `activated`.
3. Subscription becomes `status = active` and `checkout_status = paid`.
4. Start, end, activation, and renewal dates are calculated from the billing cycle.
5. `ensure_coach_member_thread` creates the shared thread if missing.
6. Client receives a payment verified notification.
7. Coach dashboard, billing queue, pipeline, and client workspace refresh.

Needs-follow-up movement:

1. Coach enters reason.
2. App calls `fail_coach_payment`.
3. Receipt status becomes `failed`.
4. Subscription checkout status becomes `failed` if it was still waiting.
5. Checkout request status becomes `failed`.
6. Audit event records the failure reason.
7. Client receives a notification with the follow-up reason.

### 3.6 Relationship becomes active

Once active, both sides can use the shared relationship:

- Client can message the coach.
- Coach can message the client.
- Client can submit weekly check-ins.
- Coach can review check-ins and send structured feedback.
- Coach can assign program templates, habits, resources, onboarding flows, and sessions.
- Client can pause or resume when the offer allows pausing.
- Client can control privacy visibility.
- Coach can manage pipeline stage, risk, internal status, tags, follow-up date, and private notes.

## 4. Coach Onboarding Inputs

Coach onboarding exists to make the coach useful to members immediately after signup. It gathers just enough information to publish a credible profile, create a starter offer, and define initial availability.

### Step 1: Specialty

Visible choices:

- `Strength`
- `Yoga`
- `Cardio`
- `Nutrition`

Saved as:

- `coach_profiles.specialties`

Purpose:

- Drives marketplace filtering.
- Helps the client understand the coach's focus before opening details.
- Helps starter package text and positioning feel aligned with the coach.

### Step 2: Profile

Inputs:

- Years of experience.
- Hourly rate.
- Bio.
- Service summary.
- Delivery mode.

Saved as:

- `coach_profiles.years_experience`
- `coach_profiles.hourly_rate`
- `coach_profiles.bio`
- `coach_profiles.service_summary`
- `coach_profiles.delivery_mode`

Purpose:

- Builds public trust.
- Gives the marketplace card and coach details page enough content.
- Helps clients decide whether to start checkout.

### Step 3: Starter Package

Coach enters:

- Delivery mode.
- Package title.
- Description.
- Price.
- Billing cycle.

System generates or normalizes:

- Subtitle.
- Outcome summary.
- Ideal client.
- Duration weeks.
- Sessions per week.
- Difficulty.
- Included features.
- Check-in frequency.
- Support summary.
- Plan preview JSON.
- Visibility status.
- Active flag.

Saved as:

- `coach_packages`

Purpose:

- Gives the client a real offer to buy.
- Gives the coach an immediately usable product.
- Supplies starter plan preview data that can later become assigned workout plan days and tasks.

### Step 4: Availability

Inputs:

- Weekday.
- Start time.
- End time.
- Timezone, currently stored as UTC by the onboarding flow.

Saved as:

- `coach_availability_slots`

Purpose:

- Lets clients see when the coach is generally available.
- Lets the coach calendar start with usable time windows.

### Onboarding submit behavior

When the coach submits onboarding:

1. `completeCoachOnboarding` validates all steps.
2. Coach profile is upserted.
3. Starter package is created.
4. Availability slot is created.
5. Profile providers are invalidated.
6. Coach is routed to the coach dashboard.

## 5. Coach-Side Screens, Buttons, And Effects

### 5.1 Coach Workspace Shell

Main navigation:

| Control | Visible label | Effect |
| --- | --- | --- |
| Bottom tab 1 | `Today` | Opens dashboard summary, metrics, action items, schedule, and package performance. |
| Bottom tab 2 | `Clients` | Opens client pipeline. |
| Bottom tab 3 | `Check-ins` | Opens check-in inbox. |
| Bottom tab 4 | `Calendar` | Opens coach calendar. |
| Bottom tab 5 | `Library` | Opens program library. |
| App bar menu | `Profile` | Opens coach profile editor. |
| App bar menu | `Packages` | Opens coaching offers. |
| App bar menu | `Billing` | Opens payment verification queue. |
| App bar menu | `Resources` | Opens resources manager. |
| App bar menu | `Onboarding` | Opens onboarding flows. |
| App bar menu | `Settings` | Opens settings. |

Dashboard cards:

- `Create Package` opens package editor.
- `Open Clients` opens pipeline.
- Metric card `Schedule` opens calendar.
- Metric card `Leads` opens clients.
- Metric card `Payments` opens billing.
- Metric card `Active` opens clients.
- Metric card `At risk` opens clients.
- Metric card `Overdue` opens check-ins.
- Metric card `Unread` opens clients.
- Metric card `Renewals` opens clients.
- Metric card `Revenue` opens billing.
- `Open billing` opens billing from package performance.
- `Open calendar` opens calendar from schedule.
- `Schedule call` opens calendar when schedule is empty.
- Coach alert CTA opens the target area depending on alert type.
- Alert dismiss icon calls `dismiss_coach_action_item`.

### 5.2 Client Pipeline

Purpose: coach CRM for every lead, pending payment, active client, at-risk client, paused client, or archived relationship.

Controls:

| Control | Effect |
| --- | --- |
| Search field `Search client, package, goal` | Filters pipeline by member, package, or goal. |
| Filter icon | Opens advanced filters sheet. |
| Stage chips `All`, `Leads`, `Payment`, `Active`, `At risk`, `Paused`, `Archived` | Filters pipeline stage. |
| Sort dropdown `Risk`, `Start`, `Renewal` | Changes pipeline ordering. |
| `Clear` in filter sheet | Removes filters. |
| `Apply` in filter sheet | Applies goal, package, city, language, date, gender, risk, and renewal filters. |
| Client card `Assign starter plan` | Calls `activateSubscriptionWithStarterPlan` when relationship is pending payment or pending activation and the offer has a starter plan preview. |
| CRM icon | Opens CRM sheet. |
| `Open client` | Opens coach client workspace. |
| `Review payment` icon | Opens billing. |
| `Schedule call` icon | Opens calendar. |

CRM sheet fields:

- Pipeline stage: `lead`, `pending_payment`, `active`, `at_risk`, `paused`, `archived`.
- Preferred language.
- Risk: `none`, `at_risk`, `critical`.
- Internal status: `active`, `new`, `follow_up`, `engaged`, `watchlist`, `renewal_watch`.
- Tags.
- Coach notes.
- Follow-up date.
- `Save CRM updates` calls `upsert_coach_client_record`.

Relationship effect:

- CRM changes do not change what the client sees.
- CRM changes influence how the coach organizes work.
- Risk, tags, notes, and follow-up dates can surface operational priority.

### 5.3 Coach Client Workspace

The workspace is the main operational view for one subscription.

Tabs:

1. `Overview`
2. `Plan`
3. `Check-ins`
4. `Progress`
5. `Nutrition`
6. `Messages`
7. `Notes`
8. `Files`
9. `Billing`
10. `Privacy`

Overview actions:

| Control | Effect |
| --- | --- |
| `Message` | Opens message sheet when a thread exists. Disabled if no thread exists. |
| `Schedule` | Opens schedule session sheet. |
| Quick action `Message client` | Opens message sheet. |
| Quick action `Schedule session` | Opens schedule session sheet. |
| Quick action `Assign program` | Opens program assignment sheet. |
| Quick action `Review payment` | Moves to billing tab. |
| Quick action `Assign resource` | Opens resource assignment sheet. |
| Quick action `Review consent` | Moves to privacy tab. |

Plan tab:

| Control | Effect |
| --- | --- |
| `Open library` | Opens program library. |
| `Assign habits` | Opens habit assignment sheet. |
| `Assign resources` | Opens resource assignment sheet. |
| Program template `Assign` | Calls `assign_program_template_to_client`. |

Habit assignment sheet:

- Habit title, default `Daily steps`.
- Target, default `8000`.
- Unit, default `steps`.
- Frequency: daily or weekly.
- `Assign habit` calls `assign_client_habits`.

Check-ins tab:

- Shows weekly check-ins for the subscription.
- Each check-in has `Review`.
- Review sheet shows week, adherence, energy, sleep, wins, blockers, questions, and photos.
- Coach enters `Coach feedback`.
- `Send feedback` calls `submit_coach_checkin_feedback`.
- Backend writes `weekly_checkins.coach_reply`.
- Backend also inserts a `coach_messages` row with `message_type = checkin_feedback`.
- Client receives a notification.

Progress tab:

- Locked unless the client shares progress metrics or workout adherence.
- Shows consented progress or adherence summaries only.

Nutrition tab:

- Locked unless the client shares nutrition summary.
- Shows consented nutrition targets and adherence only.

Messages tab:

- Shows existing threads.
- `Send` opens or uses the message sheet.
- Coach message insert uses `sender_role = coach`.
- Direct inserts are protected so the coach can only send as coach in threads they own.

Notes tab:

- `Private coach note` field stores private coach-only context.
- `Save note` calls `add_coach_client_note`.
- Client does not see these notes.

Files tab:

- `Assign resource` opens resource assignment.
- Empty state `Resources` opens the resources manager.
- Assigned resources are tied to the subscription.

Billing tab:

- Shows payment receipts and audit trail for the subscription.
- `Open queue` opens billing verification.

Privacy tab:

- Shows whether each client data category is shared or locked.
- Categories include workout, progress, nutrition, AI plan, product recommendations, and relevant purchases depending on visibility settings.
- Coach cannot change these toggles.

Schedule session sheet:

- Client is read-only.
- Coach selects session type.
- Coach enters start datetime as `YYYY-MM-DD HH:MM`.
- Coach can add session note.
- `Create booking` calls `create_coach_booking`.
- If no session types exist, `Open calendar` takes the coach to create one.

Message sheet:

- Shows message history.
- Coach types into `Message`.
- `Send` inserts `coach_messages`.
- Workspace and pipeline providers refresh after send.

Resource assignment sheet:

- Lists active coach resources.
- Each resource has `Assign`.
- Assigning calls `assign_resource_to_client`.
- Client receives a notification about the new resource.

### 5.4 Check-in Inbox

Purpose: review all recent client check-ins in one place.

Controls:

| Control | Effect |
| --- | --- |
| `Review check-in` | Opens structured feedback sheet. Disabled if there is no thread. |
| Feedback field `Coach response` | Coach writes reply. |
| `Send feedback` | Calls `submit_coach_checkin_feedback`, updates check-in, posts message, notifies client. |

Displayed information:

- Week.
- Adherence out of 100.
- Wins.
- Blockers.
- Questions.

### 5.5 Calendar

Purpose: manage session types, availability, and booked sessions.

Session type controls:

| Control | Effect |
| --- | --- |
| Plus icon or `Add type` | Opens session type sheet. |
| `Add session type` | Opens session type sheet. |
| `Save` | Calls `save_coach_session_type`. |

Session type fields:

- Title.
- Type: `consultation`, `weekly_checkin_call`, `video_coaching_session`, `in_person_training_session`.
- Minutes.
- Mode: `online`, `in_person`, `hybrid`.
- Location note or meeting note.
- Buffer before.
- Buffer after.
- Cancellation notice hours.
- Reschedule notice.
- `Allow self-booking` switch.

Availability controls:

| Control | Effect |
| --- | --- |
| `Slot` or `Add slot` | Opens availability slot sheet. |
| Day dropdown | Selects Sunday through Saturday. |
| Start time and end time | Defines availability window. |
| `Save` | Calls `saveAvailabilitySlot`. |

Booking controls:

| Control | Effect |
| --- | --- |
| `Book` | Opens create booking sheet. |
| `Create booking` | Calls `create_coach_booking`. Requires active client and session type. |
| Booking card `Update status` | Opens status sheet. |
| Status sheet `Save` | Calls `update_coach_booking_status`. |

Booking statuses:

- `scheduled`
- `completed`
- `cancelled`
- `rescheduled`

The backend session table can also support additional status values, but the current coach UI exposes the above status choices.

### 5.6 Billing

Purpose: coach verifies manual coaching payments.

Billing queue states shown:

- `awaiting_payment`
- `payment_submitted`
- `receipt_uploaded`
- `under_verification`
- `activated`
- `failed_needs_follow_up`

Controls:

| Control | Effect |
| --- | --- |
| `Details` | Opens payment details and audit trail. |
| `Approve` | Calls `verify_coach_payment`. Activates subscription and creates thread if missing. |
| Follow-up icon `Needs follow-up` | Opens failure reason sheet. |
| `Mark needs follow-up` | Calls `fail_coach_payment`. Marks receipt failed and notifies client. |

### 5.7 Program Library

Purpose: create reusable program templates and exercise library entries.

Program template controls:

| Control | Effect |
| --- | --- |
| Plus icon or `Create template` | Opens template sheet. |
| `Save` | Calls `save_coach_program_template`. |

Template fields:

- Title.
- Description.
- Goal: `fat_loss`, `muscle_gain`, `beginner`, `general_fitness`, `home_training`, `women_coaching`, `ramadan_lifestyle`.
- Weeks.
- Difficulty.
- Location: `online`, `home`, `gym`, `hybrid`.
- Tags.

Exercise controls:

| Control | Effect |
| --- | --- |
| `Exercise` or `Add exercise` | Opens exercise sheet. |
| `Save` | Calls `save_coach_exercise`. |

Exercise fields:

- Title.
- Coach instructions.
- Category: `strength`, `cardio`, `mobility`.
- Difficulty: `beginner`, `intermediate`, `advanced`.
- Primary muscles.
- Equipment tags.
- Progression rule.
- Regression or substitution.
- Video URL.
- Rest seconds.

### 5.8 Onboarding Flows

Purpose: let a coach apply a repeatable start package to a client.

Controls:

| Control | Effect |
| --- | --- |
| Plus icon or `Create flow` | Opens flow creation sheet. |
| Flow tile `Apply` | Opens active subscription selection sheet. |
| Subscription `Apply` | Calls `apply_coach_onboarding_flow`. |

Flow fields:

- Title.
- Description.
- Client type: `general`, `fat_loss`, `muscle_gain`, `beginner`, `hybrid coaching`.
- Welcome message.
- Starter program dropdown.
- Habits.
- Nutrition tasks.
- Resource checkbox list.

Applying a flow can:

- Ensure a thread exists.
- Insert the welcome message as a coach message.
- Assign a starter program template.
- Assign habits.
- Assign resources.
- Upsert the CRM record to active or pending payment depending on subscription status.
- Store an application result record.

### 5.9 Resources

Purpose: coach manages files and links that can be shared with clients.

Controls:

| Control | Effect |
| --- | --- |
| Upload action or `Upload` | Opens file picker for pdf, mp4, mov, jpg, or png. |
| Create link action | Opens link resource sheet. |
| Link sheet `Save link` | Calls `save_coach_resource` with external URL. |
| Resource tile `Assign` | Opens subscription list. |
| Subscription `Assign` | Calls `assign_resource_to_client`. |

Storage:

- Files go to the private `coach-resources` bucket.
- Coach can manage own resources.
- Assigned client can read assigned resource objects through RLS.

### 5.10 Packages

Purpose: coach creates and manages commercial offers.

Controls:

| Control | Effect |
| --- | --- |
| FAB `New offer` | Opens package editor. |
| `Preview public storefront` | Opens public coach details preview when profile exists. |
| Status chips `Published`, `Draft`, `Archived` | Filter offer list by visibility status. |
| Offer popup `Move to Published` | Saves offer as published. |
| Offer popup `Move to Draft` | Saves offer as draft. |
| Offer popup `Archive` | Archives offer. If linked subscriptions exist, it is made inactive instead of hard-deleted. |
| `Edit` | Opens package editor. |
| `Preview` | Opens public preview for published offer. |

Package editor fields:

- Offer title.
- Subtitle.
- Price.
- Billing cycle.
- Description.
- Outcome summary.
- Ideal for.
- Check-in frequency.
- Difficulty.
- Support summary.
- Duration weeks.
- Sessions per week.
- Equipment tags.
- Included features.
- FAQ items.
- Visibility: draft, published, archived.

Save effect:

- `Create offer` or `Update offer` calls `saveCoachPackage`.
- Plan preview JSON is generated from the editor structure.
- Published offers are visible to clients.
- Draft and archived offers are hidden from marketplace purchase.

### 5.11 Coach Profile

Purpose: edit public coach identity and marketplace filtering data.

Controls and fields:

| Field or control | Effect |
| --- | --- |
| `Preview public profile` icon | Opens public coach details preview. |
| Headline | Public short positioning. |
| Positioning Statement | Public value proposition. |
| Bio | Required public coach story. |
| Service Summary | Public description of service model. |
| Specialties chip input | Adds/removes public specialties. |
| Years of Experience | Public trust signal. |
| Delivery Mode | Public delivery type. |
| Hourly Rate | Pricing signal. |
| `Offer Trial Period` switch | Enables trial pricing. |
| Trial Price | Trial amount when enabled. |
| City | Location filtering. |
| `Remote Only` switch | Indicates remote-only service. |
| Languages chip input | Marketplace and client matching. |
| Coach Gender dropdown | Marketplace filter. |
| Response Time hours | Expected response speed. |
| `Save Coach Profile` | Calls `upsertCoachProfile`. |

## 6. Client-Side Screens, Buttons, And Effects

### 6.1 Coach Marketplace

Purpose: find a coach.

Controls:

| Control | Effect |
| --- | --- |
| Search field | Searches by coach name, specialty, or city. |
| Clear icon | Clears search. |
| Specialty chips | Filter by specialty. |
| City filter | Filters city, including `All` and `Cairo`. |
| Language filter | Filters by language, including Arabic and English. |
| Budget filter | Filters open budget or under EGP 2500. |
| Gender filter | Filters any or female coach. |
| `Reset filters` | Clears tailored filters. |
| Pull to refresh | Reloads coach directory. |
| Coach card `View` | Opens coach details. |
| Coach card `Offers` | Opens subscription packages. |

### 6.2 Coach Details

Purpose: inspect a coach before buying.

Visible sections:

- Coach name and headline.
- Positioning.
- Specialties.
- Experience.
- Trial or starting offer.
- Number of live offers.
- Verification and trust badges.
- About.
- Service model.
- Certifications.
- Proof or testimonials.
- Offer preview.
- FAQ.
- Availability.
- Reviews.

Controls:

- Back button returns to previous page.
- `View full offers` opens the offer list for that coach.

### 6.3 Subscription Packages

Purpose: compare and buy a coach offer.

Offer card displays:

- Price.
- Outcome or description.
- Duration.
- Sessions per week.
- Difficulty.
- Check-in cadence.
- Location.
- Delivery mode.
- Renewal or trial information.
- Ideal client.
- Included features.
- Support summary.
- Starter plan preview.
- FAQ expansion.

Controls:

| Control | Effect |
| --- | --- |
| `Start paid checkout` | Opens checkout dialog. |
| Checkout `Cancel` | Closes dialog without creating subscription. |
| Checkout `Submit request` | Calls `create_coach_checkout`. |

Checkout fields:

- Primary goal, required.
- Experience level: beginner, intermediate, advanced.
- Days per week.
- Session minutes.
- Budget in EGP.
- City.
- Equipment available.
- Limitations or injuries.
- Optional note to coach.
- Payment rail: instapay, card, or wallet.

Client-facing result:

- Snackbar: `Checkout started. Confirm payment from My Coaching to activate the coach thread.`
- Client goes to `My Coaching` to submit payment proof when required.

### 6.4 My Coaching

Purpose: client manages active and pending coaching subscriptions.

Empty state:

- `Browse Coaches` opens marketplace.

Subscription card displays:

- Coach name.
- Package title.
- Status.
- Amount.
- Billing cycle.
- Approximate response time.
- Renewal date when present.

Controls:

| Control | Visible when | Effect |
| --- | --- | --- |
| `Submit payment proof` | Checkout pending or waiting for manual payment | Opens payment proof sheet. |
| `Messages` | Thread exists | Opens member thread. |
| `Check-ins` | Active relationship | Opens member check-ins. Paused relationships keep history readable but cannot submit new check-ins. |
| `Pause subscription` | Active and pause allowed | Calls `pause_coach_subscription` with pause on. |
| `Resume subscription` | Paused | Calls `pause_coach_subscription` with pause off. |
| `Privacy Settings` | Active relationship | Opens member coach visibility settings. |

Payment proof sheet:

- Payment reference field.
- `Upload receipt` file picker for jpg, jpeg, png, or pdf.
- `Submit for verification` uploads receipt if selected and calls `submit_coach_payment_receipt`.
- Success snackbar: `Payment proof submitted for coach verification.`

### 6.5 Member Messages

Purpose: client reads and sends messages after activation.

Thread list:

- Shows coaching threads.
- Empty state explains messages appear after checkout is paid and activated.

Thread screen:

| Control | Effect |
| --- | --- |
| Text field `Write an update or question` | Client writes message. |
| Send icon | Calls `sendCoachingMessage`, inserts `coach_messages` with `sender_role = member`. |

Backend protections:

- Member can only insert as member in their own thread.
- Coach can only insert as coach in their own thread.
- Message types include text, check-in prompt, check-in feedback, and system.

### 6.6 Member Check-ins

Purpose: client submits weekly progress updates.

Eligibility:

- Active subscriptions only.
- Paused subscriptions keep history readable but cannot submit new check-ins.
- Non-active subscriptions cannot submit check-ins.

Card controls:

| Control | Effect |
| --- | --- |
| `Submit this week` | Opens weekly check-in dialog. |
| Dialog `Cancel` | Closes without save. |
| Dialog `Submit` | Calls `submit_weekly_checkin`. |

Dialog fields:

- Weight kg.
- Waist cm.
- Adherence percent from 0 to 100.
- Wins.
- Blockers.
- Questions.

Backend movement:

- App ensures a thread exists.
- Weekly check-in is inserted or updated for the same subscription and week start.
- Weight entry is inserted when weight is provided.
- Body measurement is inserted when waist is provided.
- Progress photos are replaced for that check-in when photo paths are provided.
- Coach receives a notification that feedback is needed.

### 6.7 Privacy Settings

Purpose: client controls what the coach can see beyond direct relationship records.

Controls:

| Control | Effect |
| --- | --- |
| `Revoke all` | Turns off all toggles and saves. |
| `AI Plan Summary` switch | Shares active workout plan title, duration, and overview when on. |
| `Workout Adherence` switch | Shares completion rates and missed-session counts when on. |
| `Progress Metrics` switch | Shares weight trends, body measurements, and check-in scores when on. |
| `Nutrition Summary` switch | Shares calorie, macro, and nutrition adherence summary when on. |
| `Product Recommendations` switch | Shares AI-suggested products and equipment needs when on. |
| `Relevant Purchases` switch | Shares purchase activity for recommended products only when on. |
| `Save Settings` | Calls `upsert_coach_member_visibility`. |
| `Consent change history` | Expands or collapses visibility audit timeline. |

Privacy movement:

- Data is private by default.
- First save creates `initial_grant` audit event.
- Later changes create `updated` or `revoked_all`.
- Coach can read settings only for active subscriptions.
- Coach cannot edit the client's settings.

## 7. Shared State Machines

### 7.1 Offer visibility

| State | Meaning | Client effect |
| --- | --- | --- |
| `draft` | Coach is still editing. | Not purchasable. |
| `published` | Coach has made the offer public. | Visible in marketplace and can start checkout. |
| `archived` | Coach has retired the offer. | Hidden from new purchase. Existing linked subscriptions are preserved. |

### 7.2 Subscription status

| State | Meaning | Main actions |
| --- | --- | --- |
| `checkout_pending` | Client started checkout but payment is not active. | Client submits payment proof. Coach sees lead/payment work. |
| `pending_payment` | Older or alternate pending-payment flow. | Coach can activate with starter plan in some paths, client can submit payment proof. |
| `pending_activation` | Payment or request is waiting for coach activation. | Coach can activate where allowed. |
| `active` | Coaching relationship is live. | Messaging, check-ins, bookings, resources, programs, privacy, and CRM are operational. |
| `paused` | Relationship is paused but retained. | Resume is possible; history remains readable, but new messages, check-ins, and feedback are blocked. |
| `completed` | Relationship ended normally. | Historical data may remain. |
| `cancelled` | Relationship was cancelled. | Operational actions should stop. |

### 7.3 Checkout status

| State | Meaning |
| --- | --- |
| `not_started` | No checkout began. |
| `checkout_pending` | Checkout row exists and payment is pending. |
| `submitted` | Manual payment reference submitted. |
| `receipt_uploaded` | Receipt file uploaded. |
| `under_verification` | Payment is in review. |
| `paid` | Payment accepted and relationship active. |
| `failed` | Payment proof failed and needs follow-up. |
| `refunded` | Payment reversed/refunded. |

### 7.4 Billing queue state

| State | How it is calculated |
| --- | --- |
| `activated` | Subscription active, receipt activated, or checkout paid. |
| `failed_needs_follow_up` | Receipt failed or checkout failed. |
| `under_verification` | Latest receipt under verification. |
| `receipt_uploaded` | Latest receipt has file proof. |
| `payment_submitted` | Latest receipt has submitted reference only. |
| `awaiting_payment` | Subscription is checkout pending, pending payment, pending activation, or checkout pending. |
| `not_started` | None of the above. |

### 7.5 Coach CRM pipeline stage

| Stage | Meaning |
| --- | --- |
| `lead` | Relationship is early or not yet converted. |
| `pending_payment` | Client owes or submitted payment. |
| `active` | Client is actively coached. |
| `at_risk` | Coach should intervene. |
| `paused` | Client paused. |
| `archived` | Coach removed it from active pipeline. |

### 7.6 Coach risk status

| State | Meaning |
| --- | --- |
| `none` | No manual risk flag. |
| `at_risk` | Coach should monitor or intervene. |
| `critical` | Coach considers the relationship urgent. |

Some backend records also support `watch`; the current pipeline sheet exposes `none`, `at_risk`, and `critical`.

### 7.7 Booking status

| State | Meaning |
| --- | --- |
| `scheduled` | Session is planned. |
| `completed` | Session happened. |
| `cancelled` | Session was cancelled. |
| `rescheduled` | Session was moved. |

### 7.8 Message type

| Type | Meaning |
| --- | --- |
| `text` | Normal coach or client message. |
| `checkin_prompt` | Prompt related to check-in behavior. |
| `checkin_feedback` | Coach reply generated from a check-in review. |
| `system` | Automated thread message. |

### 7.9 Visibility category

| Category | Default | Coach sees when enabled |
| --- | --- | --- |
| AI Plan Summary | Off | Active plan title, source, status, dates, version, duration, level, summary, total days, total tasks. |
| Workout Adherence | Off | Total tasks, completed, partial, skipped, missed, completion rate, streak placeholder, last completion. |
| Progress Metrics | Off | Latest weight, weight trend, body measurement, last check-in date, latest check-in adherence. |
| Nutrition Summary | Off | Calorie and macro targets, latest nutrition adherence, active meal plan flag. |
| Product Recommendations | Off | Recommended products and recommendation context. |
| Relevant Purchases | Off | Purchases for recommended products only. |

## 8. End-To-End Interaction Loops

### 8.1 New coach to first paid client

1. Coach completes onboarding.
2. Coach has profile, starter package, and availability.
3. Client finds coach in marketplace.
4. Client opens details and offers.
5. Client starts paid checkout.
6. Client submits payment proof.
7. Coach approves payment.
8. Subscription becomes active.
9. Thread is created.
10. Client sends first message or check-in.
11. Coach replies, assigns starter work, or schedules a session.

### 8.2 Weekly check-in feedback loop

1. Client opens check-ins.
2. Client taps `Submit this week`.
3. Client enters weight, waist, adherence, wins, blockers, and questions.
4. App saves or updates this week's check-in.
5. Coach sees the check-in in inbox and workspace.
6. Coach taps `Review check-in`.
7. Coach writes structured feedback.
8. App updates `coach_reply`.
9. App posts a `checkin_feedback` message into the shared thread.
10. Client receives notification and can continue the conversation.

### 8.3 Program assignment loop

1. Coach builds a program template in the library.
2. Coach opens a client workspace.
3. Coach opens the Plan tab or quick action.
4. Coach taps `Assign` on a program template.
5. Backend archives existing active coach plan for that member when needed.
6. Backend creates a new workout plan with days and tasks.
7. Client receives a notification or sees the assigned plan in workout planning areas.
8. If the client enables AI plan or adherence visibility, the coach can see aggregated plan and completion data.

### 8.4 Resource sharing loop

1. Coach uploads a file or saves a link in Resources.
2. Coach taps `Assign` from Resources or the client workspace.
3. Coach chooses a subscription.
4. Backend creates or updates `coach_resource_assignments`.
5. Client receives notification that a resource was shared.
6. The resource remains tied to that subscription.

### 8.5 Session booking loop

1. Coach creates at least one session type.
2. Coach creates availability slots.
3. Coach opens client workspace or calendar.
4. Coach taps `Schedule`, `Book`, or `Schedule session`.
5. Coach chooses client, session type, start datetime, and note.
6. Backend creates `coach_bookings`.
7. Coach can later mark it scheduled, completed, cancelled, or rescheduled.

### 8.6 Privacy and insights loop

1. Client opens `Privacy Settings`.
2. Client enables only the categories they want to share.
3. App saves visibility settings and audit history.
4. Coach workspace Privacy tab changes from locked to shared for selected categories.
5. Coach insights show only consented sections.
6. Client can return at any time, disable one category, or tap `Revoke all`.

### 8.7 Billing failure loop

1. Client submits payment proof.
2. Coach opens billing.
3. Coach taps `Needs follow-up`.
4. Coach enters reason.
5. Backend marks receipt failed and checkout failed.
6. Client receives reason notification.
7. Client can submit a corrected proof if the UI flow still exposes payment proof for that pending relationship.

### 8.8 Pause and resume loop

1. Client opens `My Coaching`.
2. Client taps `Pause subscription`.
3. Backend calls `pause_coach_subscription` with pause on.
4. Subscription status becomes `paused`.
5. Client can tap `Resume subscription`.
6. Backend calls the same RPC with pause off.
7. Subscription returns to `active`.

## 9. Permissions And Privacy Rules

Coach-side access:

- Coach can read and manage their own coach profile, offers, availability, session types, templates, resources, bookings, CRM records, private notes, payment receipts, and action items.
- Coach can read client workspace data only for subscriptions where they are the coach.
- Coach can insert messages only as `coach` in threads where they are the coach.
- Coach can submit check-in feedback only for check-ins where they are the coach.
- Coach can read visibility settings only for active subscriptions.
- Coach cannot change client visibility settings.

Client-side access:

- Client can start checkout only as a member.
- Client can submit payment proof only for their own subscription.
- Client can read their own coaching threads, messages, check-ins, subscriptions, and assigned resources.
- Client can insert messages only as `member` in their own thread.
- Client can submit weekly check-ins only for their own active or paused subscription.
- Client manages their own privacy visibility settings.

Shared access:

- Threads, messages, check-ins, payment audit, and assigned resources are visible to both participants.
- Coach private notes and CRM tags are not shared with the client.
- Consent-gated health, plan, nutrition, and purchase summaries are private unless the client enables the matching switch.

## 10. Empty States, Disabled States, And Edge Cases

Marketplace:

- No coaches found means filters or search returned no public profiles.
- Draft or archived offers should not appear for checkout.

Checkout:

- Unauthenticated user cannot start checkout.
- Non-member cannot start checkout.
- Unpublished package cannot be purchased.
- Duplicate open relationship for the same offer is rejected.
- Unsupported payment rail is rejected.
- Payment rail not enabled for the offer is rejected unless `manual_fallback`.

Payment:

- Client cannot submit payment proof for someone else's subscription.
- Client cannot submit proof if the subscription is not waiting for manual payment.
- Coach cannot verify a receipt they do not own.
- Failed receipt stores a failure reason and notifies the client.
- Approving payment creates the thread if missing.

Messaging:

- Member thread list is empty until activation creates a thread.
- Coach workspace `Message` button is disabled when no thread exists.
- Direct inserts prevent role spoofing.
- System messages can be created by backend flows such as thread initialization.

Check-ins:

- Weekly check-ins require an active subscription.
- Same subscription and week start updates the existing check-in instead of creating duplicates.
- Adherence is clamped between 0 and 100.
- Empty coach feedback is rejected.
- If a check-in has no thread, coach feedback ensures a thread exists.

Programs:

- Assigning a program template requires a valid coach-owned template.
- Assigning a starter plan from an offer requires plan preview JSON.
- Existing active coach plans can be archived before a new assigned plan is created.

Resources:

- Resource must have either storage path or external URL.
- Resource assignment requires a coach-owned active resource.
- Same resource cannot be duplicated for the same subscription; assignment is updated instead.

Calendar:

- Creating a booking requires an active client and session type.
- Invalid datetime input should block booking creation in UI or throw backend validation.
- If no session types exist, coach must create one before booking.

Privacy:

- No visibility settings means all advanced data categories are locked.
- `Revoke all` creates a revocation audit record.
- Coach insights return header-only data when no categories are shared.
- Coach insights return nothing if the subscription is not active.

CRM:

- CRM stage and risk are coach-side operational labels.
- Changing CRM does not activate or pause a subscription by itself.
- Archived pipeline records can hide work from active coach views without deleting subscription history.

## 11. Notifications Between Coach And Client

| Trigger | Recipient | Message purpose |
| --- | --- | --- |
| Client starts checkout | Coach | A paid checkout started for an offer. |
| Client starts checkout | Client | Complete payment to activate thread and check-ins. |
| Client submits payment proof | Coach | Payment proof is waiting for review. |
| Coach approves payment | Client | Payment verified and coaching workspace is active. |
| Coach fails payment proof | Client | Payment needs follow-up with reason. |
| Thread is created | Thread participants through system message | Coaching thread is ready. |
| Client submits weekly check-in | Coach | Check-in is waiting for feedback. |
| Coach submits check-in feedback | Client | Coach replied to weekly check-in. |
| Coach assigns resource | Client | New coaching resource shared. |
| Coach assigns onboarding flow | Client indirectly through messages/resources/programs | Welcome, starter program, habits, or resources may appear. |

## 12. What Each Side Can Do After Activation

Coach can:

- Message the client.
- Review and reply to check-ins.
- Assign programs from templates.
- Assign habits.
- Assign resources.
- Schedule sessions.
- Update booking status.
- Track payment audit.
- Add private notes.
- Update CRM stage, risk, tags, and follow-up dates.
- Read only the client data categories the client has explicitly shared.

Client can:

- Message the coach.
- Submit weekly check-ins.
- See coach feedback in the thread.
- Use assigned workout plans.
- Receive assigned resources.
- Attend or track scheduled sessions when surfaced.
- Pause and resume when allowed.
- Submit payment proof.
- Control privacy visibility.
- Revoke all shared data.

## 13. Practical Product Rules

- The relationship should not be considered live until `subscriptions.status = active`.
- The shared thread should be treated as the main communication surface.
- Coach CRM should be treated as private operations data, not client-facing data.
- Payment verification should be auditable because it changes the relationship state.
- Check-ins should be treated as the recurring accountability loop.
- Program assignment should create concrete plan days and tasks, not just a message.
- Resources should be attached to subscriptions, not just broadcast generally.
- Privacy visibility should be opt-in and reversible.
- Any screen that shows advanced client metrics must respect visibility settings.
- Any action that writes relationship data should invalidate or refresh the relevant dashboard, pipeline, workspace, subscription, and thread providers.
