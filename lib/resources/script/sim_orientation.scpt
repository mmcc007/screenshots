on run argv
  my do_submenu("Simulator", "Hardware", "Orientation", item 1 of argv)
  return item 1 of argv
end run

on do_submenu(app_name, menu_name, menu_item, submenu_item)
    try
        -- bring the target application to the front
        tell application app_name
            activate
        end tell
        tell application "System Events"
            tell process app_name
                tell menu bar 1
                    tell menu bar item menu_name
                        tell menu menu_name
                            tell menu item menu_item
                                tell menu menu_item
                                    click menu item submenu_item
                                end tell
                            end tell
                        end tell
                    end tell
                end tell
            end tell
        end tell
        return true
    on error error_message
        return false
    end try
end do_submenu
