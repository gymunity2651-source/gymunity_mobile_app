import { XMLParser } from "https://esm.sh/fast-xml-parser@4.5.3";
import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  type ClassifiedArticle,
  classifyArticle,
  type NewsSourceRow,
  type NormalizedArticle,
} from "./classifier.ts";

type FetchLike = typeof fetch;

type SyncRequest = {
  dry_run?: boolean;
  source_ids?: string[];
  backfill_missing_images?: boolean;
  backfill_limit?: number;
};

export type SyncSummary = {
  sourceId: string;
  sourceName: string;
  processed: number;
  inserted: number;
  updated: number;
  skipped: number;
  error?: string;
};

export type BackfillSummary = {
  processed: number;
  updated: number;
  skipped: number;
  errors: number;
};

type ExistingArticleRow = {
  id: string;
  canonical_url: string;
  image_url: string | null;
};

type BackfillArticleRow = {
  id: string;
  canonical_url: string;
  image_url: string | null;
  source_id: string;
};

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "",
  trimValues: true,
});

const NEWS_SYNC_USER_AGENT = "GymUnity-NewsSync/1.0";
const PAGE_IMAGE_TIMEOUT_MS = 6000;
const DEFAULT_BACKFILL_LIMIT = 100;
const MAX_BACKFILL_LIMIT = 500;

if (import.meta.main) {
  Deno.serve(handleSyncNewsFeedsRequest);
}

export async function handleSyncNewsFeedsRequest(
  req: Request,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!isAuthorized(req)) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  try {
    const body = (await req.json().catch(() => ({}))) as SyncRequest;
    const dryRun = body.dry_run === true;
    const sourceIds = Array.isArray(body.source_ids)
      ? body.source_ids.filter((value): value is string =>
        typeof value === "string" && value.trim().length > 0
      )
      : [];
    const backfillMissingImages = body.backfill_missing_images === true;
    const backfillLimit = normalizePositiveInt(
      body.backfill_limit,
      DEFAULT_BACKFILL_LIMIT,
      MAX_BACKFILL_LIMIT,
    );

    const supabase = createServiceClient();
    const sources = await listActiveSources(supabase, sourceIds);
    const summaries: SyncSummary[] = [];

    for (const source of sources) {
      summaries.push(await syncSource(supabase, source, dryRun));
    }

    let backfill: BackfillSummary | null = null;
    if (backfillMissingImages && !dryRun) {
      backfill = await backfillMissingArticleImages(
        supabase,
        sourceIds,
        backfillLimit,
      );
    }

    return jsonResponse({
      dry_run: dryRun,
      processed_sources: summaries.length,
      processed_articles: summaries.reduce(
        (total, item) => total + item.processed,
        0,
      ),
      inserted: summaries.reduce((total, item) => total + item.inserted, 0),
      updated: summaries.reduce((total, item) => total + item.updated, 0),
      skipped: summaries.reduce((total, item) => total + item.skipped, 0),
      backfill_requested: backfillMissingImages,
      backfill_limit: backfillMissingImages ? backfillLimit : null,
      backfill,
      summaries,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Unknown sync failure.",
      },
      500,
    );
  }
}

async function syncSource(
  supabase: SupabaseClient,
  source: NewsSourceRow,
  dryRun: boolean,
  fetchImpl: FetchLike = fetch,
): Promise<SyncSummary> {
  const summary: SyncSummary = {
    sourceId: source.id,
    sourceName: source.name,
    processed: 0,
    inserted: 0,
    updated: 0,
    skipped: 0,
  };

  try {
    const feedUrl = source.feed_url ?? source.api_endpoint;
    if (!feedUrl) {
      throw new Error("Source does not have a feed URL or API endpoint.");
    }

    const response = await fetchImpl(feedUrl, {
      headers: { "user-agent": NEWS_SYNC_USER_AGENT },
    });
    if (!response.ok) {
      throw new Error(
        `Feed returned ${response.status} ${response.statusText}`,
      );
    }

    const xml = await response.text();
    const articles = normalizeFeedEntries(source, xml).filter((article) =>
      !shouldSkipArticle(article)
    );
    summary.processed = articles.length;

    if (articles.length <= 0) {
      if (!dryRun) {
        await markSourceResult(supabase, source.id, null);
      }
      return summary;
    }

    if (dryRun) {
      summary.skipped = articles.length;
      return summary;
    }

    const canonicalUrls = articles.map((article) => article.canonicalUrl);
    const { data: existingRows, error: existingError } = await supabase
      .from("news_articles")
      .select("id,canonical_url,image_url")
      .eq("source_id", source.id)
      .in("canonical_url", canonicalUrls);

    if (existingError) {
      throw new Error(existingError.message);
    }

    const existingMap = new Map<string, ExistingArticleRow>();
    for (const row of existingRows ?? []) {
      const typedRow = row as ExistingArticleRow;
      existingMap.set(typedRow.canonical_url, typedRow);
    }

    for (const article of articles) {
      const existingRow = existingMap.get(article.canonicalUrl);
      const articleWithImage = await resolveArticleForStorage(
        article,
        existingRow?.image_url ?? null,
        fetchImpl,
      );
      const classification = classifyArticle(source, articleWithImage);
      const dedupeHash = await sha256Hex(
        `${articleWithImage.canonicalUrl}|${articleWithImage.title.toLowerCase()}|${
          articleWithImage.publishedAt.slice(0, 10)
        }`,
      );
      const payload = articlePayload(
        source,
        articleWithImage,
        classification,
        dedupeHash,
      );
      const wasExisting = existingRow != null;

      const { data: upsertedRow, error: upsertError } = await supabase
        .from("news_articles")
        .upsert(payload, { onConflict: "canonical_url" })
        .select("id")
        .single();

      if (upsertError) {
        throw new Error(upsertError.message);
      }

      const articleId = (upsertedRow as { id: string }).id;

      const { error: deleteTopicsError } = await supabase
        .from("news_article_topics")
        .delete()
        .eq("article_id", articleId);
      if (deleteTopicsError) {
        throw new Error(deleteTopicsError.message);
      }

      const topicRows = classification.topics.map((topic) => ({
        article_id: articleId,
        topic_code: topic.topicCode,
        score: topic.score,
      }));
      const { error: insertTopicsError } = await supabase
        .from("news_article_topics")
        .insert(topicRows);
      if (insertTopicsError) {
        throw new Error(insertTopicsError.message);
      }

      if (wasExisting) {
        summary.updated += 1;
      } else {
        summary.inserted += 1;
      }
    }

    await markSourceResult(supabase, source.id, null);
    return summary;
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Unknown source sync failure.";
    summary.error = message;
    if (!dryRun) {
      await markSourceResult(supabase, source.id, message);
    }
    return summary;
  }
}

async function backfillMissingArticleImages(
  supabase: SupabaseClient,
  sourceIds: string[],
  limit: number,
  fetchImpl: FetchLike = fetch,
): Promise<BackfillSummary> {
  let query = supabase
    .from("news_articles")
    .select("id,canonical_url,image_url,source_id")
    .eq("is_active", true)
    .is("image_url", null)
    .order("published_at", { ascending: false })
    .limit(limit);

  if (sourceIds.length > 0) {
    query = query.in("source_id", sourceIds);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error(error.message);
  }

  const rows = (data ?? []) as BackfillArticleRow[];
  const summary: BackfillSummary = {
    processed: rows.length,
    updated: 0,
    skipped: 0,
    errors: 0,
  };

  for (const row of rows) {
    const imageUrl = await resolveBestArticleImage(
      {
        canonicalUrl: row.canonical_url,
        feedImageUrl: null,
        existingImageUrl: row.image_url,
      },
      fetchImpl,
    );

    if (!imageUrl) {
      summary.skipped += 1;
      continue;
    }

    const timestamp = new Date().toISOString();
    const { error: updateError } = await supabase
      .from("news_articles")
      .update({
        image_url: imageUrl,
        fetched_at: timestamp,
        updated_at: timestamp,
      })
      .eq("id", row.id);

    if (updateError) {
      summary.errors += 1;
      continue;
    }

    summary.updated += 1;
  }

  return summary;
}

function normalizeFeedEntries(
  source: NewsSourceRow,
  xml: string,
): NormalizedArticle[] {
  const parsed = xmlParser.parse(xml) as Record<string, unknown>;
  const rss = parsed.rss as Record<string, unknown> | undefined;
  const channel = rss?.channel as Record<string, unknown> | undefined;
  if (channel) {
    const items = asArray<Record<string, unknown>>(channel.item);
    return items
      .map((item) => normalizeRssItem(source, item))
      .filter((item): item is NormalizedArticle => item !== null);
  }

  const feed = parsed.feed as Record<string, unknown> | undefined;
  if (feed) {
    const entries = asArray<Record<string, unknown>>(feed.entry);
    return entries
      .map((entry) => normalizeAtomEntry(source, entry))
      .filter((item): item is NormalizedArticle => item !== null);
  }

  return [];
}

function normalizeRssItem(
  source: NewsSourceRow,
  item: Record<string, unknown>,
): NormalizedArticle | null {
  const title = cleanText(readString(item.title));
  const rawLink = readLink(item.link);
  if (!title || !rawLink) {
    return null;
  }

  const canonicalUrl = canonicalizeUrl(rawLink);
  const summary = clipTextSafe(
    cleanText(
      readString(item.description) ||
        readString(item["content:encoded"]) ||
        readString(item.summary),
    ),
    420,
  );
  const content = clipTextSafe(
    cleanText(
      readString(item["content:encoded"]) ||
        readString(item.description) ||
        summary,
    ),
    12000,
  );
  const imageUrl = readImageUrl(item, canonicalUrl);
  const tags = asArray<string | Record<string, unknown>>(item.category)
    .map((value) =>
      typeof value === "string"
        ? cleanText(value)
        : cleanText(readString(value["#text"]) || readString(value.name))
    )
    .filter((value): value is string => value.length > 0);

  return {
    canonicalUrl,
    externalId: readString(item.guid) || null,
    title,
    summary,
    content,
    authorName: cleanText(
      readString(item["dc:creator"]) ||
        readAuthorName(item.author) ||
        readAuthorName(item["a10:author"]),
    ) || null,
    imageUrl,
    publishedAt: normalizeDate(
      readString(item.pubDate) ||
        readString(item.published) ||
        readString(item.updated),
    ),
    fetchedAt: new Date().toISOString(),
    language: normalizeLanguage(readString(item.language) || source.language),
    rawCategory: cleanText(readString(item.category)) || source.category ||
      null,
    tags,
  };
}

function normalizeAtomEntry(
  source: NewsSourceRow,
  entry: Record<string, unknown>,
): NormalizedArticle | null {
  const title = cleanText(readString(entry.title));
  const rawLink = readLink(entry.link);
  if (!title || !rawLink) {
    return null;
  }

  const canonicalUrl = canonicalizeUrl(rawLink);

  return {
    canonicalUrl,
    externalId: readString(entry.id) || null,
    title,
    summary: clipTextSafe(
      cleanText(readString(entry.summary) || readString(entry.content)),
      420,
    ),
    content: clipTextSafe(
      cleanText(readString(entry.content) || readString(entry.summary)),
      12000,
    ),
    authorName: cleanText(readAuthorName(entry.author)) || null,
    imageUrl: readImageUrl(entry, canonicalUrl),
    publishedAt: normalizeDate(
      readString(entry.updated) || readString(entry.published),
    ),
    fetchedAt: new Date().toISOString(),
    language: normalizeLanguage(readString(entry.language) || source.language),
    rawCategory: source.category || null,
    tags: asArray<Record<string, unknown>>(entry.category)
      .map((value) =>
        cleanText(readString(value.term) || readString(value.label))
      )
      .filter((value): value is string => value.length > 0),
  };
}

function shouldSkipArticle(article: NormalizedArticle): boolean {
  const title = cleanText(article.title);
  const summary = cleanText(article.summary).toLowerCase();
  const archiveTitlePattern =
    /^(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{4}$/i;
  const archiveUrlPattern = /\/\d{4}\/\d{2}\/?$/;

  if (archiveTitlePattern.test(title)) {
    return true;
  }

  if (archiveUrlPattern.test(article.canonicalUrl) && title.length <= 24) {
    return true;
  }

  return summary.includes("view-rss-list") ||
    summary.includes("js-view-dom-id");
}

function articlePayload(
  source: NewsSourceRow,
  article: NormalizedArticle,
  classification: ClassifiedArticle,
  dedupeHash: string,
): Record<string, unknown> {
  return {
    source_id: source.id,
    canonical_url: article.canonicalUrl,
    external_id: article.externalId,
    title: article.title,
    summary: article.summary,
    content: article.content,
    author_name: article.authorName,
    image_url: article.imageUrl,
    published_at: article.publishedAt,
    fetched_at: article.fetchedAt,
    language: article.language,
    category: classification.category,
    tags: article.tags,
    target_roles: classification.targetRoles,
    target_goals: classification.targetGoals,
    target_levels: classification.targetLevels,
    trust_score: classification.trustScore,
    evidence_level: classification.evidenceLevel,
    safety_level: classification.safetyLevel,
    quality_score: classification.qualityScore,
    dedupe_hash: dedupeHash,
    is_active: true,
    is_featured: classification.isFeatured,
    ingestion_notes: classification.ingestionNotes,
  };
}

async function listActiveSources(
  supabase: SupabaseClient,
  sourceIds: string[],
): Promise<NewsSourceRow[]> {
  let query = supabase
    .from("news_sources")
    .select(
      "id,name,base_url,feed_url,api_endpoint,source_type,language,country,category,is_active,trust_score,source_weight",
    )
    .eq("is_active", true)
    .order("name");

  if (sourceIds.length > 0) {
    query = query.in("id", sourceIds);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []) as NewsSourceRow[];
}

async function markSourceResult(
  supabase: SupabaseClient,
  sourceId: string,
  errorMessage: string | null,
): Promise<void> {
  const payload: Record<string, unknown> = {
    last_synced_at: new Date().toISOString(),
    last_error_at: errorMessage ? new Date().toISOString() : null,
    last_error_message: errorMessage,
  };

  await supabase.from("news_sources").update(payload).eq("id", sourceId);
}

function isAuthorized(req: Request): boolean {
  const cronSecret = Deno.env.get("NEWS_SYNC_SECRET")?.trim();
  const suppliedSecret = req.headers.get("x-news-sync-secret")?.trim();
  if (cronSecret && suppliedSecret && suppliedSecret === cronSecret) {
    return true;
  }

  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  const authHeader = req.headers.get("authorization")?.trim();
  return Boolean(serviceRoleKey && authHeader === `Bearer ${serviceRoleKey}`);
}

function createServiceClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false },
  });
}

function env(key: string): string {
  const value = Deno.env.get(key);
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

function readString(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number") {
    return String(value);
  }
  if (
    value &&
    typeof value === "object" &&
    "#text" in value &&
    typeof (value as Record<string, unknown>)["#text"] === "string"
  ) {
    return (value as Record<string, string>)["#text"];
  }
  return "";
}

function readLink(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }
  if (Array.isArray(value)) {
    for (const entry of value) {
      const link = readLink(entry);
      if (link) {
        return link;
      }
    }
    return "";
  }
  if (value && typeof value === "object") {
    const row = value as Record<string, unknown>;
    if (typeof row.href === "string") {
      return row.href;
    }
    if (typeof row["@_href"] === "string") {
      return row["@_href"] as string;
    }
  }
  return "";
}

function readAuthorName(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }
  if (Array.isArray(value)) {
    for (const entry of value) {
      const author = readAuthorName(entry);
      if (author) {
        return author;
      }
    }
    return "";
  }
  if (value && typeof value === "object") {
    const row = value as Record<string, unknown>;
    return readString(row.name) || readString(row["a10:name"]);
  }
  return "";
}

function readImageUrl(
  value: Record<string, unknown>,
  canonicalUrl: string,
): string | null {
  const candidates = [
    value["media:content"],
    value["media:thumbnail"],
    value.enclosure,
    value.image,
  ];
  for (const candidate of candidates) {
    const image = firstImageUrl(candidate, canonicalUrl);
    if (image) {
      return image;
    }
  }
  return null;
}

function firstImageUrl(value: unknown, canonicalUrl: string): string | null {
  if (Array.isArray(value)) {
    for (const entry of value) {
      const image = firstImageUrl(entry, canonicalUrl);
      if (image) {
        return image;
      }
    }
    return null;
  }
  if (value && typeof value === "object") {
    const row = value as Record<string, unknown>;
    const url = readString(row.url) || readString(row["@_url"]) ||
      readString(row.href);
    return resolveHttpUrl(url, canonicalUrl);
  }
  if (typeof value === "string") {
    return resolveHttpUrl(value, canonicalUrl);
  }
  return null;
}

export async function resolveArticleForStorage(
  article: NormalizedArticle,
  existingImageUrl: string | null,
  fetchImpl: FetchLike = fetch,
): Promise<NormalizedArticle> {
  const imageUrl = await resolveBestArticleImage(
    {
      canonicalUrl: article.canonicalUrl,
      feedImageUrl: article.imageUrl,
      existingImageUrl,
    },
    fetchImpl,
  );

  if (imageUrl === article.imageUrl) {
    return article;
  }

  return {
    ...article,
    imageUrl,
  };
}

export async function resolveBestArticleImage(
  options: {
    canonicalUrl: string;
    feedImageUrl?: string | null;
    existingImageUrl?: string | null;
  },
  fetchImpl: FetchLike = fetch,
): Promise<string | null> {
  const feedImage = resolveHttpUrl(options.feedImageUrl, options.canonicalUrl);
  if (feedImage) {
    return feedImage;
  }

  const existingImage = resolveHttpUrl(
    options.existingImageUrl,
    options.canonicalUrl,
  );
  if (existingImage) {
    return existingImage;
  }

  return await fetchArticlePageImage(options.canonicalUrl, fetchImpl);
}

async function fetchArticlePageImage(
  canonicalUrl: string,
  fetchImpl: FetchLike = fetch,
): Promise<string | null> {
  try {
    const response = await fetchWithTimeout(
      canonicalUrl,
      {
        headers: { "user-agent": NEWS_SYNC_USER_AGENT },
      },
      PAGE_IMAGE_TIMEOUT_MS,
      fetchImpl,
    );

    if (!response.ok) {
      return null;
    }

    const html = await response.text();
    return extractArticlePageImage(html, canonicalUrl);
  } catch {
    return null;
  }
}

export function extractArticlePageImage(
  html: string,
  canonicalUrl: string,
): string | null {
  const metaCandidates = [
    extractMetaContent(html, "property", "og:image"),
    extractMetaContent(html, "name", "twitter:image"),
  ];

  for (const candidate of metaCandidates) {
    const resolved = resolveHttpUrl(candidate, canonicalUrl);
    if (resolved) {
      return resolved;
    }
  }

  const linkCandidate = extractLinkHref(html, "image_src");
  return resolveHttpUrl(linkCandidate, canonicalUrl);
}

function extractMetaContent(
  html: string,
  attributeName: "property" | "name",
  attributeValue: string,
): string | null {
  for (const tag of html.matchAll(/<meta\b[^>]*>/gi)) {
    const attributes = parseTagAttributes(tag[0]);
    if (attributes.get(attributeName)?.toLowerCase() !== attributeValue) {
      continue;
    }
    const content = attributes.get("content");
    if (content) {
      return content;
    }
  }
  return null;
}

function extractLinkHref(html: string, relValue: string): string | null {
  for (const tag of html.matchAll(/<link\b[^>]*>/gi)) {
    const attributes = parseTagAttributes(tag[0]);
    const rel = attributes.get("rel")?.toLowerCase() ?? "";
    if (!rel.split(/\s+/).includes(relValue)) {
      continue;
    }
    const href = attributes.get("href");
    if (href) {
      return href;
    }
  }
  return null;
}

function parseTagAttributes(tag: string): Map<string, string> {
  const attributes = new Map<string, string>();
  const matcher =
    /([^\s"'=<>`\/]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))/g;

  for (const match of tag.matchAll(matcher)) {
    const name = match[1]?.toLowerCase().trim();
    if (!name) {
      continue;
    }
    const value = cleanText(match[2] ?? match[3] ?? match[4] ?? "");
    attributes.set(name, value);
  }

  return attributes;
}

function resolveHttpUrl(
  raw: string | null | undefined,
  baseUrl: string,
): string | null {
  const candidate = raw?.trim() ?? "";
  if (!candidate) {
    return null;
  }

  try {
    const resolved = new URL(candidate, baseUrl);
    if (resolved.protocol !== "http:" && resolved.protocol !== "https:") {
      return null;
    }
    return resolved.toString();
  } catch {
    return null;
  }
}

async function fetchWithTimeout(
  input: string,
  init: RequestInit,
  timeoutMs: number,
  fetchImpl: FetchLike,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetchImpl(input, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}

function normalizeLanguage(raw: string): string {
  const lower = raw.trim().toLowerCase();
  if (!lower) return "english";
  if (lower.startsWith("ar")) return "arabic";
  return "english";
}

function normalizeDate(raw: string): string {
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) {
    return new Date().toISOString();
  }
  return date.toISOString();
}

function canonicalizeUrl(raw: string): string {
  const parsed = new URL(raw);
  for (
    const key of [
      "utm_source",
      "utm_medium",
      "utm_campaign",
      "utm_term",
      "utm_content",
      "fbclid",
      "gclid",
    ]
  ) {
    parsed.searchParams.delete(key);
  }
  parsed.hash = "";
  return parsed.toString();
}

function cleanText(raw: string): string {
  if (!raw) return "";
  return raw
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&rsquo;/gi, "'")
    .replace(/&ldquo;/gi, '"')
    .replace(/&rdquo;/gi, '"')
    .replace(/&ndash;/gi, "-")
    .replace(/&mdash;/gi, "-")
    .replace(/\s+/g, " ")
    .trim();
}

function clipTextSafe(raw: string, maxLength: number): string {
  if (raw.length <= maxLength) {
    return raw;
  }
  return `${raw.slice(0, Math.max(0, maxLength - 3)).trim()}...`;
}

function asArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) {
    return value as T[];
  }
  if (value == null) {
    return [];
  }
  return [value as T];
}

function normalizePositiveInt(
  value: unknown,
  fallback: number,
  max: number,
): number {
  const parsed = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number.parseInt(value, 10)
    : Number.NaN;

  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }

  return Math.min(Math.trunc(parsed), max);
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
