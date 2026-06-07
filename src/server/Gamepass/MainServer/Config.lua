local Config = {
	Debug = false, -- Set false untuk production

	AntiSpam = {
		Enabled = true,
		CooldownTime = 1,
		MaxRequestsPerMinute = 50
	},

	-- Role update settings
	AutoUpdateRole = true,
	UpdateDelay = 3, -- Delay untuk DataStore replication
	BroadcastRoleChange = true,

	-- DataStore replication settings
	DataStore = {
		ReplicationDelay = 3,
		VerificationRetries = 3,
		RetryBaseDelay = 1,
		MaxRetryDelay = 5
	},

	-- Stats reporting interval (seconds)
	StatsReportInterval = 300 -- 5 minutes
}

return Config