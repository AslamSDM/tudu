# Tudu Sync API (v1)

Backend: Cloudflare Worker + one SQLite Durable Object per sync space (`worker/`). Production: `https://tudu-sync.aslamprpd.workers.dev`. Clients: macOS app + widget, Android app + widget.

## Auth: sync key

- A **sync key** is a random string of at least 32 characters, made of `[A-Za-z0-9_-]`. The first device makes it (32 random bytes, base64url, no padding). Other devices join by pasting it or scanning a QR code.
- Every request sends `Authorization: Bearer <syncKey>`.
- The server never stores the key. The space id is `hex(sha256(syncKey))`. Any valid key creates its space on first use.
- QR / deep-link payload: `tudu://sync?url=<urlencoded base URL>&key=<syncKey>`

## Wire format: Todo

All timestamps are **integer milliseconds since the Unix epoch**. IDs are **lowercase** UUID strings.

```json
{
  "id": "6f1c1e9e-3f43-4c1a-9a43-0b6a3f7f2b11",
  "title": "Buy milk",
  "notes": "",
  "isCompleted": false,
  "priority": 1,
  "dueDate": 1762600000000,
  "tags": ["home"],
  "createdAt": 1762500000000,
  "updatedAt": 1762500000000,
  "completedAt": null,
  "deletedAt": null
}
```

- `priority`: 0 = low, 1 = medium, 2 = high.
- `dueDate`, `completedAt`, `deletedAt`: number or null.
- A delete is a **tombstone**: set `deletedAt` and `updatedAt` to now, and keep the record. Clients hide tombstones.
- Every local change must bump `updatedAt`.

## `POST /v1/sync`

Request:

```json
{ "cursor": 0, "changes": [ /* Todo, max 500 */ ] }
```

Response `200`:

```json
{ "cursor": 42, "changes": [ /* Todo */ ], "serverTime": 1762600000000 }
```

Server behavior (one transaction):

1. For each incoming todo: upsert with **last-write-wins**. The server takes the incoming record only when `incoming.updatedAt > stored.updatedAt`. On a tie, the stored record stays.
2. Every accepted write gets a new per-space sequence number.
3. The response has every record with `seq > request.cursor`. This includes the records that this request just wrote. The response `cursor` is the new high-water mark.

Client algorithm:

1. Keep `cursor` (start 0) and a set of **pending** ids (records changed locally since the last successful push).
2. Send the pending records and `cursor`.
3. On success, merge each returned record: replace the local record when it is missing or when `remote.updatedAt > local.updatedAt`. Store the new `cursor`. Remove from pending each id whose local `updatedAt` has not changed since the push. An id that changed again during the request stays pending.
4. When `changes` has more than 500 pending records, send them in chunks.
5. To do a full resync, send `cursor: 0`.

## `GET /v1/health`

No auth. Returns `{ "ok": true }`.

## Errors

JSON `{ "error": "message" }` with status `400` (bad body), `401` (missing or bad key), `413` (too many changes), `500`.
