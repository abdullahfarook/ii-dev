-- A left click ends type-search's keyboard capture (non-consuming: the click still reaches the target).
hl.bind("mouse:272", hl.dsp.global("typesearch:click"), { non_consuming = true, description = "type-search: release keyboard on click" })

-- Float mode: like SUPER+ALT+Space, but for the whole workspace (current and future windows).
hl.bind("SUPER + ALT + G", hl.dsp.global("floatws:toggle"), { description = "Workspace: toggle float mode for new windows" })
