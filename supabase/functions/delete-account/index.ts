import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type DeleteAccountPayload = {
  current_password?: string;
};

type DeleteAccountProvider = "email" | string;

type AuthenticatedUser = {
  id: string;
  app_metadata?: { provider?: string | null } | null;
  identities?: Array<{ provider?: string | null }> | null;
};

type StorageListEntry = {
  name?: string | null;
  id?: string | null;
  metadata?: Record<string, unknown> | null;
};

type StorageBucketApi = {
  list: (
    path?: string,
    options?: { limit?: number; offset?: number },
  ) => Promise<{ data: StorageListEntry[] | null; error: { message: string } | null }>;
  remove: (
    paths: string[],
  ) => Promise<{ data: unknown; error: { message: string } | null }>;
};

type DeleteAccountClient = {
  auth: {
    getUser: (
      token: string,
    ) => Promise<{
      data: { user: AuthenticatedUser | null };
      error: { message: string } | null;
    }>;
    admin: {
      deleteUser: (
        userId: string,
      ) => Promise<{ data: unknown; error: { message: string } | null }>;
    };
  };
  rpc: (
    fn: string,
    params?: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: { message: string } | null }>;
  storage: {
    from: (bucket: string) => StorageBucketApi;
  };
};

type DeleteAccountDeps = {
  client?: DeleteAccountClient;
  getEnv?: (name: string) => string | undefined;
};

export async function handleDeleteAccountRequest(
  req: Request,
  deps: DeleteAccountDeps = {},
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const getEnv = deps.getEnv ?? ((name: string) => Deno.env.get(name));
    const supabaseUrl = getEnv("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return jsonResponse(
        {
          error:
            "Missing required env vars: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY",
        },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "").trim();
    if (!token) {
      return jsonResponse({ error: "Missing auth token" }, 401);
    }

    const supabase = deps.client ?? createDeleteAccountClient(
      supabaseUrl,
      supabaseServiceRoleKey,
    );

    const { data: authData, error: authError } = await supabase.auth.getUser(
      token,
    );
    if (authError || !authData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const payload = (await req.json().catch(() => ({}))) as DeleteAccountPayload;
    const provider = resolveProvider(authData.user);
    if (provider === "email" && !payload.current_password?.trim()) {
      return jsonResponse(
        { error: "Current password confirmation is required." },
        400,
      );
    }

    const { error: prepareError } = await supabase.rpc(
      "prepare_account_for_hard_delete",
      {
        target_user_id: authData.user.id,
      },
    );
    if (prepareError) {
      return jsonResponse({ error: prepareError.message }, 500);
    }

    await removeUserStorageFiles(supabase, authData.user.id);

    const { error: deleteUserError } = await supabase.auth.admin.deleteUser(
      authData.user.id,
    );
    if (deleteUserError) {
      return jsonResponse({ error: deleteUserError.message }, 500);
    }

    return jsonResponse({
      success: true,
      user_id: authData.user.id,
      provider,
    });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
}

export function createDeleteAccountClient(
  supabaseUrl: string,
  supabaseServiceRoleKey: string,
): DeleteAccountClient {
  return createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false },
  }) as unknown as DeleteAccountClient;
}

export function resolveProvider(user: AuthenticatedUser): DeleteAccountProvider {
  return user.app_metadata?.provider ??
    user.identities?.[0]?.provider ??
    "email";
}

export async function removeUserStorageFiles(
  supabase: DeleteAccountClient,
  userId: string,
) {
  await removeBucketPrefix(supabase, "avatars", `avatars/${userId}`);
  await removeBucketPrefix(supabase, "product-images", userId);
}

async function removeBucketPrefix(
  supabase: DeleteAccountClient,
  bucket: string,
  prefix: string,
) {
  const bucketApi = supabase.storage.from(bucket);
  const removablePaths = await collectRemovablePaths(bucketApi, prefix);
  if (removablePaths.length === 0) {
    return;
  }

  for (let i = 0; i < removablePaths.length; i += 100) {
    const batch = removablePaths.slice(i, i + 100);
    const { error } = await bucketApi.remove(batch);
    if (error) {
      throw new Error(error.message);
    }
  }
}

async function collectRemovablePaths(
  bucketApi: StorageBucketApi,
  prefix: string,
): Promise<string[]> {
  const { data, error } = await bucketApi.list(prefix, {
    limit: 100,
    offset: 0,
  });

  if (error) {
    throw new Error(error.message);
  }
  if (!data || data.length === 0) {
    return [];
  }

  const removablePaths: string[] = [];
  for (const entry of data) {
    const name = entry.name?.trim();
    if (!name) {
      continue;
    }

    const childPath = `${prefix}/${name}`;
    if (isFolderEntry(entry)) {
      const nested = await collectRemovablePaths(bucketApi, childPath);
      removablePaths.push(...nested);
      continue;
    }

    removablePaths.push(childPath);
  }

  return removablePaths;
}

function isFolderEntry(entry: StorageListEntry): boolean {
  return entry.id == null && entry.metadata == null;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

if (import.meta.main) {
  Deno.serve((req) => handleDeleteAccountRequest(req));
}
