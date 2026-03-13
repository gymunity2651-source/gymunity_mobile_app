import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type DeleteAccountPayload = {
  current_password?: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

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

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: authData, error: authError } = await supabase.auth.getUser(
      token,
    );
    if (authError || !authData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const payload = (await req.json().catch(() => ({}))) as DeleteAccountPayload;
    const provider =
      authData.user.app_metadata?.provider ??
      authData.user.identities?.[0]?.provider ??
      "email";

    if (provider === "email" && !payload.current_password?.trim()) {
      return jsonResponse(
        { error: "Current password confirmation is required." },
        400,
      );
    }

    const deletedEmail =
      `deleted+${authData.user.id.replaceAll("-", "")}` +
      "@deleted.gymunity.invalid";

    const { error: deleteError } = await supabase.rpc("soft_delete_account", {
      target_user_id: authData.user.id,
      deleted_email: deletedEmail,
    });
    if (deleteError) {
      return jsonResponse({ error: deleteError.message }, 500);
    }

    await removeAvatarFiles(supabase, authData.user.id);

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
});

async function removeAvatarFiles(
  supabase: ReturnType<typeof createClient>,
  userId: string,
) {
  const avatarPrefix = `avatars/${userId}`;
  const { data: files, error } = await supabase.storage.from("avatars").list(
    avatarPrefix,
    {
      limit: 100,
      offset: 0,
    },
  );

  if (error || !files || files.length === 0) {
    return;
  }

  const removablePaths = files
    .filter((file) => !!file.name)
    .map((file) => `${avatarPrefix}/${file.name}`);
  if (removablePaths.length == 0) {
    return;
  }

  await supabase.storage.from("avatars").remove(removablePaths);
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
