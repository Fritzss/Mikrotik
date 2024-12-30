CREATE DATABASE logs; 
CREATE TABLE logs.ros_logs
(
    `host` String,
    `message` String,
    `source_app` String,
    `timestamp` DateTime
)
ENGINE = MergeTree
ORDER BY timestamp
SETTINGS index_granularity = 8192 
