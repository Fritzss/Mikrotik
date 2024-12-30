CREATE DATABASE logs; 
CREATE TABLE IF NOT EXISTS logs.ros
(
    `host` String,
    `message` String,
    `source_type` String,
    `Topics` String,
    `port` UInt16,
    `timestamp` DateTime
)
ENGINE = MergeTree
PARTITION BY Topics
ORDER BY timestamp
TTL timestamp + toIntervalMonth(12)
SETTINGS index_granularity = 8192
