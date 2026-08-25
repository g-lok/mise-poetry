local http = require("http")
local json = require("json")

local M = {}

-- -------------------------------------------------------------
-- 1. REMOTE VERSION RESOLUTION
-- -------------------------------------------------------------
function M.Available()
	local url = "https://github.com"
	local headers = { ["User-Agent"] = "mise-poetry-plugin" }

	local resp, err = http.get(url, headers)
	if err then
		return {}, err
	end

	local data = json.decode(resp.body)
	local versions = {}

	for _, release in ipairs(data) do
		-- Skip pre-releases and draft packages
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

-- -------------------------------------------------------------
-- 2. INSTALLATION ENGINE
-- -------------------------------------------------------------
function M.Install(ctx)
	local version = ctx.version
	local install_path = ctx.install_path

	-- Use the official installer pipeline
	local install_url = "https://python-poetry.org"
	local cmd =
		string.format("curl -sSL %s | POETRY_HOME=%s python3 - --version %s", install_url, install_path, version)

	print("mise-poetry: Downloading and bootstrapping via official script...")
	local exit_code = os.execute(cmd)
	if exit_code ~= 0 then
		error("mise-poetry: Failed to execute official bootstrap script.")
	end

	-- Optimize config flags so Poetry natively respects the mise-python execution stack
	print("mise-poetry: Configuring active Python priorities...")
	os.execute(string.format("%s/bin/poetry config virtualenvs.prefer-active-python true", install_path))
	os.execute(string.format("%s/bin/poetry config virtualenvs.use-poetry-python false", install_path))
end

-- -------------------------------------------------------------
-- 3. ENVIRONMENT & VIRTUALENV TRAPPING (exec-env replacement)
-- -------------------------------------------------------------
function M.Env(ctx)
	-- Locate project context root
	local project_root = os.getenv("MISE_PROJECT_ROOT") or os.getenv("PWD")
	local pyproject = project_root .. "/pyproject.toml"
	local uv_lock = project_root .. "/uv.lock"
	local poetry_lock = project_root .. "/poetry.lock"

	-- Exit if pyproject.toml does not exist
	local f = io.open(pyproject, "r")
	if not f then
		return {}
	end
	f:close()

	-- Anti-collision: Exit early if uv.lock is present
	local uv_f = io.open(uv_lock, "r")
	if uv_f then
		uv_f:close()
		return {}
	end

	-- Behavior modifier check: MISE_POETRY_VENV_AUTO
	local venv_auto = os.getenv("MISE_POETRY_VENV_AUTO")
	if venv_auto == "1" or venv_auto == "true" then
		local lock_f = io.open(poetry_lock, "r")
		if not lock_f then
			return {}
		end
		lock_f:close()
	end

	local poetry_bin = ctx.install_path .. "/bin/poetry"

	-- Silently trigger a dry run to create the .venv if it doesn't exist
	os.execute(string.format("%s --directory %s run true >/dev/null 2>&1", poetry_bin, project_root))

	-- Retrieve the precise target path of the active virtualenv
	local handle = io.popen(string.format("%s --directory %s env info --path 2>/dev/null", poetry_bin, project_root))
	local venv_path = handle:read("*a")
	handle:close()

	local env_updates = {}

	if venv_path and venv_path ~= "" then
		venv_path = venv_path:gsub("%s+$", "") -- Strip trailing whitespaces/newlines

		-- Export standard python environment flags
		env_updates["VIRTUAL_ENV"] = venv_path
		env_updates["POETRY_ACTIVE"] = "1"

		-- Prepend virtualenv's executable binaries to the user's path environment
		ctx.path:append(venv_path .. "/bin")

		-- Handle MISE_POETRY_AUTO_INSTALL automated package population
		local auto_install = os.getenv("MISE_POETRY_AUTO_INSTALL")
		if auto_install == "1" or auto_install == "true" then
			print("mise-poetry: Executing automated backend dependency synchronization...")
			os.execute(string.format("%s --directory %s install", poetry_bin, project_root))
		end
	end

	return env_updates
end

return M
