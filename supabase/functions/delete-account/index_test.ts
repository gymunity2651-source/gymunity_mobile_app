import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { handleDeleteAccountRequest } from "./index.ts";

type RecordedRemove = {
  bucket: string;
  paths: string[];
};

function createMockClient(options?: {
  provider?: string;
  filesByBucketAndPrefix?: Record<string, Record<string, Array<Record<string, unknown>>>>;
}) {
  const rpcCalls: Array<{ fn: string; params?: Record<string, unknown> }> = [];
  const removed: RecordedRemove[] = [];
  const deletedUsers: string[] = [];

  const filesByBucketAndPrefix = options?.filesByBucketAndPrefix ?? {
    "avatars": {
      "avatars/user-1": [
        { name: "avatar.png", id: "avatar-1", metadata: {} },
      ],
    },
    "product-images": {
      "user-1": [{ name: "product-1" }],
      "user-1/product-1": [
        { name: "image.png", id: "product-image-1", metadata: {} },
      ],
    },
  };

  return {
    client: {
      auth: {
        getUser: async () => ({
          data: {
            user: {
              id: "user-1",
              app_metadata: { provider: options?.provider ?? "email" },
              identities: [{ provider: options?.provider ?? "email" }],
            },
          },
          error: null,
        }),
        admin: {
          deleteUser: async (userId: string) => {
            deletedUsers.push(userId);
            return { data: null, error: null };
          },
        },
      },
      rpc: async (fn: string, params?: Record<string, unknown>) => {
        rpcCalls.push({ fn, params });
        return { data: { ok: true }, error: null };
      },
      storage: {
        from: (bucket: string) => ({
          list: async (path = "") => ({
            data: (filesByBucketAndPrefix[bucket]?.[path] ?? []) as Array<
              Record<string, unknown>
            >,
            error: null,
          }),
          remove: async (paths: string[]) => {
            removed.push({ bucket, paths });
            return { data: null, error: null };
          },
        }),
      },
    },
    rpcCalls,
    removed,
    deletedUsers,
  };
}

Deno.test("delete-account prepares data, removes storage files, and deletes auth user", async () => {
  const mock = createMockClient();

  const response = await handleDeleteAccountRequest(
    new Request("https://example.com/delete-account", {
      method: "POST",
      headers: {
        "Authorization": "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ current_password: "Password123" }),
    }),
    {
      client: mock.client,
      getEnv: (name: string) =>
        name === "SUPABASE_URL" ? "https://example.supabase.co" : "service-role",
    },
  );

  assertEquals(response.status, 200);
  assertEquals(mock.rpcCalls, [{
    fn: "prepare_account_for_hard_delete",
    params: { target_user_id: "user-1" },
  }]);
  assertEquals(mock.deletedUsers, ["user-1"]);
  assertEquals(mock.removed, [
    { bucket: "avatars", paths: ["avatars/user-1/avatar.png"] },
    { bucket: "product-images", paths: ["user-1/product-1/image.png"] },
  ]);

  const body = await response.json();
  assertEquals(body, {
    success: true,
    user_id: "user-1",
    provider: "email",
  });
});

Deno.test("delete-account rejects email accounts without current password confirmation", async () => {
  const mock = createMockClient();

  const response = await handleDeleteAccountRequest(
    new Request("https://example.com/delete-account", {
      method: "POST",
      headers: {
        "Authorization": "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({}),
    }),
    {
      client: mock.client,
      getEnv: (name: string) =>
        name === "SUPABASE_URL" ? "https://example.supabase.co" : "service-role",
    },
  );

  assertEquals(response.status, 400);
  assertEquals(mock.rpcCalls.length, 0);
  assertEquals(mock.deletedUsers.length, 0);
});
