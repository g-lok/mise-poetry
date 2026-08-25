function PostInstall(ctx)
	local version = ctx.version
	local install_path = ctx.rootPath

	local install_url = "https://python-poetry.org"
	-- Fix for precompiled pythons: force symlinks=True so libraries resolve accurately
	local cmd = string.format(
		"curl -sSL %s | sed 's/symlinks=False/symlinks=True/' | POETRY_HOME=%s python3 - --version %s",
		install_url,
		install_path,
		version
	)

	print("mise-poetry: Bootstrapping via official installer...")
	local exit_code = os.execute(cmd)
	if exit_code ~= 0 then
		error("mise-poetry: Installation wrapper exited with an error status.")
	end

	-- Configure poetry isolation flags
	os.execute(string.format("%s/bin/poetry config virtualenvs.prefer-active-python true", install_path))
	os.execute(string.format("%s/bin/poetry config virtualenvs.use-poetry-python false", install_path))
end
