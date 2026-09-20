# Smart Water Monitor

> **AI-Powered Drinking Water Quality Monitoring System**  
> Continuous Real-Time Telemetry, 5-Layer AI Trend Peak Analysis, Abnormal Deterioration Alerts & Institutional Tank Maintenance System.

---

## 🌊 Overview

**Smart Water Monitor** is a full-stack, enterprise-grade IoT and AI water monitoring system designed for institutional drinking water storage tanks (academic blocks, hostels, canteens, RO filtration plants).

The system continuously tracks five key parameters:
- **pH Level** (Ideal: 6.5 - 8.5)
- **TDS** (Total Dissolved Solids in ppm, Ideal: < 300 ppm)
- **Turbidity** (NTU, Ideal: < 1.5 NTU)
- **Temperature** (°C)
- **Water Storage Level** (%)

When water quality deteriorates due to biofilm buildup or sediment accumulation, the cloud AI analysis engine detects abnormal trend peaks and automatically notifies technicians and administrators to inspect and clean the tank.

---

## ⚡ Core Features & Novelty

1. **Abnormal Peak Detection & Graph Highlight**: Highlighting graph peak markers when turbidity/TDS exceeds rolling baselines, with interactive root-cause modals.
2. **Multi-Layer Hybrid AI Engine**: Combines physical parameter validation, exponential moving averages, derivative rate-of-change peak analysis, and multi-parameter correlation.
3. **Mock Hardware Simulation Mode**: Fully operational with `MOCK_SENSOR_MODE = true` allowing complete end-to-end testing (Simulated Data → Trend Detection → Peak Highlight → AI Evaluation → Cleaning Alert → Notification → Cleaning Log → Baseline Reset) without physical ESP32 hardware.
4. **Hardware-Ready ESP32 REST API**: Secured endpoint (`POST /api/v1/devices/readings`) ready to ingest real ESP32 hardware telemetry.
5. **Multi-Tank & RBAC Management**: Manage multiple campus tanks with Admin, Technician, and Viewer role permissions.
6. **Water Audit PDF Reports**: Export formal PDF reports with metric statistics, min/max/avg tables, and AI recommendations.

---

## 🚀 Quick Start

### 1. Flutter Mobile / Web Frontend
```bash
# Fetch dependencies
flutter pub get

# Run on Web or Desktop
flutter run -d chrome
# or
flutter run -d windows
```

### 2. Python AI & Hardware Microservice
```bash
cd backend_ai
pip install -r requirements.txt
python main.py
# Server starts on http://localhost:8000
```

### 3. Running Unit Tests
```bash
flutter test
```

---

## 📁 Repository Structure
- `lib/`: Flutter application (Clean architecture with core, features, data).
- `supabase/`: PostgreSQL schema, RLS policies, and 30-day realistic seed data.
- `backend_ai/`: Python FastAPI AI engine and ESP32 ingestion service.
- `docs/`: System documentation (`ARCHITECTURE.md`, `DATABASE.md`, `API.md`, `AI.md`, `NOTIFICATIONS.md`, `HARDWARE_INTEGRATION.md`, `DEPLOYMENT.md`).
