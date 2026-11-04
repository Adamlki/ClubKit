local Config = {
	Debug = false, -- Set false untuk production

	AntiSpam = {
		Enabled = true,
		CooldownTime = 1,
		MaxRequestsPerMinute = 50
	},

	AutoUpdateRole = true,
	UpdateDelay = 3,
	BroadcastRoleChange = true,

	DataStore = {
		ReplicationDelay = 3,
		VerificationRetries = 3,
		RetryBaseDelay = 1,
		MaxRetryDelay = 5
	},

	StatsReportInterval = 300
}

return Config
