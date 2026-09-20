-- Smart Water Monitor Database Seed Data

-- 1. Insert Initial Tanks
INSERT INTO public.tanks (id, tank_name, location, capacity, description, status, device_id, last_cleaned_at)
VALUES 
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Main Tank', 'Main Academic Building Roof', 5000.0, 'Primary drinking water supply for academic block', 'online', 'TANK_001', NOW() - INTERVAL '6 days'),
    ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'Hostel Block A Tank', 'Student Hostel Complex', 10000.0, 'Hostel drinking and domestic water storage', 'online', 'TANK_002', NOW() - INTERVAL '14 days'),
    ('c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'Central Canteen Tank', 'Central Dining Hall', 3000.0, 'Food preparation and drinking water storage', 'online', 'TANK_003', NOW() - INTERVAL '22 days'),
    ('d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'Library RO Tank', 'Library Building Ground Floor', 2000.0, 'Filtered RO drinking water storage tank', 'online', 'TANK_004', NOW() - INTERVAL '2 days')
ON CONFLICT (id) DO NOTHING;

-- 2. Insert Associated Devices
INSERT INTO public.devices (id, device_id, tank_id, device_name, firmware_version, connection_status, last_seen_at, power_source, battery_voltage)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'TANK_001', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'ESP32 Main Academic Unit', 'v1.2.4', 'online', NOW(), 'mains', 4.2),
    ('22222222-2222-2222-2222-222222222222', 'TANK_002', 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'ESP32 Hostel Unit', 'v1.2.4', 'online', NOW(), 'mains', 4.1),
    ('33333333-3333-3333-3333-333333333333', 'TANK_003', 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'ESP32 Canteen Unit', 'v1.1.0', 'online', NOW(), 'battery', 3.8),
    ('44444444-4444-4444-4444-444444444444', 'TANK_004', 'd3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'ESP32 Library RO Unit', 'v1.2.4', 'online', NOW(), 'mains', 4.2)
ON CONFLICT (device_id) DO NOTHING;

-- 3. Seed Cleaning Records
INSERT INTO public.cleaning_records (tank_id, cleaned_at, cleaned_by, notes, cleaning_method)
VALUES 
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', NOW() - INTERVAL '6 days', 'Rajesh Kumar (Technician)', 'Routine quarterly tank cleaning and UV sterilizer bulb replacement', 'High-pressure jet wash & chlorine treatment'),
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', NOW() - INTERVAL '32 days', 'Suresh Sharma (Technician)', 'Sediment removal and tank walls scrubbing', 'Scrubbing & Flushing'),
    ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', NOW() - INTERVAL '14 days', 'Amit Patel (Technician)', 'Routine maintenance and filter backwash', 'Pressure Wash'),
    ('c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', NOW() - INTERVAL '22 days', 'Rajesh Kumar (Technician)', 'Canteen hygiene inspection cleaning', 'Chemical Sanitization');

-- 4. Seed Current AI Analysis Result
INSERT INTO public.ai_analysis (tank_id, analysis_time, water_quality_score, status, summary, detected_anomalies, trend, cleaning_recommendation, predicted_deterioration, confidence)
VALUES 
    (
        'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 
        NOW(), 
        85, 
        'GOOD', 
        'Water-quality parameters are currently stable following the recent tank cleaning on 10 Aug 2026. All 5 parameters remain within optimal ranges.', 
        '[]'::jsonb, 
        'STABLE', 
        FALSE, 
        'Estimated stable duration remaining: 18 days', 
        0.94
    ),
    (
        'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 
        NOW(), 
        72, 
        'GOOD', 
        'Slight upward trend in TDS detected over the last 48 hours. Water quality remains acceptable but requires monitoring.', 
        '[{"parameter": "tds", "severity": "MEDIUM", "reason": "TDS elevated by 15% from historical baseline"}]'::jsonb, 
        'DETERIORATING', 
        FALSE, 
        'Estimated tank inspection recommended within 7 days', 
        0.88
    ),
    (
        'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 
        NOW(), 
        61, 
        'ATTENTION', 
        'Water quality in Central Canteen Tank is deteriorating. Rapid turbidity increase detected (4.62 NTU peak).', 
        '[{"parameter": "turbidity", "severity": "HIGH", "reason": "Rapid spike from historical baseline of 1.1 NTU"}]'::jsonb, 
        'DETERIORATING', 
        TRUE, 
        'Immediate tank inspection and cleaning recommended', 
        0.92
    ),
    (
        'd3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 
        NOW(), 
        92, 
        'EXCELLENT', 
        'RO filtered water output is performing within optimal parameters. Low TDS and near zero turbidity.', 
        '[]'::jsonb, 
        'STABLE', 
        FALSE, 
        'Filter membranes operating at optimal efficiency', 
        0.98
    );

-- 5. Seed Alerts
INSERT INTO public.alerts (tank_id, device_id, alert_type, severity, title, message, parameter, value, threshold, detected_at, is_read, is_resolved)
VALUES 
    (
        'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
        'TANK_003',
        'cleaning',
        'WARNING',
        'Abnormal Water Quality Trend Detected',
        'Water quality in Central Canteen Tank is deteriorating. Turbidity reached 4.62 NTU (historical baseline: 1.1 NTU). Please inspect/clean the tank.',
        'turbidity',
        4.62,
        2.5,
        NOW() - INTERVAL '2 hours',
        FALSE,
        FALSE
    ),
    (
        'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
        'TANK_003',
        'power',
        'WARNING',
        'Battery Backup Mode',
        'Central Canteen Tank device is operating on battery backup (Battery: 74%). Mains power disconnected.',
        'power_source',
        0.0,
        0.0,
        NOW() - INTERVAL '4 hours',
        TRUE,
        FALSE
    ),
    (
        'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
        'TANK_002',
        'info',
        'INFO',
        'Scheduled AI Stability Check Complete',
        'Hostel Block A Tank parameters evaluated. Baseline TDS slight rise observed.',
        'tds',
        310.0,
        500.0,
        NOW() - INTERVAL '1 day',
        TRUE,
        TRUE
    );
