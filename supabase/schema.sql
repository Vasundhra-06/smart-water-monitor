-- Smart Water Monitor Database Schema (Supabase / PostgreSQL)

-- 1. ENUMS
CREATE TYPE user_role AS ENUM ('admin', 'technician', 'viewer');
CREATE TYPE tank_status AS ENUM ('online', 'offline', 'maintenance');
CREATE TYPE connection_status AS ENUM ('online', 'offline');
CREATE TYPE power_source_type AS ENUM ('mains', 'battery');
CREATE TYPE alert_severity AS ENUM ('INFO', 'WARNING', 'CRITICAL');
CREATE TYPE water_quality_status AS ENUM ('EXCELLENT', 'GOOD', 'ATTENTION', 'POOR', 'CRITICAL');
CREATE TYPE trend_direction AS ENUM ('STABLE', 'IMPROVING', 'DETERIORATING');

-- 2. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    role user_role NOT NULL DEFAULT 'viewer',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. TANKS TABLE
CREATE TABLE IF NOT EXISTS public.tanks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tank_name TEXT NOT NULL,
    location TEXT NOT NULL,
    capacity DOUBLE PRECISION NOT NULL DEFAULT 5000.0, -- in Liters
    description TEXT,
    status tank_status NOT NULL DEFAULT 'online',
    device_id TEXT UNIQUE,
    installation_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_cleaned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. DEVICES TABLE
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL UNIQUE,
    tank_id UUID REFERENCES public.tanks(id) ON DELETE SET NULL,
    device_name TEXT NOT NULL,
    firmware_version TEXT NOT NULL DEFAULT '1.0.0',
    connection_status connection_status NOT NULL DEFAULT 'online',
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    power_source power_source_type NOT NULL DEFAULT 'mains',
    battery_voltage DOUBLE PRECISION DEFAULT 4.2, -- Volts
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Foreign key back from tanks to devices
ALTER TABLE public.tanks ADD CONSTRAINT fk_tanks_device FOREIGN KEY (device_id) REFERENCES public.devices(device_id) ON DELETE SET NULL;

-- 5. SENSOR READINGS TABLE
CREATE TABLE IF NOT EXISTS public.sensor_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    tank_id UUID NOT NULL REFERENCES public.tanks(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ph DOUBLE PRECISION NOT NULL,
    tds DOUBLE PRECISION NOT NULL, -- ppm
    turbidity DOUBLE PRECISION NOT NULL, -- NTU
    temperature DOUBLE PRECISION NOT NULL, -- Celsius
    water_level DOUBLE PRECISION NOT NULL -- Percentage (0 - 100)
);

-- High Performance Indexes
CREATE INDEX IF NOT EXISTS idx_sensor_readings_tank_timestamp ON public.sensor_readings (tank_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_device_timestamp ON public.sensor_readings (device_id, timestamp DESC);

-- 6. ALERTS TABLE
CREATE TABLE IF NOT EXISTS public.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tank_id UUID NOT NULL REFERENCES public.tanks(id) ON DELETE CASCADE,
    device_id TEXT,
    alert_type TEXT NOT NULL, -- info, warning, critical, cleaning, device, power
    severity alert_severity NOT NULL DEFAULT 'INFO',
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    parameter TEXT,
    value DOUBLE PRECISION,
    threshold DOUBLE PRECISION,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_alerts_tank_detected ON public.alerts (tank_id, detected_at DESC);

-- 7. CLEANING RECORDS TABLE
CREATE TABLE IF NOT EXISTS public.cleaning_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tank_id UUID NOT NULL REFERENCES public.tanks(id) ON DELETE CASCADE,
    cleaned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cleaned_by TEXT NOT NULL,
    notes TEXT,
    cleaning_method TEXT NOT NULL DEFAULT 'Manual Scrubbing & Chlorination',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. AI ANALYSIS TABLE
CREATE TABLE IF NOT EXISTS public.ai_analysis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tank_id UUID NOT NULL REFERENCES public.tanks(id) ON DELETE CASCADE,
    analysis_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    water_quality_score INT NOT NULL, -- 0 to 100
    status water_quality_status NOT NULL DEFAULT 'GOOD',
    summary TEXT NOT NULL,
    detected_anomalies JSONB NOT NULL DEFAULT '[]'::jsonb,
    trend trend_direction NOT NULL DEFAULT 'STABLE',
    cleaning_recommendation BOOLEAN NOT NULL DEFAULT FALSE,
    predicted_deterioration TEXT,
    confidence DOUBLE PRECISION NOT NULL DEFAULT 0.95
);

CREATE INDEX IF NOT EXISTS idx_ai_analysis_tank_time ON public.ai_analysis (tank_id, analysis_time DESC);

-- 9. NOTIFICATION PREFERENCES TABLE
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    critical_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    cleaning_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    trend_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    device_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    power_alerts BOOLEAN NOT NULL DEFAULT TRUE
);

-- ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tanks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cleaning_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read all data
CREATE POLICY "Allow authenticated read access" ON public.tanks FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read access" ON public.devices FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read access" ON public.sensor_readings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read access" ON public.alerts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read access" ON public.cleaning_records FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated read access" ON public.ai_analysis FOR SELECT TO authenticated USING (true);

-- Admin and Technician insert/update permissions
CREATE POLICY "Allow admin/technician write tanks" ON public.tanks FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'technician'))
);

CREATE POLICY "Allow admin/technician write cleaning" ON public.cleaning_records FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'technician'))
);

-- Public device endpoint policy for ESP32 hardware postings
CREATE POLICY "Allow service insert readings" ON public.sensor_readings FOR INSERT WITH CHECK (true);
