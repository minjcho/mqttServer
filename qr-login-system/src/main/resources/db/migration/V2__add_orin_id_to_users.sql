-- V2__add_orin_id_to_users.sql
-- Add orin_id column to users table

ALTER TABLE users ADD COLUMN orin_id VARCHAR(50) UNIQUE;

-- Create index on orin_id for faster lookups
CREATE INDEX idx_users_orin_id ON users(orin_id);