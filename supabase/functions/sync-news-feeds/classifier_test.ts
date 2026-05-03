import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  classifyArticle,
  type NewsSourceRow,
  type NormalizedArticle,
} from "./classifier.ts";

const trustedSource: NewsSourceRow = {
  id: "source-1",
  name: "NIH News Releases",
  base_url: "https://www.nih.gov",
  feed_url: "https://www.nih.gov/news-releases/feed.xml",
  api_endpoint: null,
  source_type: "rss",
  language: "english",
  country: "US",
  category: "research_news",
  is_active: true,
  trust_score: 92,
  source_weight: 1,
};

function article(
  overrides: Partial<NormalizedArticle> = {},
): NormalizedArticle {
  return {
    canonicalUrl: "https://example.org/article",
    externalId: "external-1",
    title: "Strength training study highlights protein timing and muscle gains",
    summary:
      "Researchers reviewed resistance training outcomes, protein intake, recovery markers, and practical nutrition habits in adults training consistently.",
    content:
      "A new study examined resistance training, muscle protein synthesis, recovery, healthy eating patterns, and how structured meal timing supports long-term strength progress for active adults.",
    authorName: "GymUnity Test",
    imageUrl: "https://example.org/image.jpg",
    publishedAt: "2026-03-15T12:00:00Z",
    fetchedAt: "2026-03-16T12:00:00Z",
    language: "english",
    rawCategory: "research_news",
    tags: ["strength", "nutrition"],
    ...overrides,
  };
}

Deno.test("classifyArticle maps muscle and nutrition articles to member goals safely", () => {
  const result = classifyArticle(trustedSource, article());

  assertEquals(result.safetyLevel, "general");
  assertEquals(result.evidenceLevel, "expert_reviewed");
  assertEquals(result.targetRoles.includes("member"), true);
  assertEquals(result.targetGoals.includes("muscle_gain"), true);
  assertEquals(
    result.topics.some((topic) => topic.topicCode === "muscle_gain"),
    true,
  );
  assertEquals(
    result.topics.some((topic) => topic.topicCode === "nutrition_basics"),
    true,
  );
  assertEquals(result.trustScore >= 90, true);
  assertEquals(result.qualityScore >= 70, true);
});

Deno.test("classifyArticle flags obviously unsafe miracle-cure claims as restricted", () => {
  const result = classifyArticle(
    trustedSource,
    article({
      title: "Miracle cure claims you can drop 20 pounds in 7 days",
      summary:
        "This extreme diet says it can replace your doctor and detox everything instantly.",
      content:
        "A miracle cure and detox tea plan promises rapid results and asks readers to self-diagnose.",
    }),
  );

  assertEquals(result.safetyLevel, "restricted");
  assertEquals(result.trustScore < trustedSource.trust_score, true);
});

Deno.test("classifyArticle detects beginner-friendly mobility guidance", () => {
  const result = classifyArticle(
    trustedSource,
    article({
      title: "Beginner mobility routine helps improve range of motion",
      summary:
        "New to exercise? A beginner stretching routine can support joint health and recovery.",
      content:
        "This beginner routine covers stretching, flexibility, warm-up habits, and safe progression.",
      rawCategory: "health_education",
    }),
  );

  assertExists(result.topics.find((topic) => topic.topicCode === "mobility"));
  assertExists(
    result.topics.find((topic) => topic.topicCode === "beginner_training"),
  );
  assertEquals(result.targetLevels.includes("beginner"), true);
  assertEquals(result.targetRoles.includes("member"), true);
});

Deno.test("classifyArticle keeps broad public-health crisis reporting out of fitness goal buckets", () => {
  const result = classifyArticle(
    {
      ...trustedSource,
      name: "WHO News (English)",
      base_url: "https://www.who.int",
      feed_url: "https://www.who.int/rss-feeds/news-english.xml",
      category: "public_health",
      trust_score: 90,
    },
    article({
      title:
        "Sudan: 1000 days of war deepen the world’s worst health and humanitarian crisis",
      summary:
        "Over 20 million people now need health assistance and food support as the conflict continues across Sudan.",
      content:
        "WHO warns that health facilities are damaged, humanitarian access is constrained, and emergency response capacity remains under severe pressure.",
      rawCategory: "public_health",
      tags: [],
    }),
  );

  assertEquals(result.topics, [{ topicCode: "general_wellness", score: 0.45 }]);
  assertEquals(result.targetGoals, ["general_fitness"]);
  assertEquals(result.targetRoles.includes("member"), true);
  assertEquals(result.evidenceLevel, "source_reported");
});
