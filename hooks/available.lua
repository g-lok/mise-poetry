local http = require("http")
local json = require("json")

function Available()
	local url = "https://github.com"
	local resp, err = http.get(url, { ["User-Agent"] = "vfox-poetry" })
	if err then
		return {}
	end

	local data = json.decode(resp.body)
	local versions = {}

	for _, release in ipairs(data) do
		if not release.prerelease and not release.draft then
			local v = release.tag_name:gsub("^v", "")
			table.insert(versions, {
				version = v,
				note = release.name,
			})
		end
	end
	return versions
end
