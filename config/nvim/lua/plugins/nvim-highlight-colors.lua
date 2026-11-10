return {
  {
    "brenoprata10/nvim-highlight-colors",
    lazy = false,
    event = "BufReadPre",
    opts = {
      render = "virtual", -- 'background'|'foreground'|'virtual'
      virtual_symbol = "■",
      enable_hex = true,
      enable_rgb = true,
      enable_hsl = true,
      enable_var_usage = true,
      enable_named_colors = true,
    },
  },
}
