-- For LIVE Troubleshooting
exec sp_BlitzFirst @ExpertMode = 1, @Seconds = 60

-- For General Health Check
exec sp_BlitzFirst @SinceStartup = 1, @CheckServerInfo = 1;

