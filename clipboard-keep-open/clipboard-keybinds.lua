-- >>> clipboard-keep-open >>>
-- SUPER+V (clipboard) and SUPER+. (emoji) open the overview search; releasing SUPER afterwards used to toggle it shut again,
-- because the lone-SUPER "toggle on release" shortcut was never told another key was pressed. Tell it (interrupt) on press.
hl.bind("SUPER + V", hl.dsp.global("quickshell:searchToggleReleaseInterrupt"))
hl.bind("SUPER + Period", hl.dsp.global("quickshell:searchToggleReleaseInterrupt"))
-- <<< clipboard-keep-open <<<
