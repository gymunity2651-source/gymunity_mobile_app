export type NewsSourceRow = {
  id: string;
  name: string;
  base_url: string;
  feed_url: string | null;
  api_endpoint: string | null;
  source_type: string;
  language: string;
  country: string | null;
  category: string | null;
  is_active: boolean;
  trust_score: number;
  source_weight: number;
};

export type NormalizedArticle = {
  canonicalUrl: string;
  externalId: string | null;
  title: string;
  summary: string;
  content: string | null;
  authorName: string | null;
  imageUrl: string | null;
  publishedAt: string;
  fetchedAt: string;
  language: string;
  rawCategory: string | null;
  tags: string[];
};

export type ArticleTopic = {
  topicCode: string;
  score: number;
};

export type ClassifiedArticle = {
  category: string | null;
  topics: ArticleTopic[];
  targetRoles: string[];
  targetGoals: string[];
  targetLevels: string[];
  trustScore: number;
  evidenceLevel: "expert_reviewed" | "source_reported" | "educational" | "unknown";
  safetyLevel: "general" | "caution" | "restricted";
  qualityScore: number;
  isFeatured: boolean;
  ingestionNotes: string | null;
};

type TopicRule = {
  topicCode: string;
  keywords: string[];
  baseScore: number;
};

const TOPIC_RULES: TopicRule[] = [
  {
    topicCode: "muscle_gain",
    keywords: ["muscle", "hypertrophy", "strength", "lean mass", "resistance training", "protein synthesis"],
    baseScore: 0.62,
  },
  {
    topicCode: "fat_loss",
    keywords: ["fat loss", "lose weight", "weight loss", "body composition", "calorie deficit", "obesity"],
    baseScore: 0.66,
  },
  {
    topicCode: "recovery",
    keywords: ["recovery", "rest day", "deload", "soreness", "fatigue", "overtraining"],
    baseScore: 0.56,
  },
  {
    topicCode: "sleep",
    keywords: ["sleep", "circadian", "bedtime", "insomnia", "sleep quality"],
    baseScore: 0.55,
  },
  {
    topicCode: "hydration",
    keywords: ["hydration", "electrolyte", "dehydration", "fluid intake", "water intake"],
    baseScore: 0.54,
  },
  {
    topicCode: "beginner_training",
    keywords: ["beginner", "starting out", "new to exercise", "first workout", "novice"],
    baseScore: 0.64,
  },
  {
    topicCode: "mobility",
    keywords: ["mobility", "flexibility", "range of motion", "joint health", "stretching"],
    baseScore: 0.58,
  },
  {
    topicCode: "injury_prevention",
    keywords: ["injury prevention", "prevent injury", "safe form", "pain management", "warm-up", "rehab"],
    baseScore: 0.62,
  },
  {
    topicCode: "nutrition_basics",
    keywords: [
      "nutrition",
      "protein intake",
      "dietary protein",
      "meal protein",
      "fiber",
      "meal planning",
      "healthy eating",
      "diet quality",
    ],
    baseScore: 0.57,
  },
  {
    topicCode: "workout_consistency",
    keywords: ["consistency", "habit", "routine", "motivation", "adherence", "streak"],
    baseScore: 0.52,
  },
  {
    topicCode: "heart_health",
    keywords: ["heart health", "blood pressure", "cardiovascular", "cholesterol", "aerobic"],
    baseScore: 0.55,
  },
  {
    topicCode: "general_wellness",
    keywords: ["wellness", "healthy living", "preventive health", "well-being", "public health"],
    baseScore: 0.48,
  },
  {
    topicCode: "endurance",
    keywords: ["endurance", "cardio", "running", "stamina", "aerobic capacity", "vo2"],
    baseScore: 0.60,
  },
  {
    topicCode: "strength_training",
    keywords: ["strength training", "lifting", "resistance", "compound lift", "progressive overload"],
    baseScore: 0.58,
  },
];

const RESTRICTED_PATTERNS = [
  /miracle cure/i,
  /cure[- ]all/i,
  /detox tea/i,
  /drop\s+\d+\s*(?:lb|lbs|pounds|kg)\s+in\s+\d+\s+days/i,
  /starve/i,
  /self-diagnos/i,
  /replace your doctor/i,
];

const CAUTION_PATTERNS = [
  /biohack/i,
  /rapid results/i,
  /fat[- ]burning supplement/i,
  /unproven/i,
  /treat yourself/i,
  /extreme diet/i,
  /cleanse/i,
];

const CLICKBAIT_PATTERNS = [
  /you won't believe/i,
  /shocking/i,
  /secret to/i,
  /instant/i,
  /overnight/i,
];

const PUBLIC_HEALTH_GENERAL_ONLY_PATTERNS = [
  /humanitarian/i,
  /\bwar\b/i,
  /\bconflict\b/i,
  /health care attack/i,
  /violence/i,
  /outbreak/i,
  /epidemic/i,
  /pandemic/i,
  /emergency response/i,
  /health assistance/i,
  /food support/i,
  /\bcrisis\b/i,
];

export function classifyArticle(
  source: NewsSourceRow,
  article: NormalizedArticle,
): ClassifiedArticle {
  const combinedText = [
    article.title,
    article.summary,
    article.content ?? "",
    article.rawCategory ?? "",
    article.tags.join(" "),
    source.category ?? "",
  ]
    .join(" ")
    .toLowerCase();

  const notes: string[] = [];
  const topics = shouldCollapseToGeneralWellness(source, combinedText)
    ? [{ topicCode: "general_wellness", score: 0.45 }]
    : classifyTopics(combinedText, article.tags);
  const targetGoals = deriveTargetGoals(topics);
  const targetLevels = deriveTargetLevels(combinedText);
  const targetRoles = deriveTargetRoles(combinedText, source.category ?? "", topics);
  const evidenceLevel = deriveEvidenceLevel(source, combinedText);
  const safetyLevel = deriveSafetyLevel(combinedText);
  const trustScore = deriveTrustScore(source, article, evidenceLevel, safetyLevel, combinedText);
  const qualityScore = deriveQualityScore(article, combinedText, topics);
  const category = deriveCategory(source, topics);
  const isFeatured =
    safetyLevel === "general" &&
    trustScore >= 88 &&
    qualityScore >= 80 &&
    isRecent(article.publishedAt, 5);

  if (safetyLevel !== "general") {
    notes.push(`safety:${safetyLevel}`);
  }
  if (evidenceLevel !== "unknown") {
    notes.push(`evidence:${evidenceLevel}`);
  }
  if (targetGoals.length > 0) {
    notes.push(`goals:${targetGoals.join(",")}`);
  }

  return {
    category,
    topics,
    targetRoles,
    targetGoals,
    targetLevels,
    trustScore,
    evidenceLevel,
    safetyLevel,
    qualityScore,
    isFeatured,
    ingestionNotes: notes.length > 0 ? notes.join(" | ") : null,
  };
}

function classifyTopics(text: string, tags: string[]): ArticleTopic[] {
  const tagText = tags.join(" ").toLowerCase();
  const matches = TOPIC_RULES.map((rule) => {
    const hitCount = rule.keywords.filter((keyword) =>
      matchesKeyword(text, keyword) || matchesKeyword(tagText, keyword)
    ).length;
    if (hitCount <= 0) {
      return null;
    }
    const score = clamp(rule.baseScore + (hitCount - 1) * 0.12, 0.35, 0.96);
    return {
      topicCode: rule.topicCode,
      score: round(score),
    } satisfies ArticleTopic;
  }).filter((value): value is ArticleTopic => value !== null);

  if (matches.length > 0) {
    return dedupeTopics(matches);
  }

  return [{ topicCode: "general_wellness", score: 0.45 }];
}

function deriveTargetGoals(topics: ArticleTopic[]): string[] {
  const goals = new Set<string>();
  for (const topic of topics) {
    switch (topic.topicCode) {
      case "muscle_gain":
      case "strength_training":
        goals.add("muscle_gain");
        break;
      case "fat_loss":
      case "nutrition_basics":
        goals.add("fat_loss");
        break;
      case "endurance":
      case "heart_health":
        goals.add("endurance");
        break;
      case "mobility":
      case "injury_prevention":
        goals.add("mobility");
        break;
      case "recovery":
      case "sleep":
      case "hydration":
        goals.add("recovery");
        break;
      default:
        goals.add("general_fitness");
        break;
    }
  }
  if (goals.size === 0) {
    goals.add("general_fitness");
  }
  return [...goals];
}

function deriveTargetLevels(text: string): string[] {
  const levels = new Set<string>();
  if (text.includes("beginner") || text.includes("starting out") || text.includes("new to exercise")) {
    levels.add("beginner");
  }
  if (text.includes("intermediate")) {
    levels.add("intermediate");
  }
  if (text.includes("advanced") || text.includes("elite") || text.includes("athlete")) {
    levels.add("advanced");
  }
  if (levels.size === 0) {
    levels.add("all");
  }
  return [...levels];
}

function deriveTargetRoles(
  text: string,
  sourceCategory: string,
  topics: ArticleTopic[],
): string[] {
  const roles = new Set<string>();
  const coachSignals = [
    "exercise science",
    "coaching",
    "client adherence",
    "programming",
    "periodization",
  ];
  const sellerSignals = ["marketplace", "retail", "commerce", "product trend"];

  if (coachSignals.some((signal) => text.includes(signal))) {
    roles.add("coach");
  }
  if (sellerSignals.some((signal) => text.includes(signal))) {
    roles.add("seller");
  }

  if (
    sourceCategory === "health_education" ||
    sourceCategory === "public_health" ||
    topics.some((topic) =>
      [
        "general_wellness",
        "nutrition_basics",
        "fat_loss",
        "muscle_gain",
        "recovery",
        "sleep",
        "hydration",
        "mobility",
      ].includes(topic.topicCode)
    )
  ) {
    roles.add("member");
  }

  if (roles.size === 0) {
    roles.add("member");
  }
  return [...roles];
}

function deriveEvidenceLevel(
  source: NewsSourceRow,
  text: string,
): ClassifiedArticle["evidenceLevel"] {
  if (
    source.category === "research_news" ||
    text.includes("study") ||
    text.includes("trial") ||
    text.includes("guideline") ||
    text.includes("researchers") ||
    text.includes("systematic review")
  ) {
    return "expert_reviewed";
  }
  if (source.category === "health_education") {
    return "educational";
  }
  if (source.category === "public_health" || text.includes("press release")) {
    return "source_reported";
  }
  return "unknown";
}

function deriveSafetyLevel(text: string): ClassifiedArticle["safetyLevel"] {
  if (RESTRICTED_PATTERNS.some((pattern) => pattern.test(text))) {
    return "restricted";
  }
  if (CAUTION_PATTERNS.some((pattern) => pattern.test(text))) {
    return "caution";
  }
  return "general";
}

function deriveTrustScore(
  source: NewsSourceRow,
  article: NormalizedArticle,
  evidenceLevel: ClassifiedArticle["evidenceLevel"],
  safetyLevel: ClassifiedArticle["safetyLevel"],
  text: string,
): number {
  let score = source.trust_score;

  if (evidenceLevel === "expert_reviewed") score += 4;
  if (evidenceLevel === "educational") score += 3;
  if (article.authorName) score += 2;
  if (article.summary.length >= 120) score += 2;
  if ((article.content ?? "").length >= 500) score += 2;
  if (CLICKBAIT_PATTERNS.some((pattern) => pattern.test(text))) score -= 10;
  if (safetyLevel === "caution") score -= 8;
  if (safetyLevel === "restricted") score -= 25;

  return round(clamp(score, 0, 100));
}

function deriveQualityScore(
  article: NormalizedArticle,
  text: string,
  topics: ArticleTopic[],
): number {
  let score = 48;

  if (article.summary.length >= 120) score += 14;
  if ((article.content ?? "").length >= 500) score += 12;
  if (article.imageUrl) score += 4;
  if (article.authorName) score += 4;
  if (article.publishedAt) score += 5;
  if (topics.length >= 1 && topics.length <= 4) score += 6;
  if (article.title.length < 18) score -= 8;
  if (CLICKBAIT_PATTERNS.some((pattern) => pattern.test(text))) score -= 14;
  if (article.title === article.title.toUpperCase() && article.title.length > 18) score -= 10;

  return round(clamp(score, 0, 100));
}

function deriveCategory(
  source: NewsSourceRow,
  topics: ArticleTopic[],
): string | null {
  if (source.category) {
    return source.category;
  }

  const leadTopic = topics[0]?.topicCode;
  switch (leadTopic) {
    case "nutrition_basics":
    case "hydration":
      return "nutrition";
    case "muscle_gain":
    case "strength_training":
    case "beginner_training":
      return "training";
    case "recovery":
    case "sleep":
    case "mobility":
      return "recovery";
    case "heart_health":
    case "general_wellness":
      return "wellness";
    default:
      return "wellness";
  }
}

function dedupeTopics(topics: ArticleTopic[]): ArticleTopic[] {
  const seen = new Map<string, number>();
  for (const topic of topics) {
    const previous = seen.get(topic.topicCode);
    if (previous == null || topic.score > previous) {
      seen.set(topic.topicCode, topic.score);
    }
  }
  return [...seen.entries()]
    .map(([topicCode, score]) => ({ topicCode, score: round(score) }))
    .sort((left, right) => right.score - left.score || left.topicCode.localeCompare(right.topicCode));
}

function shouldCollapseToGeneralWellness(
  source: NewsSourceRow,
  text: string,
): boolean {
  return source.category === "public_health" &&
    PUBLIC_HEALTH_GENERAL_ONLY_PATTERNS.some((pattern) => pattern.test(text));
}

function matchesKeyword(text: string, keyword: string): boolean {
  const normalizedText = normalizeMatcherText(text);
  const normalizedKeyword = normalizeMatcherText(keyword);

  if (!normalizedText || !normalizedKeyword) {
    return false;
  }

  if (normalizedKeyword.includes(" ")) {
    return normalizedText.includes(normalizedKeyword);
  }

  const textTokens = new Set(normalizedText.split(" ").filter(Boolean));
  return textTokens.has(normalizedKeyword);
}

function normalizeMatcherText(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function isRecent(isoDate: string, days: number): boolean {
  const publishedAt = new Date(isoDate);
  if (Number.isNaN(publishedAt.getTime())) {
    return false;
  }
  const ageMs = Date.now() - publishedAt.getTime();
  return ageMs <= days * 24 * 60 * 60 * 1000;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function round(value: number): number {
  return Math.round(value * 1000) / 1000;
}
