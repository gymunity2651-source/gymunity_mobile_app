# Sync News Feeds

`sync-news-feeds` ingests curated trusted health/fitness sources into Supabase.

Current MVP behavior:

- Reads active rows from `public.news_sources`
- Fetches RSS feeds only
- Normalizes each entry into a stable article shape
- Deduplicates on `canonical_url` with a SHA-256 fallback hash
- Classifies topics, goals, levels, roles, evidence, trust, quality, and safety
- Upserts `news_articles`
- Rebuilds `news_article_topics` for each synced article
- Can be triggered by pg_cron through `private.schedule_news_sync(...)`

Classification is deterministic and rule-based on:

- Source metadata
- Title, summary, content, and feed categories
- Topic keyword matches
- Safety keyword patterns
- Evidence-oriented language such as `study`, `trial`, or `guideline`

Safety rules:

- `restricted`: obvious miracle-cure, extreme-diet, or self-diagnosis style claims
- `caution`: lower-confidence or potentially exaggerated wellness framing
- `general`: default for normal trusted-source health education/reporting

Operational notes:

- Use `NEWS_SYNC_SECRET` to authorize scheduled/manual sync calls
- Default scheduled cadence is every 4 hours at minute 17 (`17 */4 * * *`)
- `dry_run: true` can be passed in the request body to verify feeds without DB writes
- Seed sources live in `20260316000012_personalized_news.sql`
