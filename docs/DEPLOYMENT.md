# Deployment Guide — Smart Water Monitor

## 🚀 Cloud Production Deployment (Render + Vercel)

### Architecture
- **Backend (Python FastAPI / ThingSpeak / AI Engine)**: Hosted on **Render** (`https://<service-name>.onrender.com`).
- **Frontend (Flutter Web Dashboard)**: Hosted on **Vercel** (`https://<project-name>.vercel.app`).
- **Database / Auth**: Managed by **Supabase** (PostgreSQL).

---

### 1. Backend Deployment to Render

Render is pre-configured via `render.yaml` and `requirements.txt`.

#### Option A: 1-Click Blueprint (Recommended)
1. Push this repository to your GitHub account:
   ```bash
   git remote add origin https://github.com/<your-username>/smart-water-monitor.git
   git push -u origin main
   ```
2. Go to your **[Render Dashboard](https://dashboard.render.com/)**.
3. Click **New +** → **Blueprint**.
4. Connect your GitHub repository. Render will automatically detect `render.yaml` and configure:
   - **Environment**: Python 3
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn backend_ai.main:app --host 0.0.0.0 --port $PORT`
   - **Health Check**: `/health`
5. Click **Apply**. Once built, note your Render service URL (e.g. `https://smart-water-ai-backend.onrender.com`).

#### Option B: Manual Web Service on Render
1. In Render Dashboard, click **New +** → **Web Service**.
2. Select your repository.
3. Configure settings:
   - **Name**: `smart-water-backend`
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn backend_ai.main:app --host 0.0.0.0 --port $PORT`
4. Under **Environment Variables**, add:
   - `PYTHON_VERSION`: `3.11.0`
   - `THINGSPEAK_CHANNEL_ID`: `3487158`
5. Click **Create Web Service**.

---

### 2. Frontend Deployment to Vercel

The Flutter web application is compiled into `build/web/` and configured with `vercel.json` (for SPA routing, MIME types, and WebAssembly caching).

#### Option A: Import via GitHub (Recommended)
1. Go to your **[Vercel Dashboard](https://vercel.com/new)**.
2. Click **Add New...** → **Project**.
3. Import your GitHub repository (`smart-water-monitor`).
4. In **Project Settings**:
   - **Framework Preset**: `Other`
   - **Output Directory**: `build/web`
5. Click **Deploy**.
   Vercel will immediately deploy the dashboard to `https://<your-project>.vercel.app`!

#### Option B: Deploy via Vercel CLI
Run the following from your terminal:
```bash
# 1. Login to Vercel (first time only)
npx vercel login

# 2. Deploy to Production
npx vercel --prod
```

---

### 3. Connecting Frontend to your Render Backend

When rebuilding Flutter Web with your live Render backend URL:
```bash
flutter build web --release --dart-define=API_BASE_URL=https://<your-service>.onrender.com
git add build/web/
git commit -m "chore: connect frontend to production Render backend"
git push
```
Vercel will auto-deploy the updated web client!

