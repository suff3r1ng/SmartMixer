-- Migration: Add node_role column to devices table
-- This migration adds support for different ESP8266 node types

-- Add node_role column to devices table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'devices' AND column_name = 'node_role'
    ) THEN
        ALTER TABLE devices ADD COLUMN node_role INTEGER DEFAULT 1;
        
        -- Add comment to explain node roles
        COMMENT ON COLUMN devices.node_role IS '1: Coordinator (IR & Motor), 2: Weight Sensor, 3: Touch Sensor';
    END IF;
END $$;

-- Add fields to device_status table to support multiple sensor types
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'device_status' AND column_name = 'weight_value'
    ) THEN
        ALTER TABLE device_status ADD COLUMN weight_value FLOAT DEFAULT 0.0;
        COMMENT ON COLUMN device_status.weight_value IS 'For weight sensor nodes';
    END IF;
    
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'device_status' AND column_name = 'touch_detected'
    ) THEN
        ALTER TABLE device_status ADD COLUMN touch_detected BOOLEAN DEFAULT FALSE;
        COMMENT ON COLUMN device_status.touch_detected IS 'For touch sensor nodes';
    END IF;
END $$;

-- Create API function for retrieving devices by node role
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

-- Insert entry into admin_audit for tracking this migration
INSERT INTO admin_audit (action, details)
VALUES (
    'Database migration: Added node_role support',
    jsonb_build_object(
        'migration', '01_add_node_role.sql',
        'timestamp', now(),
        'description', 'Added support for different ESP8266 node types'
    )
);