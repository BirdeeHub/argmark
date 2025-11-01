# ARGMARK - Neovim plugin for more effectively utilizing the arglist

Tiny neovim plugin to turn your arglist into a more useful tool.

It provides:

- An editable buffer like [harpoon](https://github.com/ThePrimeagen/harpoon)'s or [grapple](https://github.com/cbochs/grapple.nvim)'s to allow you to change the entries in ANY of your arglists.

- Some functions which can be used to more easily use the argslist in lua code,

- A setup function as a shorthand to define keybindings for common buffer actions using those functions.

- Functions providing display text which may be used as a lualine component.

---

## Why use this? What would that look like?

#### (or, I already have harpoon or grapple? Why more lists?)

Global marks are the usual way of holding a location to go back to across files.

But you have to remember which letter it was, it is very easy to forget which goes where, they persist across sessions, and into different projects, etc.

I found them to be not super enjoyable to use across buffers when I had more than 1 or 2 marks active.

In addition, they always take you to one particular place in a file, when often, what you want is where you were LAST within that file.

Then [harpoon](https://github.com/ThePrimeagen/harpoon)/[grapple](https://github.com/cbochs/grapple.nvim) came along and gave us a nice way to easily have an editable shortlist of files.

But because the bookmarks persist, I found myself using them only for relatively static and long-lived bookmarks.

Persistent bookmarks are useful.

But I was hesitant to use them for bookmarks I will only need for the current session, because then I would need to delete them too.

This means they were not solving my most common buffer navigation needs.

The neovim arglist, however, does not persist (unless you save the session with `mksession` or something similar).

This means, as you go along, files you may have to return to you can simply add to the list.
That way, you can easily have a shortlist for just this session, or maybe even just that window with local arglists.

You can then edit that shortlist in an easy to use floating buffer, add, delete, and copy to the lists, etc.

In addition, you may have something else which populates the arglist, such as a plugin like [vim-dirvish](https://github.com/justinmk/vim-dirvish).

If you want a nice interface to use and edit that, this plugin provides that with its edit window.

The edit window and copy keybindings make managing local arglists easier as well.

You will likely still wish to keybind some of the other builtin arglist functions/commands.
This is because this plugin is meant to augment, not replace, the neovim arglist.

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
        edit = "<leader><leader>e",
        rm = "<leader><leader>x",
        go = "<leader><leader><leader>",
        add = "<leader><leader>a",
        copy = "<leader><leader>c",
        clear = "<leader><leader>X",
        add_windows = "<leader><leader>A",
    },
    edit_opts = {
        keys = {
            cycle_right = "<leader><leader>n",
            cycle_left = "<leader><leader>p",
            go = "<CR>",
            quit = "Q" -- save and quit
            exit = "q" -- exit
            -- :write or :w also saves, but doesn't quit
        }
        display = {
            arglist_display_func = nil
            border = nil
            footer = nil
            footer_pos = nil
            title_pos = nil
        }
    }
}
```

**Default mappings:**

```
<leader><leader>e   open floating arglist editor
<leader><leader>a   add current buffer (accepts a count, meaning buffer number to add instead of current)
<leader><leader>x   remove current buffer (accepts a count, meaning arglist index to remove instead of current)
<leader><leader>X   clear arglist
<leader><leader><leader>   go to current arg (accepts a count, meaning arglist index to go to)
<leader><leader>c   copy global arglist into local arglist (accepts a count, meaning the arglist to copy instead of global)
<leader><leader>A   add all window buffers
```

Note: "accepts a count" means that you can input a number before inputting the keybinding. ([:help count](https://neovim.io/doc/user/intro.html#count))

Note 2: Outside of using the `go` keybinding, to change which is the "current argument" in the argslist, use `:n`/`:next` or `:N`/`:prev`.

Note 3: To change back to the global argslist after creating a local one with `:arglocal` or the copy keybind, use `:argglobal`. Then to reenter it, you can use `:arglocal` again.

You can map them to something if desired, but the argslist is a builtin thing,
and many of the builtin methods are good enough.
That being said, they usually only target the current window's arglist.
So a few more lua functions which allow you to select the global list as well as by window may be added eventually.

---

### `argmark.get_display_text(tar_win_id?: integer, format_name?, format_list_id?) → string`

**Parameters**:
- `tar_win_id?`: `integer`,
- `format_name?`: `fun(name: string, focused: boolean, idx: integer): string`
- `format_list_id?`: `fun(id: integer): string?`

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

The default implementation of format_name and format_list_id are:

```lua
local function default_format_name(name, focused, idx)
  name = vim.fn.fnamemodify(name, ":t")
  if name == "" then name = vim.fn.fnamemodify(name .. ".", ":h:t") end
  if name == "" then name = "~No~Name~" end
  if focused then name = "["..name.."]" end
  return name
end
local function default_format_id(id)
  return id ~= 0 and "L"..id..":" or nil
end
```

---

### `argmark.edit(opts?: table, tar_win_id?: integer)`

Opens an editable floating window showing the contents of the current arglist,
and a display to show which arglist you are in.

It defines keybindings to cycle through the arglists, and open the current argument

The list updates when the buffer is written (`:w`) or when you quit (`Q`).

It saves only the currently selected arglist on write or `Q`

Exiting in another manner than the quit or exit keys, e.g. `<c-w>q`, will ask if you want to save first.

**Optional keys in `opts`:**

* `keys`: table defining overrides for in-buffer keymaps

  * `cycle_right` (`string?`)
  * `cycle_left` (`string?`)
  * `go` (`string?`)
  * `quit` (`string?`)
  * `exit` (`string?`)

* `display` table defining various display options

  * `arglist_display_func` (`nil|fun(id: integer, focused: boolean): string?`) passed as second argument to `argmark.get_arglist_display_text`
  * `border` (`string|string[]?`) see [:h nvim_open_win()](https://neovim.io/doc/user/api.html#nvim_open_win())
  * `title_pos` (`string?`) see [:h nvim_open_win()](https://neovim.io/doc/user/api.html#nvim_open_win())
  * `footer` (`string?`) see [:h nvim_open_win()](https://neovim.io/doc/user/api.html#nvim_open_win())
  * `footer_pos` (`string?`) see [:h nvim_open_win()](https://neovim.io/doc/user/api.html#nvim_open_win())

**Default in-buffer mappings:**

```
<CR>                open file under cursor
<leader><leader>n   cycle right through arglists
<leader><leader>p   cycle left through arglists
Q                   (quit) update and close
q                   (exit) close
```

---

### `argmark.copy(arglist_id?: number, tar_win_id?: integer)`

Copy the contents of one arglist into another window's arglist (or the global list).

This function allows transferring argument lists between windows,
or between the global arglist and a window-local arglist.

It supports copying either the global list (id = 0) or any existing
window-local arglist identified by its `arglist_id`.

- If `arglist_id` is `0`, the **global** arglist is copied.
- If `arglist_id` matches a window-local arglist, that list is copied.
- If `tar_win_id` refers to a normal window, the copied list replaces its local arglist, or if it did not have one, creates a new one with the contents.
- If `tar_win_id` is `-1`, the copied list replaces the **global** arglist.
- If the target window previously had a local arglist and the global list is
  modified instead, its original local list is restored afterward.

---

### `argmark.get_arglist_display_text(tar_win_id?: integer, format_list_id?) → string`

**Parameters**:
- `tar_win_id?`: `integer`,
- `format_list_id?`: `fun(id: integer, focused: boolean): string`

Returns a short label summarizing which arglists exist and which the given window belongs to.
Example:

```
"[Global] L:1 L:2"
```

This may be used as a lualine component as well if desired, but its main purpose is to display which arglist you are in for the edit window.

Default implementation of format_list_id:

```lua
local function default_format_list_id(id, focused)
  if id == 0 then
    if focused then
      return "[Global]"
    else
      return "Global"
    end
  elseif focused then
    return "[L:" .. id .. "]"
  else
    return "L:" .. id
  end
end
```

---

### `argmark.add(num_or_name_s?: integer|string|string[], tar_win_id?: integer, target_arg_idx?: integer)`

Adds one or more entries to the arglist of the specified window.

**Parameters:**

* `num_or_name_s`:

  * `integer`: buffer number (adds that buffer)
  * `string`: file path
  * `string[]`: list of file paths
  * *nil*: adds current buffer (`%`)
* `tar_win_id`: window id or `-1` for global list, defaults to current
* `target_arg_idx`: target index for the new item (1-based). Will insert at that index, and move higher elements up 1

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
