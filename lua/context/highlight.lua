local M = {}

function M:fill_hl_cache(row, col)
	if self.eol_col[row] == nil then
		local line = vim.api.nvim_buf_get_lines(self.buf, row - 1, row, false)[1]
		self.eol_col[row] = line and #line or 0
	end

	-- workaround some treesitter captures not terminating at eol
	if col == self.eol_col[row] then
		return
	end

	-- needs nvim >0.9.0
	local pos = vim.inspect_pos(self.buf, row - 1, col, { extmarks = false })
	if #pos.semantic_tokens > 0 then
		-- first should have highest priority
		for _, token in ipairs(pos.semantic_tokens) do
			self.cached[row][col] = token.opts.hl_group
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
		self.cached[row][col] = hl_group
		return
	end

	if #pos.syntax > 0 then
		-- last should have highest priority
		local hl_group = ""
		for _, token in ipairs(pos.syntax) do
			hl_group = token.hl_group
		end
		self.cached[row][col] = hl_group
		return
	end
end

function M:reset()
	self.cached = {}
	self.eol_col = {}
end

function M:get_highlight(row, col)
	self.cached[row] = self.cached[row] or {}
	if self.cached[row][col] ~= nil then
		return self.cached[row][col]
	end
	self.cached[row][col] = ""

	-- schedule to avoid stuttering
	self.scheduled = self.scheduled + 1
	vim.schedule(function()
		self.scheduled = self.scheduled - 1
		if self.cached[row] == nil then
			return
		end
		self:fill_hl_cache(row, col)
		if self.scheduled < 1 then
			-- last to finish triggers update
			self.scheduled = 0
			vim.fn["context#update"]("OptionSet") -- need to use OptionSet to force update
		end
	end)

	return ""
end

function M.new(buf)
	local m = setmetatable({}, { __index = M })
	m.buf = buf
	m.cached = {}
	m.eol_col = {}
	m.scheduled = 0

	return m
end

local _list = {}
local function nvim_hlgroup(winid, row, col)
	local buf = vim.api.nvim_win_get_buf(winid)
	local m = _list[buf]
	if m == nil then
		m = M.new(buf)
		vim.api.nvim_buf_attach(buf, false, {
			on_detach = function()
				_list[buf] = nil
			end,
			on_lines = function()
				m:reset()
			end,
		})
		_list[buf] = m
	end
	return m:get_highlight(row, col)
end

return { nvim_hlgroup = nvim_hlgroup }
