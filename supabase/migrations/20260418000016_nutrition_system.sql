-- GymUnity nutrition system
-- Date: 2026-04-18

create table if not exists public.nutrition_profiles (
  member_id uuid primary key references public.profiles(user_id) on delete cascade,
  activity_level text check (
    activity_level is null
    or activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')
  ),
  dietary_preference text not null default 'balanced' check (
    dietary_preference in (
      'balanced',
      'high_protein',
      'vegetarian',
      'pescatarian',
      'low_carb',
      'mediterranean',
      'halal'
    )
  ),
  meal_count_preference integer not null default 4 check (meal_count_preference between 3 and 5),
  allergies text[] not null default '{}',
  food_exclusions text[] not null default '{}',
  preferred_cuisines text[] not null default '{egyptian,international}',
  budget_level text not null default 'balanced' check (
    budget_level in ('budget', 'balanced', 'premium')
  ),
  cooking_preference text not null default 'simple' check (
    cooking_preference in ('minimal', 'simple', 'meal_prep', 'fresh')
  ),
  wake_time time,
  sleep_time time,
  workout_timing text check (
    workout_timing is null
    or workout_timing in ('morning', 'midday', 'evening', 'varies')
  ),
  hydration_preference text not null default 'standard' check (
    hydration_preference in ('standard', 'high', 'low_reminders')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.nutrition_targets (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  formula_version text not null default 'gymunity_msj_v1',
  goal_snapshot text not null,
  bmr_calories integer not null check (bmr_calories > 0),
  tdee_calories integer not null check (tdee_calories > 0),
  target_calories integer not null check (target_calories > 0),
  protein_g integer not null check (protein_g >= 0),
  carbs_g integer not null check (carbs_g >= 0),
  fats_g integer not null check (fats_g >= 0),
  protein_percent integer not null check (protein_percent between 0 and 100),
  carbs_percent integer not null check (carbs_percent between 0 and 100),
  fats_percent integer not null check (fats_percent between 0 and 100),
  hydration_ml integer not null check (hydration_ml > 0),
  explanation_json jsonb not null default '{}'::jsonb,
  source_context_json jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists idx_nutrition_targets_member_active
  on public.nutrition_targets(member_id)
  where status = 'active';
create index if not exists idx_nutrition_targets_member_created
  on public.nutrition_targets(member_id, created_at desc);

create table if not exists public.nutrition_meal_templates (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references public.profiles(user_id) on delete cascade,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  title_en text not null,
  title_ar text,
  description_en text not null default '',
  description_ar text not null default '',
  cuisine_tags text[] not null default '{}',
  dietary_tags text[] not null default '{}',
  allergen_tags text[] not null default '{}',
  budget_level text not null default 'balanced' check (
    budget_level in ('budget', 'balanced', 'premium')
  ),
  prep_level text not null default 'simple' check (
    prep_level in ('minimal', 'simple', 'meal_prep', 'fresh')
  ),
  calories integer not null check (calories > 0),
  protein_g integer not null check (protein_g >= 0),
  carbs_g integer not null check (carbs_g >= 0),
  fats_g integer not null check (fats_g >= 0),
  ingredients_json jsonb not null default '[]'::jsonb,
  ingredients_ar_json jsonb not null default '[]'::jsonb,
  instructions_en text not null default '',
  instructions_ar text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_nutrition_templates_type_active
  on public.nutrition_meal_templates(meal_type, is_active);
create index if not exists idx_nutrition_templates_owner
  on public.nutrition_meal_templates(owner_user_id, created_at desc);

create table if not exists public.member_meal_plans (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  target_id uuid not null references public.nutrition_targets(id) on delete restrict,
  start_date date not null,
  end_date date not null,
  meal_count integer not null check (meal_count between 3 and 5),
  status text not null default 'active' check (status in ('active', 'archived')),
  generation_context_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (end_date >= start_date)
);

create unique index if not exists idx_member_meal_plans_member_active
  on public.member_meal_plans(member_id)
  where status = 'active';
create index if not exists idx_member_meal_plans_member_dates
  on public.member_meal_plans(member_id, start_date desc, end_date desc);

create table if not exists public.member_meal_plan_days (
  id uuid primary key default gen_random_uuid(),
  meal_plan_id uuid not null references public.member_meal_plans(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  plan_date date not null,
  target_calories integer not null check (target_calories > 0),
  protein_g integer not null check (protein_g >= 0),
  carbs_g integer not null check (carbs_g >= 0),
  fats_g integer not null check (fats_g >= 0),
  hydration_ml integer not null check (hydration_ml > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (meal_plan_id, plan_date)
);

create index if not exists idx_member_meal_plan_days_member_date
  on public.member_meal_plan_days(member_id, plan_date desc);

create table if not exists public.member_planned_meals (
  id uuid primary key default gen_random_uuid(),
  meal_plan_day_id uuid not null references public.member_meal_plan_days(id) on delete cascade,
  meal_plan_id uuid not null references public.member_meal_plans(id) on delete cascade,
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  plan_date date not null,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  scheduled_time time,
  template_id uuid references public.nutrition_meal_templates(id) on delete set null,
  title text not null,
  description text not null default '',
  calories integer not null check (calories > 0),
  protein_g integer not null check (protein_g >= 0),
  carbs_g integer not null check (carbs_g >= 0),
  fats_g integer not null check (fats_g >= 0),
  ingredients_json jsonb not null default '[]'::jsonb,
  instructions text not null default '',
  sort_order integer not null default 0,
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_member_planned_meals_member_date
  on public.member_planned_meals(member_id, plan_date, sort_order);
create index if not exists idx_member_planned_meals_day
  on public.member_planned_meals(meal_plan_day_id, sort_order);

create table if not exists public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  planned_meal_id uuid references public.member_planned_meals(id) on delete set null,
  log_date date not null,
  source text not null default 'planned' check (source in ('planned', 'custom', 'quick_add')),
  title text not null,
  calories integer not null check (calories >= 0),
  protein_g integer not null default 0 check (protein_g >= 0),
  carbs_g integer not null default 0 check (carbs_g >= 0),
  fats_g integer not null default 0 check (fats_g >= 0),
  completed_at timestamptz not null default timezone('utc', now()),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists idx_meal_logs_planned_unique
  on public.meal_logs(planned_meal_id)
  where planned_meal_id is not null;
create index if not exists idx_meal_logs_member_date
  on public.meal_logs(member_id, log_date desc, completed_at desc);

create table if not exists public.hydration_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  log_date date not null,
  amount_ml integer not null check (amount_ml > 0),
  logged_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_hydration_logs_member_date
  on public.hydration_logs(member_id, log_date desc, logged_at desc);

create table if not exists public.nutrition_checkins (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(user_id) on delete cascade,
  week_start date not null,
  adherence_score integer not null default 0 check (adherence_score between 0 and 100),
  hunger_score integer check (hunger_score is null or hunger_score between 1 and 10),
  energy_score integer check (energy_score is null or energy_score between 1 and 10),
  notes text,
  suggested_adjustment_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (member_id, week_start)
);

create index if not exists idx_nutrition_checkins_member_week
  on public.nutrition_checkins(member_id, week_start desc);

alter table public.nutrition_profiles enable row level security;
alter table public.nutrition_targets enable row level security;
alter table public.nutrition_meal_templates enable row level security;
alter table public.member_meal_plans enable row level security;
alter table public.member_meal_plan_days enable row level security;
alter table public.member_planned_meals enable row level security;
alter table public.meal_logs enable row level security;
alter table public.hydration_logs enable row level security;
alter table public.nutrition_checkins enable row level security;

drop policy if exists nutrition_profiles_read_own on public.nutrition_profiles;
create policy nutrition_profiles_read_own
on public.nutrition_profiles for select
to authenticated
using (member_id = auth.uid());

drop policy if exists nutrition_profiles_manage_own on public.nutrition_profiles;
create policy nutrition_profiles_manage_own
on public.nutrition_profiles for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists nutrition_targets_read_own on public.nutrition_targets;
create policy nutrition_targets_read_own
on public.nutrition_targets for select
to authenticated
using (member_id = auth.uid());

drop policy if exists nutrition_targets_manage_own on public.nutrition_targets;
create policy nutrition_targets_manage_own
on public.nutrition_targets for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists nutrition_templates_read_available on public.nutrition_meal_templates;
create policy nutrition_templates_read_available
on public.nutrition_meal_templates for select
to authenticated
using (is_active = true and (owner_user_id is null or owner_user_id = auth.uid()));

drop policy if exists nutrition_templates_manage_own on public.nutrition_meal_templates;
create policy nutrition_templates_manage_own
on public.nutrition_meal_templates for all
to authenticated
using (owner_user_id = auth.uid() and public.current_role() = 'member')
with check (owner_user_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_meal_plans_read_own on public.member_meal_plans;
create policy member_meal_plans_read_own
on public.member_meal_plans for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_meal_plans_manage_own on public.member_meal_plans;
create policy member_meal_plans_manage_own
on public.member_meal_plans for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_meal_plan_days_read_own on public.member_meal_plan_days;
create policy member_meal_plan_days_read_own
on public.member_meal_plan_days for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_meal_plan_days_manage_own on public.member_meal_plan_days;
create policy member_meal_plan_days_manage_own
on public.member_meal_plan_days for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists member_planned_meals_read_own on public.member_planned_meals;
create policy member_planned_meals_read_own
on public.member_planned_meals for select
to authenticated
using (member_id = auth.uid());

drop policy if exists member_planned_meals_manage_own on public.member_planned_meals;
create policy member_planned_meals_manage_own
on public.member_planned_meals for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists meal_logs_read_own on public.meal_logs;
create policy meal_logs_read_own
on public.meal_logs for select
to authenticated
using (member_id = auth.uid());

drop policy if exists meal_logs_manage_own on public.meal_logs;
create policy meal_logs_manage_own
on public.meal_logs for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists hydration_logs_read_own on public.hydration_logs;
create policy hydration_logs_read_own
on public.hydration_logs for select
to authenticated
using (member_id = auth.uid());

drop policy if exists hydration_logs_manage_own on public.hydration_logs;
create policy hydration_logs_manage_own
on public.hydration_logs for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop policy if exists nutrition_checkins_read_own on public.nutrition_checkins;
create policy nutrition_checkins_read_own
on public.nutrition_checkins for select
to authenticated
using (member_id = auth.uid());

drop policy if exists nutrition_checkins_manage_own on public.nutrition_checkins;
create policy nutrition_checkins_manage_own
on public.nutrition_checkins for all
to authenticated
using (member_id = auth.uid() and public.current_role() = 'member')
with check (member_id = auth.uid() and public.current_role() = 'member');

drop trigger if exists touch_nutrition_profiles_updated_at on public.nutrition_profiles;
create trigger touch_nutrition_profiles_updated_at
before update on public.nutrition_profiles
for each row execute function public.touch_updated_at();

drop trigger if exists touch_nutrition_targets_updated_at on public.nutrition_targets;
create trigger touch_nutrition_targets_updated_at
before update on public.nutrition_targets
for each row execute function public.touch_updated_at();

drop trigger if exists touch_nutrition_templates_updated_at on public.nutrition_meal_templates;
create trigger touch_nutrition_templates_updated_at
before update on public.nutrition_meal_templates
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_meal_plans_updated_at on public.member_meal_plans;
create trigger touch_member_meal_plans_updated_at
before update on public.member_meal_plans
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_meal_plan_days_updated_at on public.member_meal_plan_days;
create trigger touch_member_meal_plan_days_updated_at
before update on public.member_meal_plan_days
for each row execute function public.touch_updated_at();

drop trigger if exists touch_member_planned_meals_updated_at on public.member_planned_meals;
create trigger touch_member_planned_meals_updated_at
before update on public.member_planned_meals
for each row execute function public.touch_updated_at();

drop trigger if exists touch_meal_logs_updated_at on public.meal_logs;
create trigger touch_meal_logs_updated_at
before update on public.meal_logs
for each row execute function public.touch_updated_at();

drop trigger if exists touch_nutrition_checkins_updated_at on public.nutrition_checkins;
create trigger touch_nutrition_checkins_updated_at
before update on public.nutrition_checkins
for each row execute function public.touch_updated_at();

insert into public.nutrition_meal_templates (
  id,
  meal_type,
  title_en,
  title_ar,
  description_en,
  description_ar,
  cuisine_tags,
  dietary_tags,
  allergen_tags,
  budget_level,
  prep_level,
  calories,
  protein_g,
  carbs_g,
  fats_g,
  ingredients_json,
  ingredients_ar_json,
  instructions_en,
  instructions_ar
)
values
('00000000-0000-4000-8000-000000000001','breakfast','Ful medames protein bowl','فول مدمس عالي البروتين','Ful with eggs, vegetables, and baladi bread.','فول مع بيض وخضار وعيش بلدي.', '{egyptian,arabic}', '{balanced,high_protein,halal}', '{eggs,gluten}', 'budget', 'simple', 520, 32, 62, 16, '["ful medames","eggs","tomato","cucumber","baladi bread"]'::jsonb, '["فول مدمس","بيض","طماطم","خيار","عيش بلدي"]'::jsonb, 'Serve ful with boiled eggs and chopped vegetables.', 'قدم الفول مع البيض والخضار.'),
('00000000-0000-4000-8000-000000000002','breakfast','Greek yogurt oat cup','كوب زبادي يوناني بالشوفان','High-protein yogurt with oats and fruit.','زبادي عالي البروتين مع شوفان وفاكهة.', '{international,mediterranean}', '{balanced,high_protein,vegetarian}', '{dairy}', 'balanced', 'minimal', 430, 34, 52, 9, '["greek yogurt","oats","banana","honey"]'::jsonb, '["زبادي يوناني","شوفان","موز","عسل"]'::jsonb, 'Layer ingredients in a bowl and chill.', 'اخلط المكونات في كوب وقدمه باردا.'),
('00000000-0000-4000-8000-000000000003','breakfast','Egg white veggie wrap','راب بياض بيض بالخضار','Light wrap with eggs and vegetables.','راب خفيف بالبيض والخضار.', '{international}', '{balanced,high_protein,halal}', '{eggs,gluten}', 'balanced', 'simple', 390, 31, 38, 12, '["egg whites","whole wheat wrap","pepper","spinach"]'::jsonb, '["بياض بيض","راب قمح كامل","فلفل","سبانخ"]'::jsonb, 'Cook eggs with vegetables and wrap.', 'اطه البيض مع الخضار ثم لفه.'),
('00000000-0000-4000-8000-000000000004','breakfast','Cottage cheese fruit plate','طبق جبن قريش وفاكهة','Simple cottage cheese, fruit, and nuts.','جبن قريش مع فاكهة ومكسرات.', '{egyptian,international}', '{balanced,high_protein,vegetarian,halal}', '{dairy,nuts}', 'budget', 'minimal', 410, 30, 42, 13, '["cottage cheese","apple","almonds","toast"]'::jsonb, '["جبن قريش","تفاح","لوز","توست"]'::jsonb, 'Plate and serve fresh.', 'قدم المكونات طازجة.'),
('00000000-0000-4000-8000-000000000005','breakfast','Protein smoothie bowl','بول سموثي بروتين','Milk, banana, oats, and protein.','لبن وموز وشوفان وبروتين.', '{international}', '{balanced,high_protein}', '{dairy}', 'premium', 'minimal', 480, 36, 58, 11, '["milk","banana","oats","protein powder"]'::jsonb, '["لبن","موز","شوفان","بودرة بروتين"]'::jsonb, 'Blend and top with oats.', 'اخلط المكونات وأضف الشوفان.'),
('00000000-0000-4000-8000-000000000006','breakfast','Taameya and salad plate','طبق طعمية وسلطة متوازن','A practical Egyptian breakfast with portion control.','إفطار مصري عملي مع تحكم في الكمية.', '{egyptian,arabic}', '{balanced,vegetarian,halal}', '{gluten}', 'budget', 'minimal', 500, 18, 68, 18, '["taameya","salad","baladi bread","tahini"]'::jsonb, '["طعمية","سلطة","عيش بلدي","طحينة"]'::jsonb, 'Keep tahini and bread portions moderate.', 'حافظ على كمية معتدلة من الطحينة والعيش.'),
('00000000-0000-4000-8000-000000000007','lunch','Chicken rice fitness plate','طبق دجاج وأرز','Lean chicken with rice and vegetables.','دجاج قليل الدهون مع أرز وخضار.', '{egyptian,international}', '{balanced,high_protein,halal}', '{}', 'balanced', 'meal_prep', 680, 48, 78, 17, '["chicken breast","rice","mixed vegetables","olive oil"]'::jsonb, '["صدر دجاج","أرز","خضار مشكل","زيت زيتون"]'::jsonb, 'Grill chicken and serve with rice and vegetables.', 'اشو الدجاج وقدمه مع الأرز والخضار.'),
('00000000-0000-4000-8000-000000000008','lunch','Koshari light bowl','كشري خفيف','Koshari-inspired bowl with controlled oil and lentils.','كشري أخف مع عدس وزيت أقل.', '{egyptian,arabic}', '{balanced,vegetarian}', '{gluten}', 'budget', 'meal_prep', 640, 24, 104, 13, '["rice","lentils","pasta","tomato sauce","crispy onions"]'::jsonb, '["أرز","عدس","مكرونة","صلصة طماطم","بصل مقرمش"]'::jsonb, 'Use extra lentils and a smaller fried onion portion.', 'زود العدس وقلل البصل المقلي.'),
('00000000-0000-4000-8000-000000000009','lunch','Tuna potato salad','سلطة تونة وبطاطس','Tuna with potatoes, greens, and lemon.','تونة مع بطاطس وخضار وليمون.', '{mediterranean,international}', '{balanced,high_protein,pescatarian,halal}', '{fish}', 'balanced', 'minimal', 560, 42, 58, 16, '["tuna","potato","greens","olive oil","lemon"]'::jsonb, '["تونة","بطاطس","خضار ورقي","زيت زيتون","ليمون"]'::jsonb, 'Mix and serve chilled.', 'اخلط المكونات وقدمها باردة.'),
('00000000-0000-4000-8000-000000000010','lunch','Lean kofta bulgur bowl','كفتة قليلة الدهون وبرغل','Lean kofta with bulgur and salad.','كفتة قليلة الدهون مع برغل وسلطة.', '{egyptian,arabic}', '{balanced,high_protein,halal}', '{gluten}', 'balanced', 'simple', 700, 46, 70, 24, '["lean beef kofta","bulgur","salad","yogurt sauce"]'::jsonb, '["كفتة قليلة الدهون","برغل","سلطة","صوص زبادي"]'::jsonb, 'Grill kofta and serve with bulgur.', 'اشو الكفتة وقدمها مع البرغل.'),
('00000000-0000-4000-8000-000000000011','lunch','Lentil soup protein lunch','شوربة عدس غنية','Lentils with yogurt and bread for a filling lunch.','عدس مع زبادي وعيش لوجبة مشبعة.', '{egyptian,arabic}', '{balanced,vegetarian}', '{dairy,gluten}', 'budget', 'meal_prep', 590, 27, 88, 14, '["lentils","carrot","yogurt","baladi bread"]'::jsonb, '["عدس","جزر","زبادي","عيش بلدي"]'::jsonb, 'Cook lentils with vegetables and pair with yogurt.', 'اطه العدس مع الخضار وقدمه مع الزبادي.'),
('00000000-0000-4000-8000-000000000012','lunch','Salmon sweet potato plate','سلمون وبطاطا','Higher-fat protein plate for active days.','وجبة بروتين ودهون صحية للأيام النشطة.', '{international,mediterranean}', '{balanced,high_protein,pescatarian}', '{fish}', 'premium', 'simple', 720, 45, 62, 30, '["salmon","sweet potato","greens","olive oil"]'::jsonb, '["سلمون","بطاطا","خضار ورقي","زيت زيتون"]'::jsonb, 'Bake salmon and sweet potato.', 'اخبز السلمون والبطاطا.'),
('00000000-0000-4000-8000-000000000013','dinner','Grilled chicken salad dinner','عشاء سلطة دجاج مشوي','Light high-protein dinner.','عشاء خفيف عالي البروتين.', '{international,mediterranean}', '{balanced,high_protein,halal,low_carb}', '{}', 'balanced', 'simple', 460, 44, 24, 19, '["grilled chicken","greens","tomato","olive oil"]'::jsonb, '["دجاج مشوي","خضار ورقي","طماطم","زيت زيتون"]'::jsonb, 'Serve chicken over salad.', 'قدم الدجاج فوق السلطة.'),
('00000000-0000-4000-8000-000000000014','dinner','Cottage cheese omelet','أومليت جبن قريش','Protein-focused simple dinner.','عشاء بسيط مركز على البروتين.', '{egyptian,international}', '{balanced,high_protein,vegetarian,halal,low_carb}', '{eggs,dairy}', 'budget', 'simple', 430, 38, 18, 22, '["eggs","cottage cheese","pepper","greens"]'::jsonb, '["بيض","جبن قريش","فلفل","خضار ورقي"]'::jsonb, 'Cook as an omelet with greens.', 'اطهه كأومليت مع الخضار.'),
('00000000-0000-4000-8000-000000000015','dinner','Turkey pasta recovery bowl','باستا ديك رومي للتعافي','Balanced carb dinner for training days.','عشاء كارب متوازن لأيام التمرين.', '{international}', '{balanced,high_protein,halal}', '{gluten}', 'balanced', 'meal_prep', 640, 42, 78, 16, '["turkey mince","pasta","tomato sauce","vegetables"]'::jsonb, '["لحم ديك رومي مفروم","مكرونة","صلصة طماطم","خضار"]'::jsonb, 'Cook turkey sauce and pasta.', 'اطه صوص الديك الرومي والمكرونة.'),
('00000000-0000-4000-8000-000000000016','dinner','Fish sayadeya light','صيادية سمك خفيفة','Egyptian fish and rice with controlled oil.','سمك وأرز بطريقة مصرية بزيت أقل.', '{egyptian,arabic}', '{balanced,pescatarian,halal}', '{fish}', 'balanced', 'simple', 610, 38, 76, 16, '["white fish","rice","onion","salad"]'::jsonb, '["سمك أبيض","أرز","بصل","سلطة"]'::jsonb, 'Bake or grill fish and keep oil moderate.', 'اخبز أو اشو السمك وقلل الزيت.'),
('00000000-0000-4000-8000-000000000017','dinner','Bean and veggie stew','يخنة فاصوليا وخضار','Plant-forward filling dinner.','عشاء نباتي مشبع.', '{mediterranean,international}', '{balanced,vegetarian}', '{}', 'budget', 'meal_prep', 520, 24, 76, 12, '["beans","vegetables","tomato sauce","rice"]'::jsonb, '["فاصوليا","خضار","صلصة طماطم","أرز"]'::jsonb, 'Simmer beans with vegetables.', 'اطه الفاصوليا مع الخضار.'),
('00000000-0000-4000-8000-000000000018','dinner','Beef shawarma bowl','بول شاورما لحم','Lean shawarma-style dinner bowl.','بول عشاء بطابع شاورما قليلة الدهون.', '{arabic,international}', '{balanced,high_protein,halal}', '{dairy}', 'balanced', 'simple', 680, 44, 64, 24, '["lean beef","rice","salad","yogurt sauce"]'::jsonb, '["لحم قليل الدهون","أرز","سلطة","صوص زبادي"]'::jsonb, 'Cook beef strips and serve as a bowl.', 'اطه شرائح اللحم وقدمها في بول.'),
('00000000-0000-4000-8000-000000000019','snack','Protein dates yogurt','زبادي بالتمر والبروتين','Sweet snack with protein and carbs.','سناك حلو بالبروتين والكارب.', '{egyptian,arabic}', '{balanced,high_protein,vegetarian,halal}', '{dairy}', 'balanced', 'minimal', 260, 22, 34, 4, '["greek yogurt","dates","cinnamon"]'::jsonb, '["زبادي يوناني","تمر","قرفة"]'::jsonb, 'Mix and serve cold.', 'اخلط وقدمه باردا.'),
('00000000-0000-4000-8000-000000000020','snack','Apple peanut butter','تفاح وزبدة فول سوداني','Simple energy snack.','سناك طاقة بسيط.', '{international}', '{balanced,vegetarian}', '{nuts}', 'budget', 'minimal', 240, 7, 30, 11, '["apple","peanut butter"]'::jsonb, '["تفاح","زبدة فول سوداني"]'::jsonb, 'Slice apple and portion peanut butter.', 'قطع التفاح وقدمه مع كمية مناسبة من الزبدة.'),
('00000000-0000-4000-8000-000000000021','snack','Tuna cucumber bites','تونة وخيار','Low-carb high-protein snack.','سناك عالي البروتين وقليل الكارب.', '{international,mediterranean}', '{high_protein,pescatarian,low_carb}', '{fish}', 'balanced', 'minimal', 220, 30, 8, 7, '["tuna","cucumber","lemon"]'::jsonb, '["تونة","خيار","ليمون"]'::jsonb, 'Serve tuna over cucumber slices.', 'قدم التونة فوق شرائح الخيار.'),
('00000000-0000-4000-8000-000000000022','snack','Hummus veggie cup','كوب حمص وخضار','Fiber-rich snack with vegetables.','سناك غني بالألياف مع الخضار.', '{arabic,mediterranean}', '{balanced,vegetarian,halal}', '{}', 'budget', 'minimal', 230, 9, 28, 9, '["hummus","carrot","cucumber","pepper"]'::jsonb, '["حمص","جزر","خيار","فلفل"]'::jsonb, 'Dip vegetables into hummus.', 'اغمس الخضار في الحمص.'),
('00000000-0000-4000-8000-000000000023','snack','Milk banana recovery','لبن وموز للتعافي','Post-workout recovery snack.','سناك تعافي بعد التمرين.', '{international}', '{balanced,vegetarian,halal}', '{dairy}', 'budget', 'minimal', 300, 16, 46, 6, '["milk","banana","cocoa"]'::jsonb, '["لبن","موز","كاكاو"]'::jsonb, 'Blend or drink with banana.', 'اخلط أو قدم اللبن مع الموز.'),
('00000000-0000-4000-8000-000000000024','snack','Boiled eggs and vegetables','بيض مسلوق وخضار','Portable protein snack.','سناك بروتين سهل الحمل.', '{egyptian,international}', '{high_protein,halal,low_carb}', '{eggs}', 'budget', 'meal_prep', 210, 18, 8, 12, '["boiled eggs","cucumber","tomato"]'::jsonb, '["بيض مسلوق","خيار","طماطم"]'::jsonb, 'Prep eggs ahead and serve with vegetables.', 'جهز البيض مسبقا وقدمه مع الخضار.')
on conflict (id) do nothing;
