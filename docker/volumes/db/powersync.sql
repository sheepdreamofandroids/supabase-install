-- NOTE: change to your own passwords for production environments
\set pspass `echo "POWERSYNC_DB_PASSWORD"`

CREATE USER powersync WITH PASSWORD :'pspass';

CREATE DATABASE _powersync WITH OWNER powersync;

CREATE PUBLICATION powersync FOR ALL TABLES