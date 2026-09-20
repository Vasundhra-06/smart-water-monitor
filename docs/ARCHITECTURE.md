# System Architecture — Smart Water Monitor

## 🏛️ End-to-End System Topology

```text
ESP32 Hardware Sensors (pH, TDS, Turbidity, Temp, Level)
              │
              ▼ (Wi-Fi / HTTPS REST)
     Supabase PostgreSQL & Cloud Database
              │
              ▼
   Python FastAPI AI Microservice (5-Layer Engine)
              │
              ▼
   Riverpod State Management & GoRouter
              │
              ▼
Flutter App (Android, iOS, Web, Windows)
```

## 🔌 Hardware Abstraction Layer
The application uses a repository pattern abstraction (`ISensorRepository`) with swappable data sources:
- `MockSensorDataSource`: Generates realistic physics simulation streams and demo scenario triggers.
- `SupabaseSensorDataSource`: Direct cloud subscription to real ESP32 PostgreSQL telemetry.

Switching from simulated mock mode to physical hardware requires zero changes in the Flutter UI widgets.
