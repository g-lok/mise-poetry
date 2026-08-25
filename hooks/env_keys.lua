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

	-- Locate the installation path safely using runtimePath context
	local install_root = ctx.runtimePath or ctx.installPath or ctx.rootPath
	if not install_root then
		return {}
	end

	local poetry_bin = install_root .. "/bin/poetry"

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

		-- CORRECT VFOX WAY: Use the native path object to force-prepend priority
		-- over mise's system/tool pythons
		ctx.path:prepend(venv_path .. "/bin")

		-- Return only standard non-PATH environment updates
		return {
			{ key = "VIRTUAL_ENV", value = venv_path },
			{ key = "POETRY_ACTIVE", value = "1" },
		}
	end

	return {}
end
