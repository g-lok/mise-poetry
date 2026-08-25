-- Must be attached directly to the global PLUGIN object
function PLUGIN:EnvKeys(ctx)
	local project_root = os.getenv("MISE_PROJECT_ROOT") or os.getenv("PWD")
	local pyproject = project_root .. "/pyproject.toml"
	local uv_lock = project_root .. "/uv.lock"
	local poetry_lock = project_root .. "/poetry.lock"

	-- Stop if no pyproject.toml is detected
	local f = io.open(pyproject, "r")
	if not f then
		return {}
	end
	f:close()

	-- Stop if uv is handling this project instead
	local uv_f = io.open(uv_lock, "r")
	if uv_f then
		uv_f:close()
		return {}
	end

	-- MISE_POETRY_VENV_AUTO check
	local venv_auto = os.getenv("MISE_POETRY_VENV_AUTO")
	if venv_auto == "1" or venv_auto == "true" then
		local lock_f = io.open(poetry_lock, "r")
		if not lock_f then
			return {}
		end
		lock_f:close()
	end

	local poetry_bin = ctx.rootPath .. "/bin/poetry"

	-- Run a dynamic dry run to force-generate a .venv if it's missing
	os.execute(string.format("%s --directory %s run true >/dev/null 2>&1", poetry_bin, project_root))

	-- Query the generated venv path
	local handle = io.popen(string.format("%s --directory %s env info --path 2>/dev/null", poetry_bin, project_root))
	local venv_path = handle:read("*a")
	handle:close()

	if venv_path and venv_path ~= "" then
		venv_path = venv_path:gsub("%s+$", "") -- Clean whitespace

		-- Run automated dependency sync if requested
		local auto_install = os.getenv("MISE_POETRY_AUTO_INSTALL")
		if auto_install == "1" or auto_install == "true" then
			print("mise-poetry: Synchronizing workspace packages...")
			os.execute(string.format("%s --directory %s install", poetry_bin, project_root))
		end

		-- Export environment changes back to mise
		return {
			{ key = "VIRTUAL_ENV", value = venv_path },
			{ key = "POETRY_ACTIVE", value = "1" },
			{ key = "PATH", value = venv_path .. "/bin" .. ctx.pathSeparator .. os.getenv("PATH") },
		}
	end

	return {}
end
