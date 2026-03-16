import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

import type { NormalizedArticle } from "./classifier.ts";
import { resolveArticleForStorage } from "./index.ts";

function article(
  overrides: Partial<NormalizedArticle> = {},
): NormalizedArticle {
  return {
    canonicalUrl: "https://example.org/articles/recovery-basics",
    externalId: "article-1",
    title: "Recovery basics for consistent training",
    summary: "A trusted explainer on sleep, hydration, and recovery.",
    content: "A trusted explainer on sleep, hydration, and recovery.",
    authorName: "GymUnity Test",
    imageUrl: null,
    publishedAt: "2026-03-16T12:00:00Z",
    fetchedAt: "2026-03-16T12:00:00Z",
    language: "english",
    rawCategory: "health_education",
    tags: ["recovery", "sleep"],
    ...overrides,
  };
}

function htmlResponse(html: string): Response {
  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
    },
  });
}

Deno.test("resolveArticleForStorage keeps RSS image and skips page fallback", async () => {
  let fetchCalls = 0;

  const result = await resolveArticleForStorage(
    article({ imageUrl: "https://cdn.example.org/feed-image.jpg" }),
    null,
    (async () => {
      fetchCalls += 1;
      return htmlResponse("<html></html>");
    }) as typeof fetch,
  );

  assertEquals(result.imageUrl, "https://cdn.example.org/feed-image.jpg");
  assertEquals(fetchCalls, 0);
});

Deno.test("resolveArticleForStorage fills missing image from og:image", async () => {
  const result = await resolveArticleForStorage(
    article(),
    null,
    (async () =>
      htmlResponse(
        '<html><head><meta property="og:image" content="https://cdn.example.org/hero.jpg"></head></html>',
      )) as typeof fetch,
  );

  assertEquals(result.imageUrl, "https://cdn.example.org/hero.jpg");
});

Deno.test("resolveArticleForStorage resolves relative og:image urls", async () => {
  const result = await resolveArticleForStorage(
    article({ canonicalUrl: "https://example.org/news/recovery-basics" }),
    null,
    (async () =>
      htmlResponse(
        '<html><head><meta property="og:image" content="/images/recovery-hero.png"></head></html>',
      )) as typeof fetch,
  );

  assertEquals(result.imageUrl, "https://example.org/images/recovery-hero.png");
});

Deno.test("resolveArticleForStorage tolerates page fetch failures", async () => {
  const result = await resolveArticleForStorage(
    article(),
    null,
    (async () => {
      throw new Error("network failed");
    }) as typeof fetch,
  );

  assertEquals(result.imageUrl, null);
});

Deno.test("resolveArticleForStorage preserves existing stored image when no new image exists", async () => {
  let fetchCalls = 0;

  const result = await resolveArticleForStorage(
    article(),
    "https://cdn.example.org/stored-image.jpg",
    (async () => {
      fetchCalls += 1;
      return htmlResponse("<html></html>");
    }) as typeof fetch,
  );

  assertEquals(result.imageUrl, "https://cdn.example.org/stored-image.jpg");
  assertEquals(fetchCalls, 0);
});
