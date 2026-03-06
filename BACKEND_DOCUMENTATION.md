# PropCare Backend — Full Technical Documentation

> Node.js · PostgreSQL · Redis · BullMQ · Multi-Tenant SaaS  
> Version 1.0 | Rental Maintenance Platform — South Africa

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Folder Structure](#2-folder-structure)
3. [Database Architecture](#3-database-architecture)
4. [Multi-Tenant Design](#4-multi-tenant-design)
5. [Authentication & Authorization](#5-authentication--authorization)
6. [Service Layer](#6-service-layer)
7. [Background Workers & Job Queue](#7-background-workers--job-queue)
8. [Notification Dispatcher](#8-notification-dispatcher)
9. [Caching Strategy](#9-caching-strategy)
10. [Performance & Auto-Scaling](#10-performance--auto-scaling)
11. [Load Management](#11-load-management)
12. [File Storage Architecture](#12-file-storage-architecture)
13. [API Design](#13-api-design)
14. [Error Handling](#14-error-handling)
15. [Logging & Monitoring](#15-logging--monitoring)
16. [Deployment Architecture](#16-deployment-architecture)

---

## 1. System Overview

PropCare is a multi-tenant SaaS platform for rental property maintenance management. Multiple rental companies share one codebase and one database, but their data is completely isolated from each other.

### Core Principles

**Tenant Isolation** — Every database query is scoped to a `company_id`. No query ever returns data from another company.

**Role-Based Access** — Every API endpoint checks both authentication (who are you?) and authorization (are you allowed to do this?).

**Event-Driven Notifications** — Ticket events (created, assigned, updated, completed) trigger background jobs that dispatch notifications. The API never sends notifications directly — it fires events.

**Reactive + Proactive Maintenance** — Tenants and staff report reactive issues. The system automatically generates proactive maintenance tickets on a schedule.

**Performance by Design** — Caching, connection pooling, job queues, and database read replicas are built in from the start, not added later.

---

## 2. Folder Structure

```
propcare-backend/
│
├── src/
│   ├── app.ts                    # Express app setup
│   ├── server.ts                 # HTTP server + cluster bootstrap
│   │
│   ├── config/
│   │   ├── database.ts           # PostgreSQL pool config
│   │   ├── redis.ts              # Redis client config
│   │   ├── storage.ts            # S3 / R2 config
│   │   ├── queue.ts              # BullMQ queue definitions
│   │   └── env.ts                # Validated environment variables (Zod)
│   │
│   ├── middleware/
│   │   ├── auth.middleware.ts    # JWT verification
│   │   ├── tenant.middleware.ts  # Resolves company from subdomain
│   │   ├── role.middleware.ts    # Role-based access control
│   │   ├── ratelimit.middleware.ts
│   │   └── error.middleware.ts   # Global error handler
│   │
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── auth.router.ts
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   └── auth.schema.ts    # Zod validation schemas
│   │   │
│   │   ├── users/
│   │   │   ├── users.router.ts
│   │   │   ├── users.controller.ts
│   │   │   ├── users.service.ts
│   │   │   └── users.schema.ts
│   │   │
│   │   ├── properties/
│   │   │   ├── properties.router.ts
│   │   │   ├── properties.controller.ts
│   │   │   ├── properties.service.ts
│   │   │   └── properties.schema.ts
│   │   │
│   │   ├── units/
│   │   │   ├── units.router.ts
│   │   │   ├── units.controller.ts
│   │   │   └── units.service.ts
│   │   │
│   │   ├── areas/
│   │   │   ├── areas.router.ts
│   │   │   ├── areas.controller.ts
│   │   │   └── areas.service.ts
│   │   │
│   │   ├── tickets/
│   │   │   ├── tickets.router.ts
│   │   │   ├── tickets.controller.ts
│   │   │   ├── tickets.service.ts
│   │   │   ├── tickets.schema.ts
│   │   │   └── tickets.events.ts # Ticket event definitions
│   │   │
│   │   ├── assignments/
│   │   │   ├── assignments.router.ts
│   │   │   ├── assignments.controller.ts
│   │   │   └── assignments.service.ts
│   │   │
│   │   ├── categories/
│   │   │   ├── categories.router.ts
│   │   │   ├── categories.controller.ts
│   │   │   └── categories.service.ts
│   │   │
│   │   ├── schedules/
│   │   │   ├── schedules.router.ts
│   │   │   ├── schedules.controller.ts
│   │   │   └── schedules.service.ts
│   │   │
│   │   ├── notifications/
│   │   │   ├── notifications.router.ts
│   │   │   ├── notifications.controller.ts
│   │   │   └── notifications.service.ts
│   │   │
│   │   ├── reports/
│   │   │   ├── reports.router.ts
│   │   │   ├── reports.controller.ts
│   │   │   └── reports.service.ts
│   │   │
│   │   └── super-admin/
│   │       ├── admin.router.ts
│   │       ├── admin.controller.ts
│   │       └── admin.service.ts
│   │
│   ├── workers/
│   │   ├── worker.bootstrap.ts   # Starts all workers
│   │   ├── notification.worker.ts
│   │   ├── scheduler.worker.ts   # Maintenance schedule processor
│   │   └── report.worker.ts
│   │
│   ├── queues/
│   │   ├── notification.queue.ts
│   │   ├── scheduler.queue.ts
│   │   └── report.queue.ts
│   │
│   ├── dispatchers/
│   │   ├── email.dispatcher.ts
│   │   ├── sms.dispatcher.ts
│   │   └── inapp.dispatcher.ts
│   │
│   ├── events/
│   │   └── ticket.events.ts      # EventEmitter definitions
│   │
│   ├── cache/
│   │   ├── cache.service.ts      # Redis wrapper
│   │   └── cache.keys.ts         # Centralized cache key definitions
│   │
│   ├── db/
│   │   ├── pool.ts               # Primary + replica connection pools
│   │   └── query.ts              # Query helpers
│   │
│   ├── storage/
│   │   └── s3.service.ts         # Upload / delete / signed URLs
│   │
│   └── utils/
│       ├── logger.ts
│       ├── pagination.ts
│       └── response.ts           # Standardised API response format
│
├── database/
│   ├── schema.sql                # Full PostgreSQL schema
│   ├── migrations/               # Migration files
│   └── seeds/                    # Seed data
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
│
├── .env.example
├── .gitignore
├── package.json
├── tsconfig.json
├── README.md
└── BACKEND_DOCUMENTATION.md
```

---

## 3. Database Architecture

### Design Philosophy

The database is designed around one rule: **every table that holds company data includes `company_id`**. This is the multi-tenant isolation key. No query should ever be written without it.

### Tables and Their Purpose

#### `companies`
The root of the system. Each company is a separate rental business using the platform. Holds branding information (logo, colors), subdomain slug, and status.

Key fields:
- `slug` — Used to resolve the company from a subdomain. `greenestate.system.co.za` resolves to `slug = greenestate`.
- `status` — Can be `trial`, `active`, `inactive`, or `suspended`. Suspended companies cannot access the system.

#### `company_settings`
One-to-one with `companies`. Stores operational settings: support email, timezone (`Africa/Johannesburg` by default), currency (`ZAR`), and which notification channels are enabled.

Separated from `companies` so that settings can be updated frequently without touching the main company record.

#### `users`
All human actors in the system live in this one table. Differentiated by `role` enum.

- `company_id` is `NULL` only for `super_admin` users.
- `status` controls access: `pending` users cannot log in until activated.
- Passwords stored as bcrypt hashes only. Never plaintext, never reversible encryption.

#### `properties`
A physical estate or building complex. Belongs to a company. Contains units and shared areas.

Includes `latitude` and `longitude` for future map-based features and technician routing.

#### `units`
An individual rentable space inside a property. Apartment, flat, studio, townhouse, office, etc.

The unique constraint on `(property_id, unit_number)` prevents duplicate unit numbers within the same property.

#### `unit_occupants`
Tracks which tenant lives in which unit and for how long. This is the tenant history table.

`end_date = NULL` means the tenant currently occupies the unit. When a tenant moves out, `end_date` is set.

This means if a tenant reports a plumbing issue and then moves out, the ticket still correctly shows who submitted it and which unit it belongs to.

#### `property_areas`
Shared spaces that are not individual units: main gate, parking lot, garden, pool, security office, lift lobby, etc.

Type field categorises them: `facility`, `outdoor`, `infrastructure`, `common_area`.

This is what allows the system to track maintenance for the whole property — not just individual apartments.

#### `categories`
Maintenance categories are per-company and customisable. Each company can create their own: Plumbing, Electrical, Security, Landscaping, IT, Appliances, etc.

Scoped to `company_id` so Company A's categories never appear in Company B's dropdown.

#### `tickets`
The core of the entire system.

Key design decisions:

- **Location constraint** — A ticket must belong to either a `unit_id` OR an `area_id`, but not both. A constraint enforces this at the database level, not just the application.
- **`created_by`** — The user who submitted the ticket. Could be a tenant, staff member, technician, or manager.
- **`assigned_to`** — The technician responsible for the job.
- **`source`** — Tracks whether the ticket was created by a tenant, staff, technician, manager, or the system (for scheduled maintenance).
- **`total_cost`** — A generated column. Automatically computed as `parts_cost + labour_cost`. Never set manually.
- **`ticket_number`** — Human-readable. Auto-generated by a database trigger as `TKT-000001`. Easier to reference in conversations than a UUID.

#### `ticket_updates`
The activity log for a ticket. Every comment, status change, or technician note is recorded here.

`is_internal = TRUE` means the update is a staff/admin note — not visible to the tenant.

This is important because managers need to communicate internally (e.g., "waiting for parts — supplier delayed") without that message going to the tenant.

#### `attachments`
Photos and documents linked to tickets. Uploaded to S3/R2 and the URL stored here.

`storage_path` records the structured path: `company_5/tickets/tkt-000221/leak.jpg`. This keeps files organised in storage and prevents collisions across companies.

#### `maintenance_schedules`
Defines recurring preventative maintenance tasks. Examples: pool cleaning weekly, gate motor service every 6 months, fire extinguisher inspection yearly.

The `next_due_date` is checked by the maintenance scheduler worker every morning. When a schedule is due, a ticket is automatically created and logged in `scheduled_ticket_log`.

#### `scheduled_ticket_log`
Links each auto-generated ticket back to its schedule. This allows managers to see: "this ticket was auto-generated from the pool cleaning schedule" — and the system avoids creating duplicate tickets if the scheduler runs more than once.

#### `notifications`
Stores all notifications sent to users. Every in-app notification lives here. `is_read` tracks whether the user has seen it.

Email and SMS notifications are also logged here for audit purposes.

#### `activity_logs`
Full audit trail. Every important action in the system is logged: who did what, to which entity, what changed (old value vs new value stored as JSONB).

Used for accountability, dispute resolution, and compliance.

#### `platform_metrics`
Super admin analytics only. One row per day with aggregate counts: total companies, active users, tickets created, etc.

This table never contains any company-specific data. Super admins see aggregates only.

### Database Indexes

Critical indexes for performance:

```sql
-- Tenant isolation (used in almost every query)
CREATE INDEX idx_tickets_company ON tickets(company_id);
CREATE INDEX idx_users_company ON users(company_id);

-- Ticket filtering (most common queries)
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_assigned ON tickets(assigned_to);

-- Unread notifications (high-frequency)
CREATE INDEX idx_notif_unread ON notifications(user_id) WHERE is_read = FALSE;

-- Maintenance due dates (scheduler job)
CREATE INDEX idx_schedules_due ON maintenance_schedules(next_due_date) WHERE is_active = TRUE;

-- Active occupants only (partial index — faster than full scan)
CREATE INDEX idx_occupants_active ON unit_occupants(unit_id) WHERE end_date IS NULL;
```

### Connection Pooling

The application uses two connection pools:

```typescript
// src/db/pool.ts

const primaryPool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,              // max connections in pool
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

const replicaPool = new Pool({
  connectionString: process.env.DATABASE_REPLICA_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// All write operations use primary
export const db = primaryPool;

// All read-only operations use replica
export const dbRead = replicaPool;
```

Write queries (INSERT, UPDATE, DELETE) go to the primary database.

Read queries (SELECT) go to the replica.

This distributes load and protects the primary database from heavy read traffic.

---

## 4. Multi-Tenant Design

### How Tenant Isolation Works

Every request goes through this pipeline:

```
Request arrives at greenestate.system.co.za
         │
         ▼
[ Tenant Middleware ]
  - Extracts subdomain from Host header
  - Looks up company by slug in Redis cache
  - If not cached, queries DB and caches result
  - Attaches req.companyId to request
  - Rejects with 404 if company not found
  - Rejects with 403 if company is suspended
         │
         ▼
[ Auth Middleware ]
  - Verifies JWT token
  - Confirms token.company_id === req.companyId
  - Prevents users from one company accessing another
         │
         ▼
[ Role Middleware ]
  - Checks user role against required role for endpoint
         │
         ▼
[ Controller → Service ]
  - All service methods receive companyId
  - All queries filter by company_id
```

### Tenant Middleware Implementation

```typescript
// src/middleware/tenant.middleware.ts

export async function tenantMiddleware(req: Request, res: Response, next: NextFunction) {
  const host = req.headers.host || '';
  const subdomain = host.split('.')[0];

  if (!subdomain || subdomain === 'www' || subdomain === 'api') {
    return res.status(400).json({ error: 'Invalid company domain' });
  }

  // Check Redis cache first (TTL: 10 minutes)
  const cacheKey = `company:slug:${subdomain}`;
  const cached = await cache.get(cacheKey);

  if (cached) {
    req.companyId = cached.id;
    req.company = cached;
    return next();
  }

  // Cache miss — query database
  const company = await db.query(
    `SELECT id, name, status, primary_color, logo_url
     FROM companies WHERE slug = $1 LIMIT 1`,
    [subdomain]
  );

  if (!company.rows.length) {
    return res.status(404).json({ error: 'Company not found' });
  }

  if (company.rows[0].status === 'suspended') {
    return res.status(403).json({ error: 'Account suspended' });
  }

  // Cache and attach
  await cache.set(cacheKey, company.rows[0], 600); // 10 min TTL
  req.companyId = company.rows[0].id;
  req.company = company.rows[0];
  next();
}
```

### Why Every Service Must Use companyId

Every service method must receive and use `companyId`. No exceptions.

```typescript
// CORRECT
async getTickets(companyId: string, filters: TicketFilters) {
  return db.query(
    `SELECT * FROM tickets WHERE company_id = $1 AND status = $2`,
    [companyId, filters.status]
  );
}

// WRONG — Never do this
async getTickets(filters: TicketFilters) {
  return db.query(`SELECT * FROM tickets WHERE status = $1`, [filters.status]);
  // This returns tickets from ALL companies
}
```

---

## 5. Authentication & Authorization

### JWT Token Structure

```json
{
  "user_id": "uuid",
  "company_id": "uuid",
  "role": "manager",
  "name": "John Sithole",
  "iat": 1700000000,
  "exp": 1700604800
}
```

Token expiry: 7 days for regular users. 1 day for super admins.

### Role Hierarchy

```
super_admin
    │
    ▼
manager
    │
    ▼
maintenance_admin
    │
    ▼
technician / staff / tenant
```

Higher roles can access lower role endpoints. Lower roles cannot access higher role endpoints.

### Role Guard Implementation

```typescript
// src/middleware/role.middleware.ts

export function requireRole(...roles: UserRole[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const userRole = req.user.role;

    if (!roles.includes(userRole)) {
      return res.status(403).json({
        error: 'Insufficient permissions',
        required: roles,
        current: userRole
      });
    }

    next();
  };
}

// Usage in router
router.post('/tickets/:id/assign',
  requireRole('manager', 'maintenance_admin'),
  assignmentController.assign
);
```

### Password Security

Passwords are hashed using bcrypt with a cost factor of 12. Never stored in plaintext.

```typescript
const hash = await bcrypt.hash(password, 12);
const valid = await bcrypt.compare(password, hash);
```

---

## 6. Service Layer

Each service is responsible for one domain. Services do not call each other directly — they communicate through events or the queue.

### Ticket Service

The most complex service. Handles the full ticket lifecycle.

```
Create Ticket
     │
     ├─ Validate input (Zod)
     ├─ Confirm location exists (unit or area)
     ├─ Insert into tickets table
     ├─ Create initial ticket_update ("Ticket created")
     ├─ Emit TICKET_CREATED event
     └─ Return created ticket

Update Status
     │
     ├─ Validate status transition (open→assigned→in_progress→completed→closed)
     ├─ Update ticket status
     ├─ Create ticket_update with status_change
     ├─ If completed: set completed_at timestamp
     ├─ Emit TICKET_STATUS_CHANGED event
     └─ Return updated ticket

Assign Technician
     │
     ├─ Confirm technician belongs to same company
     ├─ Confirm technician has role = 'technician'
     ├─ Update assigned_to on ticket
     ├─ Set status to 'assigned'
     ├─ Emit TICKET_ASSIGNED event
     └─ Return updated ticket
```

### Valid Status Transitions

The system enforces that tickets can only move forward in valid steps:

```typescript
const VALID_TRANSITIONS: Record<TicketStatus, TicketStatus[]> = {
  open:        ['assigned', 'cancelled'],
  assigned:    ['in_progress', 'open', 'cancelled'],
  in_progress: ['on_hold', 'completed', 'cancelled'],
  on_hold:     ['in_progress', 'cancelled'],
  completed:   ['closed'],
  closed:      [],
  cancelled:   [],
};

function canTransition(from: TicketStatus, to: TicketStatus): boolean {
  return VALID_TRANSITIONS[from].includes(to);
}
```

If an invalid transition is attempted (e.g., closed → open), the API returns a 422 error.

### Assignment Service

Handles technician assignment logic.

For MVP: manual assignment by maintenance admin.

The service validates:
1. Technician exists in the same company
2. Technician role is `technician`
3. Technician status is `active`

It does not assign to inactive or suspended technicians.

Future enhancement: workload-aware auto-assignment that considers how many open tickets a technician already has.

### Reporting Service

Generates management reports. All reporting queries run against the **read replica** to avoid affecting primary database performance.

Reports include:
- Open ticket count by property
- Tickets by category
- Average resolution time
- Technician performance (tickets assigned vs completed)
- Monthly cost summary (parts + labour)
- Overdue tickets (past due_date)

Heavy reports are generated as background jobs and cached.

---

## 7. Background Workers & Job Queue

### Why a Job Queue

The API must be fast. Sending emails, SMS, or generating reports inside an API request slows down the response and creates failures that affect the user.

Instead: API fires an event → job is added to queue → worker processes it separately.

```
API Request
    │
    ▼
Ticket Created
    │
    ▼
Event Emitted
    │
    ▼
Job Added to BullMQ Queue
    │
    └─── (API returns 201 immediately — user is not waiting)

           Background Worker
                │
                ▼
           Process Job
                │
                ▼
           Send Email / SMS / In-App Notification
```

### Queue Setup

```typescript
// src/config/queue.ts

import { Queue } from 'bullmq';
import { redis } from './redis';

export const notificationQueue = new Queue('notifications', { connection: redis });
export const schedulerQueue = new Queue('maintenance-scheduler', { connection: redis });
export const reportQueue = new Queue('reports', { connection: redis });
```

### Notification Worker

```typescript
// src/workers/notification.worker.ts

import { Worker } from 'bullmq';

new Worker('notifications', async (job) => {
  const { type, userId, ticketId, companyId, data } = job.data;

  const user = await getUserWithSettings(userId, companyId);
  const settings = await getCompanySettings(companyId);

  // Dispatch based on enabled channels
  const dispatchers = [];

  if (settings.email_enabled) {
    dispatchers.push(emailDispatcher.send({ user, type, data }));
  }

  if (settings.sms_enabled && user.phone) {
    dispatchers.push(smsDispatcher.send({ user, type, data }));
  }

  // Always send in-app notification
  dispatchers.push(inAppDispatcher.create({ userId, type, data, ticketId }));

  await Promise.allSettled(dispatchers);
  // allSettled — if email fails, SMS still sends

}, {
  connection: redis,
  concurrency: 5,               // Process 5 notifications simultaneously
  removeOnComplete: { count: 1000 },
  removeOnFail: { count: 500 },
});
```

### Maintenance Scheduler Worker

Runs every morning at 06:00 SAST via a cron job.

```typescript
// src/workers/scheduler.worker.ts

// Cron: Every day at 06:00 Africa/Johannesburg
new QueueScheduler('maintenance-scheduler', { connection: redis });

schedulerQueue.add('run-daily-check', {}, {
  repeat: { cron: '0 6 * * *', tz: 'Africa/Johannesburg' }
});

new Worker('maintenance-scheduler', async () => {
  const today = new Date().toISOString().split('T')[0];

  // Find all active schedules due today or overdue
  const due = await db.query(`
    SELECT ms.*, p.company_id
    FROM maintenance_schedules ms
    JOIN properties p ON p.id = ms.property_id
    WHERE ms.is_active = TRUE
    AND ms.next_due_date <= $1
    AND NOT EXISTS (
      SELECT 1 FROM scheduled_ticket_log stl
      WHERE stl.schedule_id = ms.id
      AND stl.run_date = $1
    )
  `, [today]);

  for (const schedule of due.rows) {
    // Create ticket
    await ticketService.createFromSchedule(schedule);

    // Update next due date
    await updateNextDueDate(schedule);

    // Log the run
    await logScheduleRun(schedule.id, today);
  }
}, { connection: redis });
```

The `NOT EXISTS` subquery prevents duplicate tickets if the scheduler runs more than once in a day.

### Next Due Date Calculation

```typescript
function calculateNextDueDate(schedule: MaintenanceSchedule): Date {
  const base = new Date(schedule.next_due_date);

  switch (schedule.frequency_type) {
    case 'daily':       return addDays(base, schedule.frequency_value);
    case 'weekly':      return addWeeks(base, schedule.frequency_value);
    case 'fortnightly': return addWeeks(base, 2);
    case 'monthly':     return addMonths(base, schedule.frequency_value);
    case 'quarterly':   return addMonths(base, 3);
    case 'biannual':    return addMonths(base, 6);
    case 'yearly':      return addYears(base, 1);
    default:            return addDays(base, schedule.frequency_value);
  }
}
```

---

## 8. Notification Dispatcher

The notification system is separated from the queue worker. The worker decides what to send. The dispatchers know how to send it.

### Email Dispatcher

```typescript
// src/dispatchers/email.dispatcher.ts

const TEMPLATES: Record<string, EmailTemplate> = {
  TICKET_CREATED: {
    subject: 'Maintenance Request Received — Ticket {ticketNumber}',
    body: 'ticket-created.html',
  },
  TICKET_ASSIGNED: {
    subject: 'Technician Assigned — Ticket {ticketNumber}',
    body: 'ticket-assigned.html',
  },
  TICKET_COMPLETED: {
    subject: 'Maintenance Completed — Ticket {ticketNumber}',
    body: 'ticket-completed.html',
  },
};

export async function send({ user, type, data }) {
  const template = TEMPLATES[type];
  const html = await renderTemplate(template.body, data);

  await sendgrid.send({
    to: user.email,
    from: data.companySettings.notification_email,
    subject: interpolate(template.subject, data),
    html,
  });
}
```

Email is sent FROM the company's own email address — not from a generic platform email. This is important for tenant trust. If a tenant at Green Estate gets an email, it comes from `support@greenestate.co.za`, not `noreply@propcare.co.za`.

### SMS Dispatcher (Africa's Talking)

Africa's Talking is the recommended SMS provider for South Africa. It supports local numbers and has reliable delivery.

```typescript
// src/dispatchers/sms.dispatcher.ts

const SMS_MESSAGES: Record<string, string> = {
  TICKET_CREATED:   'Your maintenance request #{ticketNumber} has been received. We will be in touch.',
  TICKET_ASSIGNED:  'A technician has been assigned to ticket #{ticketNumber}.',
  TICKET_COMPLETED: 'Ticket #{ticketNumber} has been marked complete. Please confirm.',
};

export async function send({ user, type, data }) {
  const message = interpolate(SMS_MESSAGES[type], data);

  await africasTalking.SMS.send({
    to: [user.phone],
    message,
    from: 'PropCare',
  });
}
```

SMS messages are short and actionable. No HTML, no lengthy content.

### In-App Dispatcher

```typescript
// src/dispatchers/inapp.dispatcher.ts

export async function create({ userId, type, data, ticketId }) {
  await db.query(`
    INSERT INTO notifications (company_id, user_id, ticket_id, title, message, channel)
    VALUES ($1, $2, $3, $4, $5, 'in_app')
  `, [data.companyId, userId, ticketId, data.title, data.message]);
}
```

In-app notifications are fetched by the client polling `/api/notifications/unread` or via WebSocket in a future version.

---

## 9. Caching Strategy

### What Gets Cached

Not everything should be cached. Only data that is:
1. Read frequently
2. Changes infrequently
3. Expensive to recompute

| Data | Cache Key | TTL |
|---|---|---|
| Company by slug | `company:slug:{slug}` | 10 minutes |
| Company settings | `settings:{companyId}` | 15 minutes |
| User profile | `user:{userId}` | 5 minutes |
| Property list | `properties:{companyId}` | 5 minutes |
| Category list | `categories:{companyId}` | 30 minutes |
| Dashboard metrics | `dashboard:{companyId}` | 2 minutes |
| Unread notification count | `notif:unread:{userId}` | 30 seconds |

Ticket data is NOT cached because ticket status changes frequently and showing stale status to a tenant would be confusing.

### Cache Invalidation

When data changes, the cache for that data must be cleared immediately.

```typescript
// When a company's settings are updated
await cache.del(`settings:${companyId}`);

// When a category is added or removed
await cache.del(`categories:${companyId}`);

// When a user updates their profile
await cache.del(`user:${userId}`);
```

### Cache Service

```typescript
// src/cache/cache.service.ts

export const cache = {
  async get<T>(key: string): Promise<T | null> {
    const value = await redis.get(key);
    return value ? JSON.parse(value) : null;
  },

  async set(key: string, value: unknown, ttlSeconds: number): Promise<void> {
    await redis.setex(key, ttlSeconds, JSON.stringify(value));
  },

  async del(key: string): Promise<void> {
    await redis.del(key);
  },

  async delPattern(pattern: string): Promise<void> {
    const keys = await redis.keys(pattern);
    if (keys.length) await redis.del(...keys);
  },
};
```

---

## 10. Performance & Auto-Scaling

### Node.js Cluster Mode

Node.js is single-threaded. Running one process on a multi-core server wastes most of the CPU.

Cluster mode spawns one worker process per CPU core. Each worker handles requests independently. The master process distributes incoming connections.

```typescript
// src/server.ts

import cluster from 'cluster';
import os from 'os';

const WORKERS = process.env.NODE_ENV === 'production'
  ? os.cpus().length    // Use all cores in production
  : 1;                  // Single process in development

if (cluster.isPrimary) {
  console.log(`Master PID ${process.pid} — spawning ${WORKERS} workers`);

  for (let i = 0; i < WORKERS; i++) {
    cluster.fork();
  }

  // Replace dead workers automatically
  cluster.on('exit', (worker, code, signal) => {
    console.warn(`Worker ${worker.process.pid} died (${signal || code}). Restarting.`);
    cluster.fork();
  });

} else {
  // Each worker runs its own Express app
  const app = require('./app').default;
  const PORT = process.env.PORT || 3000;

  app.listen(PORT, () => {
    console.log(`Worker ${process.pid} listening on port ${PORT}`);
  });
}
```

If a server has 4 cores, 4 Node.js processes run in parallel. If one crashes, the master restarts it immediately. The system never goes completely down.

### Database Connection Pool Sizing

Each worker needs its own database connections.

```
Workers × Pool Size = Total Connections

Example:
4 workers × 20 connections each = 80 total connections

PostgreSQL max_connections = 100 (default)

So: keep pool size at 20 per worker when using 4 workers.
```

Adjust `max` in the pool config based on your server's PostgreSQL `max_connections` setting.

### Read Replica Load Distribution

```typescript
// src/db/query.ts

export async function queryRead(sql: string, params?: unknown[]) {
  // Route to replica for all SELECT queries
  return dbRead.query(sql, params);
}

export async function queryWrite(sql: string, params?: unknown[]) {
  // Route to primary for all writes
  return db.query(sql, params);
}
```

Example usage in a service:

```typescript
// Reading: uses replica
const tickets = await queryRead(
  `SELECT * FROM tickets WHERE company_id = $1`,
  [companyId]
);

// Writing: uses primary
await queryWrite(
  `UPDATE tickets SET status = $1 WHERE id = $2`,
  [status, ticketId]
);
```

Dashboard and reporting queries are always read-only and hit the replica.

### Horizontal Scaling

When traffic grows beyond one server, multiple API servers can run behind a load balancer.

```
Internet
    │
    ▼
[ Nginx Load Balancer ]
  - Round robin distribution
  - Health check: GET /health
  - Removes unhealthy nodes automatically
    │
    ├─── API Server 1 (4 workers)
    ├─── API Server 2 (4 workers)
    └─── API Server 3 (4 workers)
         │
         ▼
    [ Shared Redis ]     ← Session state and cache shared across all servers
    [ PostgreSQL Primary + Replica ]
    [ S3 Storage ]
```

Because JWT tokens are stateless and Redis is shared, any API server can handle any request. There is no server-specific state.

### Auto-Scaling Rules (Cloud Deployment)

If deployed on AWS, GCP, or DigitalOcean with auto-scaling:

| Metric | Scale Up | Scale Down |
|---|---|---|
| CPU > 70% for 3 minutes | Add 1 server | — |
| CPU < 20% for 10 minutes | — | Remove 1 server |
| Memory > 80% | Add 1 server | — |
| Queue depth > 1000 jobs | Add worker server | — |
| Response time p95 > 500ms | Add 1 server | — |

Minimum servers: 2 (always at least 2 for redundancy)  
Maximum servers: 10 (cost control — adjust based on usage)

---

## 11. Load Management

### Rate Limiting

Rate limiting prevents abuse, protects database connections, and ensures fair usage across companies.

```typescript
// src/middleware/ratelimit.middleware.ts

import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';

// General API rate limit
export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,   // 15 minutes
  max: 200,                    // 200 requests per 15 min per IP
  store: new RedisStore({ client: redis }),
  message: { error: 'Too many requests. Please slow down.' },
  standardHeaders: true,
});

// Auth endpoints (stricter)
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,                     // 10 login attempts per 15 min
  store: new RedisStore({ client: redis }),
  message: { error: 'Too many login attempts. Try again in 15 minutes.' },
});

// File uploads (resource-intensive)
export const uploadLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,                     // 20 uploads per minute
  store: new RedisStore({ client: redis }),
});
```

Rate limits use Redis as the store so they work correctly across multiple API server instances.

### Request Timeout

Long-running requests can block connections. All API endpoints have a maximum execution time.

```typescript
// src/middleware/timeout.middleware.ts

import timeout from 'connect-timeout';

// 30 second maximum for any request
app.use(timeout('30s'));

app.use((req, res, next) => {
  if (!req.timedout) next();
});
```

Heavy operations like report generation are moved to background jobs and never run synchronously in an API request.

### Database Query Timeout

Slow database queries are cancelled automatically:

```typescript
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  statement_timeout: 10000,         // Cancel queries taking > 10 seconds
  query_timeout: 10000,
  connectionTimeoutMillis: 3000,    // Connection timeout
});
```

### Health Check Endpoint

Load balancers need a health check URL to know if a server is alive:

```typescript
app.get('/health', async (req, res) => {
  const checks = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    database: 'unknown',
    redis: 'unknown',
  };

  try {
    await db.query('SELECT 1');
    checks.database = 'ok';
  } catch {
    checks.database = 'error';
    checks.status = 'degraded';
  }

  try {
    await redis.ping();
    checks.redis = 'ok';
  } catch {
    checks.redis = 'error';
    checks.status = 'degraded';
  }

  const statusCode = checks.status === 'ok' ? 200 : 503;
  res.status(statusCode).json(checks);
});
```

If the database or Redis is unreachable, the health check returns 503. The load balancer stops sending traffic to that server.

### Worker Concurrency

BullMQ workers process multiple jobs simultaneously. Concurrency is tuned to balance throughput with resource usage:

```typescript
// Notifications — lightweight, can run many
new Worker('notifications', handler, {
  connection: redis,
  concurrency: 10,
});

// Report generation — CPU and DB intensive, run fewer
new Worker('reports', handler, {
  connection: redis,
  concurrency: 2,
});

// Maintenance scheduler — runs once daily, low concurrency needed
new Worker('maintenance-scheduler', handler, {
  connection: redis,
  concurrency: 1,
});
```

### Graceful Shutdown

When a server is being stopped (for deployment, scaling down, etc.), it should finish what it is doing before stopping:

```typescript
process.on('SIGTERM', async () => {
  console.log('SIGTERM received — shutting down gracefully');

  // Stop accepting new connections
  server.close(async () => {
    // Drain database pool
    await db.end();
    await dbRead.end();

    // Close Redis
    await redis.quit();

    // Workers finish current job before stopping
    await notificationWorker.close();
    await schedulerWorker.close();

    console.log('Shutdown complete');
    process.exit(0);
  });

  // Force exit after 30 seconds if still not done
  setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000);
});
```

This ensures no jobs are lost, no database connections are left open, and no requests are dropped mid-response.

---

## 12. File Storage Architecture

Photos uploaded by tenants and technicians are stored in S3-compatible object storage (AWS S3 or Cloudflare R2).

### File Path Convention

```
{bucket}/
  └── company_{companyId}/
        └── tickets/
              └── {ticketNumber}/
                    ├── photo_1.jpg        (uploaded by tenant on creation)
                    ├── photo_2.jpg
                    └── completion_1.jpg   (uploaded by technician on completion)
```

Example:
```
propcare-uploads/
  └── company_abc123/
        └── tickets/
              └── tkt-000221/
                    ├── leak_under_sink.jpg
                    └── repair_complete.jpg
```

### Upload Flow

```
1. Client requests a signed upload URL from the API
2. API generates presigned S3 URL (valid 5 minutes)
3. Client uploads directly to S3 (never through the API server)
4. Client notifies API with the file path
5. API saves attachment record to database
```

Uploading through the API server would use server memory and bandwidth unnecessarily. Presigned URLs let clients upload directly to storage — the API only handles metadata.

```typescript
// src/storage/s3.service.ts

export async function getPresignedUploadUrl(
  companyId: string,
  ticketNumber: string,
  fileName: string
): Promise<{ uploadUrl: string; storagePath: string }> {
  const ext = fileName.split('.').pop();
  const key = `company_${companyId}/tickets/${ticketNumber}/${Date.now()}.${ext}`;

  const command = new PutObjectCommand({
    Bucket: process.env.AWS_S3_BUCKET,
    Key: key,
    ContentType: `image/${ext}`,
  });

  const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn: 300 });

  return { uploadUrl, storagePath: key };
}
```

---

## 13. API Design

### Base URL

```
https://{company-slug}.system.co.za/api/v1
```

Example: `https://greenestate.system.co.za/api/v1`

### Standard Response Format

All API responses follow a consistent structure:

```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 143
  }
}
```

Error response:
```json
{
  "success": false,
  "error": {
    "code": "TICKET_NOT_FOUND",
    "message": "Ticket TKT-000221 not found",
    "status": 404
  }
}
```

### Core Endpoints

#### Authentication
```
POST   /auth/login              — Login (returns JWT)
POST   /auth/logout             — Logout
POST   /auth/forgot-password    — Request password reset
POST   /auth/reset-password     — Reset password with token
GET    /auth/me                 — Get current user
```

#### Tickets
```
GET    /tickets                 — List tickets (filtered by role)
POST   /tickets                 — Create ticket
GET    /tickets/:id             — Get single ticket with updates
PATCH  /tickets/:id/status      — Update ticket status
PATCH  /tickets/:id/assign      — Assign technician
POST   /tickets/:id/updates     — Add comment or note
POST   /tickets/:id/attachments — Get presigned upload URL
GET    /tickets/:id/attachments — List attachments
```

#### Properties
```
GET    /properties              — List properties
POST   /properties              — Create property (manager+)
GET    /properties/:id          — Get property details
PATCH  /properties/:id          — Update property
GET    /properties/:id/units    — List units in property
GET    /properties/:id/areas    — List areas in property
```

#### Units
```
POST   /properties/:id/units    — Add unit to property
GET    /units/:id               — Get unit details
PATCH  /units/:id               — Update unit
GET    /units/:id/occupants     — Tenant history
POST   /units/:id/occupants     — Move tenant in
PATCH  /units/:id/occupants/current — Move tenant out
```

#### Users
```
GET    /users                   — List users (manager+)
POST   /users/invite            — Invite user by email
GET    /users/:id               — Get user profile
PATCH  /users/:id               — Update user
PATCH  /users/:id/status        — Activate/deactivate
```

#### Maintenance Schedules
```
GET    /schedules               — List schedules
POST   /schedules               — Create schedule
PATCH  /schedules/:id           — Update schedule
DELETE /schedules/:id           — Deactivate schedule
```

#### Notifications
```
GET    /notifications           — List notifications for current user
PATCH  /notifications/:id/read  — Mark as read
PATCH  /notifications/read-all  — Mark all as read
GET    /notifications/unread-count — Fast count for badge
```

#### Reports (Manager+)
```
GET    /reports/overview        — Dashboard summary
GET    /reports/tickets         — Ticket analytics
GET    /reports/technicians     — Technician performance
GET    /reports/costs           — Cost summary
```

#### Super Admin (No company context — global endpoint)
```
GET    /admin/companies         — List all companies
POST   /admin/companies         — Onboard new company
PATCH  /admin/companies/:id     — Update company status
GET    /admin/metrics           — Platform metrics
```

### Pagination

All list endpoints support pagination:

```
GET /tickets?page=1&limit=20&status=open&priority=high
```

Response includes meta:
```json
{
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 143,
    "totalPages": 8
  }
}
```

---

## 14. Error Handling

### Error Classes

```typescript
// src/utils/errors.ts

export class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number,
    public code: string
  ) {
    super(message);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string) {
    super(`${resource} not found`, 404, 'NOT_FOUND');
  }
}

export class ForbiddenError extends AppError {
  constructor() {
    super('You do not have permission to perform this action', 403, 'FORBIDDEN');
  }
}

export class ValidationError extends AppError {
  constructor(message: string) {
    super(message, 422, 'VALIDATION_ERROR');
  }
}
```

### Global Error Middleware

```typescript
// src/middleware/error.middleware.ts

export function errorMiddleware(err: Error, req: Request, res: Response, next: NextFunction) {
  // Log all errors
  logger.error({
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    companyId: req.companyId,
    userId: req.user?.user_id,
  });

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        status: err.statusCode,
      }
    });
  }

  // Unknown error — never expose internal details to client
  return res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
      status: 500,
    }
  });
}
```

---

## 15. Logging & Monitoring

### Structured Logging

All logs are structured JSON. This makes them searchable in logging platforms like Datadog, Papertrail, or Logtail.

```typescript
// src/utils/logger.ts

import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: {
    service: 'propcare-api',
    env: process.env.NODE_ENV,
  },
});
```

Example log entry:

```json
{
  "level": "info",
  "service": "propcare-api",
  "method": "POST",
  "url": "/api/v1/tickets",
  "statusCode": 201,
  "responseTime": 43,
  "companyId": "abc-123",
  "userId": "user-456",
  "timestamp": "2025-03-06T08:23:11.000Z"
}
```

### Key Metrics to Monitor

| Metric | Alert Threshold |
|---|---|
| API response time p95 | > 500ms |
| API error rate | > 1% |
| Database connection pool | > 80% used |
| Redis memory | > 80% used |
| Queue depth (notifications) | > 500 jobs |
| Queue depth (scheduler) | > 0 failed jobs |
| Worker failure rate | Any failure |
| Server CPU | > 80% for 5 min |

---

## 16. Deployment Architecture

### Recommended Production Setup

```
DNS (Cloudflare)
    │
    ▼
Nginx (Load Balancer + SSL Termination)
    │
    ├── API Server 1
    │     ├── Node.js (4 workers)
    │     └── BullMQ Workers
    │
    ├── API Server 2
    │     ├── Node.js (4 workers)
    │     └── BullMQ Workers
    │
    └── (Auto-scaled servers)
         │
         ▼
    ┌────────────────────────────────┐
    │  PostgreSQL Primary            │
    │  PostgreSQL Read Replica       │
    │  Redis Cluster                 │
    │  S3 / R2 Object Storage        │
    └────────────────────────────────┘
```

### SSL / HTTPS

All traffic must use HTTPS. Nginx handles SSL termination using Let's Encrypt certificates.

For wildcard subdomain support (`*.system.co.za`), a wildcard SSL certificate is required.

### Subdomain Routing

Nginx routes all subdomains to the same Node.js cluster:

```nginx
server {
    listen 443 ssl;
    server_name *.system.co.za;

    ssl_certificate /etc/letsencrypt/live/system.co.za/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/system.co.za/privkey.pem;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

upstream api_cluster {
    least_conn;                      # Route to server with fewest active connections
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000;
}
```

The Node.js Tenant Middleware then resolves the company from the subdomain.

### Recommended Cloud Providers (South Africa)

| Provider | Region |
|---|---|
| AWS | af-south-1 (Cape Town) |
| GCP | africa-south1 (Johannesburg) |
| DigitalOcean | Closest: London or Singapore |
| Hetzner | Best price/performance for SA startups |

AWS `af-south-1` is the best choice for low-latency access from South Africa.

---

*End of PropCare Backend Documentation v1.0*
