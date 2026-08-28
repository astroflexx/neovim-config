-- autosave.lua is a plugin to autosave files as you edit them

return {
  "okuuva/auto-save.nvim",
  cmd = "ASToggle",
  event = { "InsertLeave", "TextChanged", "TextChangedI" },
  opts = {
    debounce_delay = 100,
    trigger_events = {
      defer_save = { "InsertLeave", "TextChanged", "TextChangedI" },
    },
  },
}
