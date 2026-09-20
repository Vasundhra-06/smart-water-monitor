# Deployment Guide — Smart Water Monitor

## 🚀 Cloud Deployment Steps

### 1. Database (Supabase)
1. Log into your Supabase Dashboard.
2. Navigate to SQL Editor and run `supabase/schema.sql`.
3. Seed test data by running `supabase/seed.sql`.

### 2. AI Backend Microservice (Docker / Fastify / FastAPI)
```bash
docker build -t smart-water-ai ./backend_ai
docker run -d -p 8000:8000 --name water-ai smart-water-ai
```

### 3. Flutter Web / Mobile App Build
```bash
# Web Build
flutter build web --release

# Android APK Build
flutter build apk --release
```
