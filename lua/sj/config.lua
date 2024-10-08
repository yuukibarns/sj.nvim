local utils = require("sj.utils")

------------------------------------------------------------------------------------------------------------------------

local function is_boolean(v)
	return type(v) == "boolean"
end

local function is_char(v)
	return type(v) == "string" and v:len() == 1
end

local function is_unsigned_number(v)
	return type(v) == "number" and v > -1
end

local function is_string(v)
	return type(v) == "string"
end

local function is_string_and_not_empty(v)
	return type(v) == "string" and v:len() > 0
end

local function valid_keymaps(v)
	if type(v) ~= "table" then
		return false
	end

	for key, val in pairs(v) do
		if type(key) ~= "string" or type(val) ~= "string" then
			return false
		end
	end

	return true
end

local function valid_highlights(v)
	if type(v) ~= "table" then
		return false
	end

	for _, val in pairs(v) do
		if type(val) ~= "table" then
			return false
		end
	end

	return true
end

local function valid_labels(labels)
	if type(labels) ~= "table" then
		return false
	else
		return #labels > 0 and #vim.tbl_filter(is_char, labels) == #labels
	end
end

------------------------------------------------------------------------------------------------------------------------

local checks = {
	auto_jump = { func = is_boolean, message = "must be a boolean" },
	highlights = { func = valid_highlights, message = "must be a table with tables as values" },
	inclusive = { func = is_boolean, message = "must be a boolean" },
	keymaps = { func = valid_keymaps, message = "must be a table with string as values" },
	labels = { func = valid_labels, message = "must be a list of characters" },
	max_pattern_length = { func = is_unsigned_number, message = "must be an unsigned number" },
	pattern = { func = is_string, message = "must be a string" },
	pattern_type = { func = is_string, message = "must be a string" },
	preserve_highlights = { func = is_boolean, message = "must be a boolean" },
	prompt_prefix = { func = is_string, message = "must be a string" },
	search_scope = { func = is_string, message = "must be a string" },
	separator = { func = is_string_and_not_empty, message = "must be a nonempty string" },
	stop_on_fail = { func = is_boolean, message = "must be a boolean" },
	use_overlay = { func = is_boolean, message = "must be a boolean" },
}

local M = {
	defaults = {
		auto_jump = false, -- if true, automatically jump on the sole match
		inclusive = true, -- if true, the jump target will be included with 'operator-pending' and 'visual' modes
		max_pattern_length = 0, -- if > 0, wait for a label after N characters
		pattern = "", -- predefined pattern to use at the start of a search
		pattern_type = "vim", -- how to interpret the pattern (lua_plain, lua, vim, vim_very_magic)
		preserve_highlights = true, -- if true, create an autocmd to preserve highlights when switching colorscheme
		prompt_prefix = "", -- if set, the string will be used as a prefix in the command line
		search_scope = "visible_lines", -- (current_line, visible_lines_above, visible_lines_below, visible_lines)
		separator = ":", -- character used to split the user input in <pattern> and <label> (should not be empty)
		stop_on_fail = true, -- if true, the search will stop when a search fails (no matches), if false, when there are no match type the separator will end the search.
		use_overlay = true, -- if true, apply an overlay to better identify labels and matches

		--- keymaps used during the search
		keymaps = {
			cancel = "<Esc>", -- cancel the search
			delete_prev_char = "<BS>", -- delete the previous character
		},

		--- labels used for each matches. (one-character strings only)
		-- stylua: ignore
		labels = {
			"a", "s", "d", "f", "g", "h", "j", "k", "l", "q", "w", "e", "r",
			"t", "y", "u", "i", "o", "p", "z", "x", "c", "v", "b", "n", "m",
			"A", "S", "D", "F", "G", "H", "J", "K", "L", "Q", "W", "E", "R",
			"T", "Y", "U", "I", "O", "P", "Z", "X", "C", "V", "B", "N", "M",
		},
	},
}

function M.filter_options(opts)
	local filtered = {}
	local warnings = {}

	for key, o in pairs(checks) do
		if o.func(opts[key]) == true then
			filtered[key] = opts[key]
		else
			filtered[key] = o.default
		end

		if opts[key] ~= nil and filtered[key] == nil then
			table.insert(warnings, ("'%s' option " .. o.message):format(key))
		end
	end

	utils.warn(warnings)
	return filtered
end

return M
