-- >>> super-d-empty >>>
-- SUPER + D: if the current workspace has a window, jump to the next empty workspace (replaces "Window: Maximize").
hl.unbind("SUPER + D")
hl.bind("SUPER + D", function()
    -- tell the lone-SUPER "search on release" shortcut another key was pressed, so letting go of SUPER opens nothing
    hl.dispatch(hl.dsp.global("quickshell:searchToggleReleaseInterrupt"))
    if hl.get_active_window() ~= nil then
        hl.dispatch(hl.dsp.focus({ workspace = "emptyn" }))
    end
end, { description = "Workspace: Next empty (if current has windows)" })
-- <<< super-d-empty <<<
