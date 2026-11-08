import { DurableObject } from "cloudflare:workers";

export interface Env {
  SPACES: DurableObjectNamespace<SyncSpace>;
}

/** Wire format, see docs/SYNC_API.md. Timestamps are ms since the Unix epoch. */
export interface WireTodo {
  id: string;
  title: string;
  notes: string;
  isCompleted: boolean;
  priority: number;
  dueDate: number | null;
  tags: string[];
  createdAt: number;
  updatedAt: number;
  completedAt: number | null;
  deletedAt: number | null;
}

export interface SyncResult {
  cursor: number;
  changes: WireTodo[];
  serverTime: number;
}

export const MAX_CHANGES = 500;
const MAX_BODY_BYTES = 4 * 1024 * 1024;
const KEY_PATTERN = /^[A-Za-z0-9_-]{32,128}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

async function spaceIdFor(key: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(key));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// MARK: - Validation

function isTimestamp(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
}

function optionalTimestamp(value: unknown, field: string): number | null {
  if (value === null || value === undefined) return null;
  if (!isTimestamp(value)) throw new HttpError(400, `${field} must be an integer ms timestamp or null`);
  return value;
}

function boundedString(value: unknown, field: string, max: number, fallback?: string): string {
  if (value === undefined && fallback !== undefined) return fallback;
  if (typeof value !== "string") throw new HttpError(400, `${field} must be a string`);
  if (value.length > max) throw new HttpError(400, `${field} is too long`);
  return value;
}

export function parseTodo(raw: unknown): WireTodo {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    throw new HttpError(400, "each change must be an object");
  }
  const t = raw as Record<string, unknown>;

  const id = boundedString(t.id, "id", 36).toLowerCase();
  if (!UUID_PATTERN.test(id)) throw new HttpError(400, "id must be a UUID");

  if (!isTimestamp(t.createdAt)) throw new HttpError(400, "createdAt must be an integer ms timestamp");
  if (!isTimestamp(t.updatedAt)) throw new HttpError(400, "updatedAt must be an integer ms timestamp");

  const priority = t.priority ?? 1;
  if (priority !== 0 && priority !== 1 && priority !== 2) throw new HttpError(400, "priority must be 0, 1 or 2");

  const tagsRaw = t.tags ?? [];
  if (!Array.isArray(tagsRaw) || tagsRaw.length > 50) throw new HttpError(400, "tags must be an array (max 50)");
  const tags = tagsRaw.map((tag) => boundedString(tag, "tag", 100));

  return {
    id,
    title: boundedString(t.title, "title", 2_000),
    notes: boundedString(t.notes, "notes", 50_000, ""),
    isCompleted: t.isCompleted === true,
    priority,
    dueDate: optionalTimestamp(t.dueDate, "dueDate"),
    tags,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    completedAt: optionalTimestamp(t.completedAt, "completedAt"),
    deletedAt: optionalTimestamp(t.deletedAt, "deletedAt"),
  };
}

function parseSyncBody(body: unknown): { cursor: number; changes: WireTodo[] } {
  if (typeof body !== "object" || body === null) throw new HttpError(400, "body must be a JSON object");
  const b = body as Record<string, unknown>;
  const cursor = b.cursor ?? 0;
  if (!isTimestamp(cursor)) throw new HttpError(400, "cursor must be a non-negative integer");
  const changes = b.changes ?? [];
  if (!Array.isArray(changes)) throw new HttpError(400, "changes must be an array");
  if (changes.length > MAX_CHANGES) throw new HttpError(413, `send at most ${MAX_CHANGES} changes per request`);
  return { cursor, changes: changes.map(parseTodo) };
}

// MARK: - Worker entry

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    try {
      if (url.pathname === "/v1/health" && request.method === "GET") {
        return json({ ok: true });
      }

      if (url.pathname === "/v1/sync") {
        if (request.method !== "POST") throw new HttpError(405, "use POST");

        const auth = request.headers.get("authorization") ?? "";
        const key = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
        if (!KEY_PATTERN.test(key)) throw new HttpError(401, "missing or invalid sync key");

        const length = Number(request.headers.get("content-length") ?? "0");
        if (length > MAX_BODY_BYTES) throw new HttpError(413, "request body too large");

        let body: unknown;
        try {
          body = await request.json();
        } catch {
          throw new HttpError(400, "body must be valid JSON");
        }
        const { cursor, changes } = parseSyncBody(body);

        const stub = env.SPACES.getByName(await spaceIdFor(key));
        return json(await stub.sync(cursor, changes));
      }

      throw new HttpError(404, "not found");
    } catch (error) {
      if (error instanceof HttpError) return json({ error: error.message }, error.status);
      console.error("sync failed", error);
      return json({ error: "internal error" }, 500);
    }
  },
} satisfies ExportedHandler<Env>;

// MARK: - Durable Object (one per sync space)

interface TodoRow extends Record<string, SqlStorageValue> {
  id: string;
  title: string;
  notes: string;
  is_completed: number;
  priority: number;
  due_date: number | null;
  tags: string;
  created_at: number;
  updated_at: number;
  completed_at: number | null;
  deleted_at: number | null;
}

function rowToWire(row: TodoRow): WireTodo {
  let tags: string[] = [];
  try {
    tags = JSON.parse(row.tags);
  } catch {}
  return {
    id: row.id,
    title: row.title,
    notes: row.notes,
    isCompleted: row.is_completed === 1,
    priority: row.priority,
    dueDate: row.due_date,
    tags,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    completedAt: row.completed_at,
    deletedAt: row.deleted_at,
  };
}

export class SyncSpace extends DurableObject<Env> {
  private sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS todos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        is_completed INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 1,
        due_date INTEGER,
        tags TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        completed_at INTEGER,
        deleted_at INTEGER,
        seq INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS todos_seq ON todos (seq);
      INSERT OR IGNORE INTO meta (key, value) VALUES ('seq', 0);
    `);
  }

  private currentSeq(): number {
    return this.sql.exec<{ value: number }>("SELECT value FROM meta WHERE key = 'seq'").one().value;
  }

  /** Applies `changes` with last-write-wins, then returns everything after `cursor`. */
  sync(cursor: number, changes: WireTodo[]): SyncResult {
    this.ctx.storage.transactionSync(() => {
      let seq = this.currentSeq();
      for (const todo of changes) {
        const existing = this.sql
          .exec<{ updated_at: number }>("SELECT updated_at FROM todos WHERE id = ?", todo.id)
          .toArray()[0];
        if (existing && existing.updated_at >= todo.updatedAt) continue;

        seq += 1;
        this.sql.exec(
          `INSERT INTO todos (id, title, notes, is_completed, priority, due_date, tags,
                              created_at, updated_at, completed_at, deleted_at, seq)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT (id) DO UPDATE SET
             title = excluded.title, notes = excluded.notes, is_completed = excluded.is_completed,
             priority = excluded.priority, due_date = excluded.due_date, tags = excluded.tags,
             created_at = excluded.created_at, updated_at = excluded.updated_at,
             completed_at = excluded.completed_at, deleted_at = excluded.deleted_at, seq = excluded.seq`,
          todo.id,
          todo.title,
          todo.notes,
          todo.isCompleted ? 1 : 0,
          todo.priority,
          todo.dueDate,
          JSON.stringify(todo.tags),
          todo.createdAt,
          todo.updatedAt,
          todo.completedAt,
          todo.deletedAt,
          seq,
        );
      }
      this.sql.exec("UPDATE meta SET value = ? WHERE key = 'seq'", seq);
    });

    const newCursor = this.currentSeq();
    // A cursor ahead of the server (for example after a server reset) means
    // the client must resync everything.
    const since = cursor > newCursor ? 0 : cursor;
    const rows = this.sql
      .exec<TodoRow>(
        `SELECT id, title, notes, is_completed, priority, due_date, tags,
                created_at, updated_at, completed_at, deleted_at
         FROM todos WHERE seq > ? ORDER BY seq`,
        since,
      )
      .toArray();

    return { cursor: newCursor, changes: rows.map(rowToWire), serverTime: Date.now() };
  }
}
