# Database Documentation — Smart Water Monitor

## 📊 Database Schema (Supabase / PostgreSQL)

Tables created:
1. `profiles`: User accounts, emails, and roles (`admin`, `technician`, `viewer`).
2. `tanks`: Storage tanks, locations, capacity (L), device key, and last cleaned timestamp.
3. `devices`: Telemetry units, firmware version, connection status, power source (`mains`, `battery`), and battery voltage.
4. `sensor_readings`: High frequency time-series sensor readings (`ph`, `tds`, `turbidity`, `temperature`, `water_level`) with composite indexes on `(tank_id, timestamp DESC)`.
5. `alerts`: System notifications, severity levels (`INFO`, `WARNING`, `CRITICAL`), parameter values, and resolution state.
6. `cleaning_records`: Tank maintenance logs with date, technician, notes, and cleaning method.
7. `ai_analysis`: Historical AI evaluations, water quality score (0-100), status, anomalies JSONB, and recommendations.
8. `notification_preferences`: User alert settings.

## 🔐 Security & RLS
- All tables enforce Row Level Security.
- Authenticated read access granted to logged-in users.
- Write operations on `tanks` and `cleaning_records` restricted to `admin` and `technician` roles.
