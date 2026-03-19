Config = {}

Config.Framework = 'esx' -- 'esx' | 'qbcore' | 'standalone'
Config.OpenKey = 'F9'
Config.RefreshRate = 2000 -- ms for resmon refresh
Config.MaxEventLog = 200
Config.MaxNuiLog = 100
Config.EntityRange = 50.0
Config.AllowedGroups = {'admin', 'superadmin', 'god', 'dev'}
Config.RequireAce = true -- require dei.devtools ACE permission
Config.DefaultTheme = 'dark' -- dark | midnight | neon | minimal
Config.DefaultOpacity = 85 -- 30-100
