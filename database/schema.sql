-- schema.sql
-- Main database schema for Auto Stirrer project

-- Enable Row Level Security
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-super-secret-jwt-token';

-- Create tables with proper relations and constraints
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles table to store user information
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Devices table to store all auto stirrer devices
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    sensor_id TEXT,
    user_id UUID REFERENCES auth.users ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT FALSE,
    mode TEXT DEFAULT 'auto',
    speed_percentage INTEGER DEFAULT 50,
    timer_minutes INTEGER DEFAULT 0,
    node_role INTEGER DEFAULT 1, -- 1: Coordinator (IR & Motor), 2: Weight Sensor, 3: Touch Sensor
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Device status table to store current status
CREATE TABLE IF NOT EXISTS device_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices ON DELETE CASCADE,
    motor_on BOOLEAN DEFAULT FALSE,
    glass_present BOOLEAN DEFAULT FALSE,
    weight_value FLOAT DEFAULT 0.0, -- For weight sensor nodes
    touch_detected BOOLEAN DEFAULT FALSE, -- For touch sensor nodes
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Device users table to allow many-to-many relationships
CREATE TABLE IF NOT EXISTS device_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (device_id, user_id)
);

-- Logs table to track system activities
CREATE TABLE IF NOT EXISTS logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users ON DELETE SET NULL,
    action TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Admin audit log for sensitive operations
CREATE TABLE IF NOT EXISTS admin_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users ON DELETE SET NULL,
    action TEXT NOT NULL,
    details JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_logs_device_id ON logs (device_id);
CREATE INDEX IF NOT EXISTS idx_logs_user_id ON logs (user_id);
CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs (created_at);
CREATE INDEX IF NOT EXISTS idx_device_status_device_id ON device_status (device_id);
CREATE INDEX IF NOT EXISTS idx_device_users_device_id ON device_users (device_id);
CREATE INDEX IF NOT EXISTS idx_device_users_user_id ON device_users (user_id);

-- Create utility functions for statistics
CREATE OR REPLACE FUNCTION count_devices() RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM devices);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION count_active_devices() RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM devices WHERE is_active = TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION count_manual_mode_devices() RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM devices WHERE mode = 'manual');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION count_users() RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM profiles);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Set up Row-Level Security policies
-- Devices table policies
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can do anything with devices" 
ON devices FOR ALL 
TO authenticated 
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
);

CREATE POLICY "Users can view their assigned devices" 
ON devices FOR SELECT 
TO authenticated 
USING (
    user_id = auth.uid() OR
    EXISTS (
        SELECT 1 FROM device_users 
        WHERE device_id = devices.id AND user_id = auth.uid()
    )
);

-- Device status policies
ALTER TABLE device_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can do anything with device status" 
ON device_status FOR ALL 
TO authenticated 
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
);

CREATE POLICY "Users can view status of their devices" 
ON device_status FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM devices d
        LEFT JOIN device_users du ON d.id = du.device_id
        WHERE d.id = device_status.device_id 
        AND (d.user_id = auth.uid() OR du.user_id = auth.uid())
    )
);

-- Logs policies
ALTER TABLE logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all logs" 
ON logs FOR SELECT 
TO authenticated 
USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
);

CREATE POLICY "Users can view logs for their devices" 
ON logs FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM devices d
        LEFT JOIN device_users du ON d.id = du.device_id
        WHERE d.id = logs.device_id 
        AND (d.user_id = auth.uid() OR du.user_id = auth.uid())
    )
);

-- Create database triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add triggers to automatically update timestamp columns
CREATE TRIGGER set_timestamp_devices
BEFORE UPDATE ON devices
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE TRIGGER set_timestamp_profiles
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

-- Create API functions for retrieving devices by node role
CREATE OR REPLACE FUNCTION get_devices_by_role(role_id INTEGER)
RETURNS TABLE (
    id UUID,
    name TEXT,
    sensor_id TEXT,
    is_active BOOLEAN,
    mode TEXT,
    node_role INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT d.id, d.name, d.sensor_id, d.is_active, d.mode, d.node_role
    FROM devices d
    WHERE d.node_role = role_id
    ORDER BY d.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
