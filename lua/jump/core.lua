local cache = require("sj.cache")
local ui = require("sj.ui")
local utils = require("sj.utils")

local keymaps = {
	cancel = vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
	delete_prev_char = vim.api.nvim_replace_termcodes("<BS>", true, false, true),
}

------------------------------------------------------------------------------------------------------------------------

local function pattern_ranges(text, pattern, search)
	local iters, text_len = 0, #text
	local start_idx, end_idx, init
	local ranges = {}

	if text_len == 0 then
		return ranges
	end

	while iters <= text_len do
		iters = iters + 1

		start_idx, end_idx, init = search(text, pattern, init)
		if start_idx == nil then
			break
		end

		table.insert(ranges, { start_idx, end_idx })
	end

	return ranges
end

local function get_search_function(pattern_type)
	if type(pattern_type) ~= "string" then
		pattern_type = "vim"
	end

	local plain = pattern_type:find("plain$") and true or false
	local function lua_search(text, pattern, init)
		if vim.o.ignorecase == true and not (vim.o.smartcase == true and pattern:find("%u") ~= nil) then
			text = text:lower()
			pattern = pattern:lower()
		end
		local start_idx, end_idx = text:find(pattern, init, plain)
		if start_idx ~= nil then
			return start_idx, end_idx, start_idx and start_idx == end_idx and end_idx + 1 or end_idx
		end
	end

	local prefix = pattern_type == "vim_very_magic" and "\\v" or ""
	local function vim_search(text, pattern, init)
		local _, start_idx, end_idx = unpack(vim.fn.matchstrpos(text, prefix .. pattern, init))
		if start_idx ~= -1 then
			return start_idx + 1, end_idx, end_idx
		end
	end

	if pattern_type:find("^lua") then
		return lua_search
	else
		return vim_search
	end
end

---@param user_input string
local function extract_pattern_and_label(user_input, separator)
	local separator_pos = user_input:match("^.*()" .. vim.pesc(separator))

	if separator_pos then
		return user_input:sub(1, separator_pos - 1), user_input:sub(separator_pos + separator:len())
	else
		return user_input, ""
	end
end

------------------------------------------------------------------------------------------------------------------------

local M = {}

function M.manage_keymaps(new_keymaps)
	for action, _ in pairs(keymaps) do
		if type(new_keymaps[action]) == "string" and #new_keymaps[action] > 0 then
			keymaps[action] = vim.api.nvim_replace_termcodes(new_keymaps[action], true, false, true)
		end
	end
end

function M.jump_to(range)
	if type(range) ~= "table" then
		return
	end

	local new_lnum, new_col = unpack(range)
	if type(new_lnum) ~= "number" or type(new_col) ~= "number" then
		return
	end
	new_lnum, new_col = new_lnum + 1, new_col - 1

	local cur_lnum, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local jump_forward = cur_lnum < new_lnum or (cur_lnum == new_lnum and cur_col < new_col)

	local mode = vim.fn.mode(1)
	local inclusive = cache.options.inclusive == true
	local line_scope = cache.options.search_scope == "current_line"

	if mode and mode:find("no") ~= nil then
		if not jump_forward and not inclusive then -- T
			new_col = new_col + 1
		elseif jump_forward and inclusive then -- f
			-- new_col++ wouldn't delete the last character of the line
			vim.cmd("normal! v")
		end
	elseif mode and mode:match("[vV\22]") or (mode == "n" and line_scope) then
		if not jump_forward and not inclusive then -- T
			new_col = new_col + 1
		elseif jump_forward and not inclusive then -- t
			new_col = new_col - 1
		end
	end

	vim.api.nvim_win_set_cursor(0, { new_lnum, new_col })
end

function M.extract_range_and_jump_to(user_input, labels_map)
	if type(user_input) ~= "string" or type(labels_map) ~= "table" then
		return
	end

	local _, label = extract_pattern_and_label(user_input, cache.options.separator)

	if #user_input and label == "" then -- auto_jump
		label = cache.options.labels[1]
	end

	M.jump_to(labels_map[label])
end

function M.win_get_lines_range(win_id, scope)
	local cursor_line = vim.fn.line(".", win_id)
	local first_visible_line, last_visible_line = vim.fn.line("w0", win_id), vim.fn.line("w$", win_id)
	local first_buffer_line, last_buffer_line = 1, vim.fn.line("$", win_id)

	local cases = {
		current_line = { cursor_line, cursor_line },
		visible_lines_above = { first_visible_line, cursor_line - 1 },
		visible_lines_below = { cursor_line + 1, last_visible_line },
		visible_lines = { first_visible_line, last_visible_line },
		buffer = { first_buffer_line, last_buffer_line },
	}

	return unpack(cases[scope] or cases["visible_lines"])
end

function M.create_labels_map(labels, matches, reverse)
	local label
	local labels_map = {}

	for match_num, _ in pairs(matches) do
		label = labels[match_num]
		if not label then
			break
		end

		if reverse == true then
			labels_map[label] = matches[#matches + 1 - match_num]
		else
			labels_map[label] = matches[match_num]
		end
	end

	return labels_map
end

---@param win_id number
---@param pattern string
function M.win_find_pattern(win_id, pattern, opts)
	if type(win_id) ~= "number" or not vim.api.nvim_win_is_valid(win_id) then
		return {}
	end

	if type(pattern) ~= "string" or #pattern == 0 then
		return {}
	end

	local default_opts = {
		cursor_pos = vim.api.nvim_win_get_cursor(win_id),
		forward = true,
		pattern_type = "vim",
		relative = false,
		scope = "visible_lines",
	}
	opts = vim.tbl_extend("force", default_opts, type(opts) == "table" and opts or {})

	local buf_nr = vim.api.nvim_win_get_buf(win_id)
	local first_line, last_line = M.win_get_lines_range(win_id, opts.scope)
	local lines = vim.api.nvim_buf_get_lines(buf_nr, first_line - 1, last_line, false)

	if vim.o.smartcase and opts.pattern_type:find("vim") and pattern:find("%u") then
		pattern = "\\C" .. pattern
	end
	local search = get_search_function(opts.pattern_type)

	local cursor_lnum, cursor_col = opts.cursor_pos[1], opts.cursor_pos[2] + 1

	local forward = opts.forward == true
	local relative = opts.relative == true

	local match_lnum, match_col, match_end_col, match_text, match_next_chars
	local prev_matches, next_matches = {}, {}

	for i, line in ipairs(lines) do
		--- skip errors due to % at the end (lua), unbalanced (), ...
		local ok, ranges = pcall(pattern_ranges, line, pattern, search)

		if ok then
			for _, match_range in ipairs(ranges) do
				match_lnum, match_col, match_end_col = first_line - 1 + i, unpack(match_range)
				match_text = line:sub(match_col, match_end_col)
				match_next_chars = line:sub(match_end_col + 1, match_end_col + 1)
				match_range = { match_lnum - 1, match_col, match_text, match_next_chars }

				--- prev matches
				if match_lnum < cursor_lnum then
					table.insert(prev_matches, match_range)
				elseif match_lnum == cursor_lnum and forward == false and match_col < cursor_col then
					table.insert(prev_matches, match_range)
				elseif match_lnum == cursor_lnum and forward == true and match_col <= cursor_col then
					table.insert(prev_matches, match_range)

				--- next matches
				elseif match_lnum == cursor_lnum and forward == false and match_col >= cursor_col then
					table.insert(next_matches, match_range)
				elseif match_lnum == cursor_lnum and forward == true and match_col > cursor_col then
					table.insert(next_matches, match_range)
				elseif match_lnum > cursor_lnum then
					table.insert(next_matches, match_range)
				end
			end
		end
	end

	local matches = {}

	if relative == false and forward == false then
		matches = utils.list_reverse(utils.list_extend(prev_matches, next_matches))
	elseif relative == false and forward == true then
		matches = utils.list_extend(prev_matches, next_matches)
	elseif relative == true and forward == false then
		matches = utils.list_extend(utils.list_reverse(prev_matches), utils.list_reverse(next_matches))
	elseif relative == true and forward == true then
		matches = utils.list_extend(next_matches, prev_matches)
	end

	return matches
end

function M.get_user_input()
	local keynum, ok, char
	local separator = cache.options.separator
	local user_input = ""
	local pattern, label = "", ""
	local matches, labels_map = {}, {}
	local labels = cache.options.labels
	local need_looping = true

	local win_id = vim.api.nvim_get_current_win()
	local buf_nr = vim.api.nvim_win_get_buf(win_id)
	local cursor_pos = vim.api.nvim_win_get_cursor(win_id)
	local view = utils.win_view(win_id)

	local search_opts = {
		cursor_pos = cursor_pos, -- needed here to avoid "sliding matches" while typing the pattern
		forward = cache.options.forward_search,
		pattern_type = cache.options.pattern_type,
		relative = cache.options.relative_labels,
		scope = cache.options.search_scope,
	}

	if #cache.options.pattern > 0 then
		user_input = cache.options.pattern
	end

	if #user_input > 0 then
		pattern = user_input
		matches = M.win_find_pattern(win_id, user_input, search_opts)
		-- labels_slider.set_max(#matches)
	end

	if cache.options.search_scope == "buffer" and #matches > 0 then
		M.jump_to(matches[1])
	end

	if cache.options.auto_jump and #matches == 1 then
		need_looping = false
	end

	if need_looping == true then
		labels_map = M.create_labels_map(labels, matches, false)
		ui.show_feedbacks(buf_nr, pattern, matches, labels_map)
	end

	while need_looping == true do
		--- user input

		ok, keynum = pcall(vim.fn.getchar)
		if ok then
			char = type(keynum) == "number" and vim.fn.nr2char(keynum) or ""
			if char == keymaps.cancel or keynum == keymaps.cancel then
				user_input, labels_map = "", {}
				break
			elseif char == keymaps.delete_prev_char or keynum == keymaps.delete_prev_char then
				user_input = #user_input > 0 and user_input:sub(1, #user_input - 1) or user_input
			else
				user_input = user_input .. char
			end
		end

		--- matches

		pattern, label = extract_pattern_and_label(user_input, separator)
		matches = M.win_find_pattern(win_id, pattern, search_opts)
		labels_map = M.create_labels_map(labels, matches, false)

		if #pattern > 0 and #label > 0 then
			break
		end

		if #matches == 0 then
			if cache.options.stop_on_fail == true or char == separator then
				break
			end
			labels_map = {}
			ui.show_feedbacks(buf_nr, user_input, {}, {})
		end

		if #matches == 1 and cache.options.auto_jump then
			label = labels[1]
			break
		end

		if #matches > 0 then
			ui.show_feedbacks(buf_nr, pattern, matches, labels_map)
		end
	end

	ui.clear_feedbacks(buf_nr)

	if char == keymaps.cancel or not labels_map[label] then
		view.restore()
		return
	end

	return user_input, labels_map
end

return M
