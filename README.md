<!--
vim: expandtab tabstop=2
-->

- [Requirements](#requirements)
- [Usage](#usage)
- [Configuration](#configuration)
- [Why this plugin ?](#why)

## SJ - Search and Jump

Search based navigation combined with quick jump features.

<p align="center">
  Demo<br>
  <img src="https://user-images.githubusercontent.com/111681540/197946515-e2818592-bf3d-439a-99f3-8c9eabd2fbce.gif">
</p>

<p align="center">
  Screenshots<br>
  <img src="https://user-images.githubusercontent.com/111681540/197934569-999dba0d-bbd2-4a9b-8be5-997207ac0cc0.png">
  <img src="https://user-images.githubusercontent.com/111681540/197934582-b860c767-64f4-4b44-b38b-007afb4e8cc1.png">
</p>

### Requirements

Only [Neovim 0.9+](https://github.com/neovim/neovim/releases) is required, nothing more.

### Usage

The main goal of this plugin is to quickly jump to any characters using a search pattern.

By default, the search is made forward and only in visible lines of the current buffer.

To start using SJ, you can add the lines below in your configuration for Neovim.

```lua
local sj = require("sj")
sj.setup()

vim.keymap.set("n", "s", sj.run)
```

As soon as you use the keymap assigned to `sj.run()` and start typing the pattern :

- the highlights in the buffer will change ;
- all matches will be highlighted and will have a label assigned to them ;

While searching, you can use the keymaps below :

| Keymap     | Description                   |
| ---------- | ----------------------------- |
| `<Escape>` | cancel the search             |
| `<BS>`     | delete the previous character |

### Configuration

Here is the default configuration :

```lua
defaults = {
		auto_jump = false, -- if true, automatically jump on the sole match
		forward_search = true, -- if true, the search will be done from top to bottom
		inclusive = true, -- if true, the jump target will be included with 'operator-pending' and 'visual' modes
		max_pattern_length = 0, -- if > 0, wait for a label after N characters
		pattern = "", -- predefined pattern to use at the start of a search
		pattern_type = "vim", -- how to interpret the pattern (lua_plain, lua, vim, vim_very_magic)
		preserve_highlights = true, -- if true, create an autocmd to preserve highlights when switching colorscheme
		prompt_prefix = "", -- if set, the string will be used as a prefix in the command line
		relative_labels = false, -- if true, labels are ordered from the cursor position, not from the top of the buffer
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
			"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
			"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
			"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
			"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
		},
},
```

and here is a configuration sample :

```lua
local sj = require("jump")
local sj_cache = require("jump.cache")

--- Configuration ------------------------------------------------------------------------

sj.setup({
  prompt_prefix = "/",

  -- stylua: ignore
  highlights = {
    SjFocusedLabel = { bold = false, italic = false, fg = "#FFFFFF", bg = "#C000C0", },
    SjLabel =        { bold = true , italic = false, fg = "#000000", bg = "#5AA5DE", },
    SjLimitReached = { bold = true , italic = false, fg = "#000000", bg = "#DE945A", },
    SjMatches =      { bold = false, italic = false, fg = "#DDDDDD", bg = "#005080", },
    SjNoMatches =    { bold = false, italic = false, fg = "#DE945A",                 },
    SjOverlay =      { bold = false, italic = false, fg = "#345576",                 },
  },
})
```

## Why

Why this plugin ?! Well, let me explain ! :smiley:

Using vertical/horizontal navigation with `<count>k/j`, `:<count><CR>`,
`H/M/L/f/F/t/T/,/;b/e/w^/$`, is a very good way to navigate. But with the keyboards I use,
I have to press the `<Shift>` key to type numbers and some of them are a bit to far for my
fingers. Once on the good line, I have to repeat pressing some horizontal movement keys
too much.

When navigating in a buffer, I often find the search based navigation to be easier, faster
and more precise. But if there are too many matches, I have to repeat pressing a key to
cycle between the matches. By adding jump features with labels, I can quickly jump to the
match I want.

For me, one small caveat of the 'jump plugins', is that they generate the labels or 'hint
keys' based on the cursor position. That is understandable and efficient but within the
same buffer area, it means that you can have different labels for the same pattern or
position which make the keys sequence for a jump less predictables. Also, in some
contexts, you don't know if you'll have to use a 1, 2 or 3 characters for the label.

By using a search pattern with a 1-character label, you already know all the keys except
one character for the label.

```

```
