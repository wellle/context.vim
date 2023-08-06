local M = {}

local cached = {}
local eol_col = {}

local function fill_hl_cache(buf, row, col)
	if eol_col[row] == nil then
		local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
		eol_col[row] = line and #line or 0
	end

	-- workaround some treesitter captures not terminating at eol
	if col == eol_col[row] then
		return
	end

	-- needs nvim >0.9.0
	local pos = vim.inspect_pos(buf, row - 1, col, { extmarks = false })
	if #pos.semantic_tokens > 0 then
		-- first should have highest priority
		for _, token in ipairs(pos.semantic_tokens) do
			cached[row][col] = token.opts.hl_group
			return
		end
	end

	if #pos.treesitter > 0 then
		-- last should have highest priority
		local hl_group = ""
		for _, token in ipairs(pos.treesitter) do
			-- spell is special?
			if token.capture ~= "spell" then
				hl_group = token.hl_group
			end
		end
		cached[row][col] = hl_group
		return
	end

	if #pos.syntax > 0 then
		-- last should have highest priority
		local hl_group = ""
		for _, token in ipairs(pos.syntax) do
			hl_group = token.hl_group
		end
		cached[row][col] = hl_group
		return
	end
end

local active_buf = nil
local last_tick = nil
local scheduled = 0

function M.nvim_hlgroup(row, col)
	local buf = vim.api.nvim_get_current_buf()

	if buf ~= active_buf or last_tick ~= vim.api.nvim_buf_get_changedtick(buf) then
		active_buf = buf
		last_tick = vim.api.nvim_buf_get_changedtick(buf)
		cached = {}
		eol_col = {}
	end

	cached[row] = cached[row] or {}
	if cached[row][col] ~= nil then
		return cached[row][col]
	end
	cached[row][col] = ""

	-- schedule to avoid stuttering
	scheduled = scheduled + 1
	vim.schedule(function()
		scheduled = scheduled - 1
		if buf ~= active_buf or cached[row] == nil then
			return
		end
		fill_hl_cache(buf, row, col)
		if scheduled < 1 then
			-- last to finish triggers update
			scheduled = 0
			vim.fn["context#update"]("OptionSet") -- need to use OptionSet to force update
		end
	end)

	return ""
end

return M
