# 🏢 Maintena — Rental Maintenance Platform

> Multi-tenant, white-label property maintenance management system for South Africa.  
> Built with Node.js · PostgreSQL · Redis · BullMQ

---

## What This Is

PropCare is a SaaS platform that gives rental property businesses their own branded maintenance management system. Each company gets their own subdomain, their own data, their own branding — completely isolated from every other company on the platform.

Tenants report issues. Managers assign work. Technicians fix things. Everyone can see exactly what they need — nothing more.

---

## Who Uses It

| Role | What They Do |
|---|---|
| **Super Admin** | Manages the entire platform. Onboards companies. Views system metrics only — never sees tenant data. |
| **Manager** | Oversees properties. Approves tickets. Views reports. |
| **Maintenance Admin** | Assigns technicians. Manages ticket flow. Schedules preventative work. |
| **Technician** | Receives job assignments. Updates ticket progress. Uploads completion photos. |
| **Tenant** | Reports maintenance issues. Tracks their ticket status. |
| **Staff** | Internal workers (cleaners, security, landscapers) who can log issues they find. |

---

## Quick Start

```bash
# Clone
git clone https://github.com/your-org/propcare-backend.git
cd propcare-backend

# Install
npm install

# Environment
cp .env.example .env
# Edit .env with your database, Redis, and storage credentials

# Database
npm run db:migrate
npm run db:seed

# Development
npm run dev

# Production
npm run build
npm start
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js 20+ |
| Framework | Express.js with NestJS structure |
| Database | PostgreSQL 15+ |
| Cache / Queue | Redis 7+ |
| Job Queue | BullMQ |
| Auth | JWT + bcrypt |
| File Storage | AWS S3 / Cloudflare R2 |
| Email | Nodemailer + SendGrid |
| SMS | Africa's Talking (South Africa) |
| Validation | Zod |
| ORM | Prisma |
| Testing | Jest + Supertest |

---

## Architecture Overview

```
Client Request
     │
     ▼
[ Nginx / Load Balancer ]
     │
     ▼
[ Node.js API Cluster ]
  ├ Auth Middleware
  ├ Tenant Resolver
  └ Rate Limiter
     │
     ▼
[ Service Layer ]
  ├ Ticket Service
  ├ Assignment Service
  ├ Notification Service
  ├ Property Service
  └ Reporting Service
     │
     ▼
[ Data Layer ]
  ├ PostgreSQL (Primary + Replica)
  ├ Redis Cache
  └ S3 File Storage
     │
     ▼
[ Background Workers ]
  ├ Notification Dispatcher
  ├ Maintenance Scheduler
  └ Report Generator
```

---

## Environment Variables

```env
# App
NODE_ENV=production
PORT=3000
APP_DOMAIN=system.co.za

# Database
DATABASE_URL=postgresql://user:pass@host:5432/propcare
DATABASE_REPLICA_URL=postgresql://user:pass@replica:5432/propcare

# Redis
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d

# Storage
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_S3_BUCKET=propcare-uploads
AWS_REGION=af-south-1

# Email
SENDGRID_API_KEY=
EMAIL_FROM=noreply@propcare.co.za

# SMS (Africa's Talking)
AT_API_KEY=
AT_USERNAME=

# Workers
WORKER_CONCURRENCY=5
SCHEDULER_CRON=0 6 * * *
```

---

## Project Structure

See `BACKEND_DOCUMENTATION.md` for the full folder structure, service architecture, database schema explanation, scaling design, and API reference.

---

## Database

Full PostgreSQL schema is in `database/schema.sql`.

Run migrations:
```bash
npm run db:migrate
```

Seed default data:
```bash
npm run db:seed
```

---

## Documentation

| File | Contents |
|---|---|
| `README.md` | This file. Quick start and overview. |
| `BACKEND_DOCUMENTATION.md` | Full architecture, database, services, scaling, API design. |
| `database/schema.sql` | Production-ready PostgreSQL schema. |

---

## License

Private. All rights reserved.
