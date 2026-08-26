-- autosave.lua is a plugin to autosave files as you edit them

return {
  "okuuva/auto-save.nvim",
  cmd = "ASToggle",
  event = { "InsertLeave", "TextChanged", "TextChangedI" },
  opts = {
    trigger_events = {
      immediate_save = { "BufLeave", "FocusLost", "QuitPre", "VimSuspend" },
      defer_save = { "InsertLeave", "TextChanged", "TextChangedI" },
      cancel_deferred_save = { "InsertEnter" },
    },
    debounce_delay = 50,
  },
}
