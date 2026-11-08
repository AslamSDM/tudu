import { describe, expect, it } from "vitest";
import { exports } from "cloudflare:workers";

const KEY_A = "a".repeat(43);
const KEY_B = "b".repeat(43);

function todo(overrides: Record<string, unknown> = {}) {
  return {
    id: crypto.randomUUID(),
    title: "Buy milk",
    notes: "",
    isCompleted: false,
    priority: 1,
    dueDate: null,
    tags: ["home"],
    createdAt: 1_000,
    updatedAt: 1_000,
    completedAt: null,
    deletedAt: null,
    ...overrides,
  };
}

async function sync(key: string, body: unknown) {
  const res = await (exports as any).default.fetch("https://tudu.test/v1/sync", {
    method: "POST",
    headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: (await res.json()) as any };
}

describe("tudu sync", () => {
  it("health is public", async () => {
    const res = await (exports as any).default.fetch("https://tudu.test/v1/health");
    expect(await res.json()).toEqual({ ok: true });
  });

  it("rejects bad keys", async () => {
    expect((await sync("short", { cursor: 0, changes: [] })).status).toBe(401);
  });

  it("round-trips and isolates spaces", async () => {
    const t = todo();
    const first = await sync(KEY_A, { cursor: 0, changes: [t] });
    expect(first.status).toBe(200);
    expect(first.body.changes).toEqual([t]);
    expect(first.body.cursor).toBe(1);

    const other = await sync(KEY_B, { cursor: 0, changes: [] });
    expect(other.body.changes).toEqual([]);

    const again = await sync(KEY_A, { cursor: first.body.cursor, changes: [] });
    expect(again.body.changes).toEqual([]);
  });

  it("applies last-write-wins", async () => {
    const key = "c".repeat(40);
    const t = todo({ updatedAt: 5_000 });
    await sync(key, { cursor: 0, changes: [t] });

    const stale = await sync(key, { cursor: 0, changes: [{ ...t, title: "old", updatedAt: 4_000 }] });
    expect(stale.body.changes[0].title).toBe("Buy milk");

    const tie = await sync(key, { cursor: 0, changes: [{ ...t, title: "tie", updatedAt: 5_000 }] });
    expect(tie.body.changes[0].title).toBe("Buy milk");

    const newer = await sync(key, {
      cursor: 1,
      changes: [{ ...t, title: "done", isCompleted: true, updatedAt: 6_000, deletedAt: 6_000 }],
    });
    expect(newer.body.cursor).toBe(2);
    expect(newer.body.changes).toHaveLength(1);
    expect(newer.body.changes[0]).toMatchObject({ title: "done", isCompleted: true, deletedAt: 6_000 });
  });

  it("validates payloads", async () => {
    expect((await sync(KEY_A, { cursor: 0, changes: [todo({ id: "nope" })] })).status).toBe(400);
    expect((await sync(KEY_A, { cursor: 0, changes: [todo({ priority: 7 })] })).status).toBe(400);
    expect((await sync(KEY_A, { cursor: 0, changes: [todo({ updatedAt: 1.5 })] })).status).toBe(400);
    const many = Array.from({ length: 501 }, () => todo());
    expect((await sync(KEY_A, { cursor: 0, changes: many })).status).toBe(413);
  });

  it("lowercases ids and resets cursors from the future", async () => {
    const key = "d".repeat(40);
    const id = crypto.randomUUID().toUpperCase();
    const res = await sync(key, { cursor: 999, changes: [todo({ id })] });
    expect(res.body.changes[0].id).toBe(id.toLowerCase());
  });
});
