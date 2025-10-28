# ARGMARK - Neovim plugin for more effectively utilizing the arglist

Tiny neovim plugin to turn your arglist into a more useful tool.

It provides:

- An editable buffer like [harpoon](https://github.com/ThePrimeagen/harpoon)'s or [grapple](https://github.com/cbochs/grapple.nvim)'s to allow you to change the entries in ANY of your arglists.

- Some functions which can be used to more easily use the argslist in lua code,

- A setup function as a shorthand to define keybindings for common buffer actions using those functions.

- Functions providing display text which may be used as a lualine component.

## Why use this? I already have harpoon or grapple

I use one of those alongside this plugin. They serve different purposes for me.

I found I tend to not use them for bookmarks I will only need for the current session, because then I would need to remember to delete them.

I find myself only using those plugins for things that I will need to access often for the forseeable future because of this.

The neovim arglist is local to that session, so I find myself using this a lot more for anything that isn't something I will want bookmarked for a long time.

However, any session saving like `mksession` or any of the plugins which wrap it will also still allow you to save them, if you want.


## Install:

```lua
vim.pack.add("https://github.com/BirdeeHub/argmark")
-- You may omit this call if you would rather use the functions it exports to make your own keybindings
require("argmark").setup {}
```

or other equivalent method. It is a single lua file.

Here's the lazy.nvim example:

```lua
require("lazy").setup {
    -- Your other plugin specs here...
    { "https://github.com/BirdeeHub/argmark", opts = { --[[passed to setup]] } }
    -- Your other plugin specs here...
}
```

## Reference/Usage:

All functions (except setup) accept an optional `tar_win_id` parameter (`integer`).

If `tar_win_id == -1`, the function is guaranteed to operate on the **global arglist**.
If omitted, the **current window** is used.
Otherwise, the argslist corresponding to the window with the given id is used.

---

### `argmark.setup(opts?: { keys?: table, edit_opts?: table })`

Registers normal-mode keybindings for arglist manipulation.

Each keybinding may be changed.
Global keybindings (the ones not in the edit window) may also disabled with `false`.

```lua
require("argmark").setup {
    keys = {
        rm = "<leader><leader>x",
        go = "<leader><leader><leader>",
        add = "<leader><leader>a",
        edit = "<leader><leader>e",
        clear = "<leader><leader>X",
        add_windows = "<leader><leader>A",
    },
    edit_opts = {
        keys = {
            cycle_right = "<leader><leader>n",
            cycle_left = "<leader><leader>p",
            go = "<CR>",
            quit = "Q",
            exit = "q",
        }
    }
}
```

**Default mappings:**

```
<leader><leader>a   add current buffer (accepts a count, meaning buffer number to add instead of current)
<leader><leader>x   remove current buffer (accepts a count, meaning arglist index to remove instead of current)
<leader><leader>X   clear arglist
<leader><leader><leader>   go to arg under count (accepts a count, meaning arglist index to go to)
<leader><leader>e   open floating arglist editor
<leader><leader>A   add all window buffers
```

---

### `argmark.edit(opts?: table, tar_win_id?: integer)`

Opens an editable floating window showing the contents of the current arglist,
and a display to show which arglist you are in.

It defines keybindings to cycle through the arglists, and open the current argument

The list updates when the buffer is written (`:w`) or when you quit (`Q`).

Exiting in another manner than the quit or exit keys, e.g. `<c-w>q`, will ask if you want to save first.

**Optional keys in `opts`:**

* `keys`: table defining overrides for in-buffer keymaps

  * `cycle_right` (`string?`)
  * `cycle_left` (`string?`)
  * `go` (`string?`)
  * `quit` (`string?`)
  * `exit` (`string?`)

**Default in-buffer mappings:**

```
<CR>                open file under cursor
<leader><leader>n   cycle right through arglists
<leader><leader>p   cycle left through arglists
Q                   (quit) update and close
q                   (exit) close
```

---

### `argmark.get_display_text(tar_win_id?: integer) → string`

Returns a formatted string representation of the arglist for `tar_win_id`.

Highlights the current argument with brackets `[name]`.

Displays which arglist you are in if not global

Useful for statusline or tabline components.

For example this function can be used directly as a lualine component:

```lua
require('lualine').setup {
    tabline = {
        lualine_x = { require("argmark").get_display_text },
    }
}
```

---

### `argmark.get_arglist_display_text(tar_win_id?: integer) → string`

Returns a short label summarizing which arglists exist and which the given window belongs to.
Example:

```
"[Global] L:1 L:2"
```

This may be used as a lualine component as well if desired, but its main purpose is to display which arglist you are in for the edit window.

---

### `argmark.add(num_or_name_s?: integer|string|string[], tar_win_id?: integer)`

Adds one or more entries to the arglist of the specified window.
**Parameters:**

* `num_or_name_s`:

  * `integer`: buffer number (adds that buffer)
  * `string`: file path
  * `string[]`: list of file paths
  * *nil*: adds current buffer (`%`)
* `tar_win_id`: window id or `-1` for global list, defaults to current

Duplicates are automatically removed with `:argdedupe`.

---

### `argmark.go(num?: integer, tar_win_id?: integer)`

Jumps to an argument entry by position.
**Parameters:**

* `num`: argument index (1-based)
* `tar_win_id`: window id or `-1` for global list, defaults to current

If `num` is omitted, reopens the current argument.
Errors if arglist is empty.

---

### `argmark.rm(num_or_name?: integer|string|string[], num?: integer, tar_win_id?: integer)`

Removes arguments from the list.
**Parameters:**

* `num_or_name`:

  * `integer`: starting index
  * `string`: filename
  * `string[]`: filenames
  * *nil*: defaults to current buffer (`%`)
* `num`: optional end index when deleting by range
* `tar_win_id`: window id or `-1` for global list, defaults to current

Examples:

```lua
local argmark = require('argmark')
argmark.rm(3)         -- remove arg 3  
argmark.rm(2, 5)      -- remove args 2–5  
argmark.rm("foo.lua") -- remove by name
```

---

### `argmark.add_windows(tar_win_id?: integer)`

Adds the main buffers of all windows to the arglist for the target window.
Duplicates removed automatically.
