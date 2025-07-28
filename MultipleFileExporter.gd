# ========================================
# Multiple File Exporter Mod
# Purpose: A Dungeondraft mod to export multiple files in different formats.
# ========================================

# Variables
# ========================================
var script_class = "tool"
var tool_panel
var ui_config
var search_focus

# Logging
# ========================================
const ENABLE_LOGGING = true

# Functions
# ========================================

# Logging
# ========================================
func outputlog(msg):
    if ENABLE_LOGGING:
        printraw("(%d) <Multiple File Exporter>: " % OS.get_ticks_msec())
        print(msg)
    else:
        pass

# Loading image from a texture path
# =========================================
func load_image_texture(texture_path: String):

    var image = Image.new()
    var texture = ImageTexture.new()

    # If it isn't an internal resource
    if not "res://" in texture_path:
        image.load(Global.Root + texture_path)
        texture.create_from_image(image)
    # If it is an internal resource then just use the ResourceLoader
    else:
        texture = ResourceLoader.load(texture_path)
    
    return texture

# This does all the magic of the export
# ========================================

# This function is called when the export button is pressed
# ========================================
func on_export_button_pressed():
    var export_type_list = [
        {"mode": 0, "file_extension": ".png"},
        {"mode": 1, "file_extension": ".jpg"},
        {"mode": 2, "file_extension": ".webp"},
        {"mode": 3, "file_extension": ".dd2vtt"},
        {"mode": 4, "file_extension": ".dd2vtt"}
    ]
    
    # Create timer for export delays
    var timer = Timer.new()
    timer.autostart = false
    timer.one_shot = true
    tool_panel.add_child(timer)

    # Get UI configuration values
    Global.Exporter.Quality = ui_config["export_quality"]["slider"].value
    var gridppi = ui_config["gridppi"]["spinbox"].value
    var export_delay = ui_config["export_delay"]["slider"].value
    var base_name = ui_config["output_files"]["new_dir_lineedit"].text
    var output_dir = ui_config["output_files"]["choose_dir_dialog"].current_dir
    var file_path
    var show_warning = false
    var selected_overlay_index = 0
    var export_string = {}
    var pixel_width = Global.World.Width * gridppi
    var pixel_height = Global.World.Height * gridppi

    # Calculates resoluton based on gridppi and world size
    export_string["resolution"] = str(pixel_width) + "x" + str(pixel_height)
    export_string["map_grid_size"] = str(Global.World.Width) + "x" + str(Global.World.Height)
    export_string["gridppi"] = str(gridppi) + "ppi"
    
    # Create output directory
    # ========================================
    var dir = Directory.new()
    if dir.open(output_dir) != OK:
        outputlog("directory not found: " + str(output_dir))
        return

    if not dir.dir_exists(base_name):
        var err = dir.make_dir(base_name)
        if err != OK:
            Global.Editor.Warn("Error Selecting Target Directory", 
                "The export can't be written to this directory, try choosing a target on the main drive or in Documents folder.\n" + output_dir)
            return

    # Export dialog is needed for all VTT expors and overlay levels
    # ========================================
    if ui_config["export_types"]["menubutton"].get_popup().is_item_checked(4):
        show_warning = true
    if ui_config["export_types"]["menubutton"].get_popup().get_item_count() > 5:
        if ui_config["export_types"]["menubutton"].get_popup().is_item_checked(5):
            show_warning = true

    # Set export dialog if overlay levels are used
    var overlay_popup = ui_config["overlay_levels"]["menubutton"].get_popup()
    for i in range(overlay_popup.get_item_count()):
        if overlay_popup.is_item_checked(i):
            selected_overlay_index = i
            if i == 0:
                pass
            else:
                show_warning = true
            break

    # Hanlde warning dialog to user if required
    # ========================================
    if show_warning:
        # Show warning to user
        Global.Editor.Warn("Multiple File Exports", 
            "The normal Export menu is about to pop up. There is no need to interact with it and I would recommend not doing so, the exports will happen automatically.")
        
        # Wait 5 seconds for user to read warning
        timer.start(5.0)
        yield(timer, "timeout")
        
        # Hide warning window and launch export dialog
        Global.Editor.Windows["Accept"].visible = false
        Global.Editor.exportButton.emit_signal("pressed")

        # Wait for export dialog to load
        timer.start(1.0)
        yield(timer, "timeout")

    # Process each level accordingly
    # ========================================
    
    var levels_popup = ui_config["levels"]["menubutton"].get_popup()
    var selected_level_index = 0
    var export_dialog = Global.Editor.Windows["Export"]
    var original_level_name_toggle = ui_config["levels"]["export_string_button"].pressed
    var original_overlay_name_toggle = ui_config["overlay_levels"]["export_string_button"].pressed

    # Iterate through levels in the popup menu
    # =========================================
    for level_index in range(levels_popup.get_item_count() - 1):
        
        # Only process levels that are checked for export
        if not levels_popup.is_item_checked(level_index + 1):
            continue
        
        # The name for the current level
        export_string["levels"] = levels_popup.get_item_text(level_index + 1)

        # Iterate through each overlay level
        # =========================================
        for overlay_index in range(overlay_popup.get_item_count()):

            # If the overlay level is selected, set it in the export string
            if not overlay_popup.is_item_checked(overlay_index):
                continue
            
            # Set the overlay level in the export string
            
            export_string["overlay_levels"] = overlay_popup.get_item_text(overlay_index)

            # Only process overlay controls for actual overlay levels (index 1+)
            # =========================================
            if overlay_index > 0:
                var overlay_control = export_dialog.find_node("OverlayLevelOptions", true, false)

                # To simplify the exporting of overlay levels we enable selection of the base level as well
                # If base level is present then we will set overlay to 0 to capture a base iamge
                # We also disable the export string button for base level regardles of user input
                # Due to it just outputting ground-ground which no one wants
                if levels_popup.get_item_text(level_index + 1) == overlay_popup.get_item_text(overlay_index):

                    #Disable base level export string button
                    ui_config["levels"]["export_string_button"].pressed = false

                    if overlay_control and overlay_control.has_method("select"):
                        overlay_control.select(0)
                        overlay_control.emit_signal("item_selected", 0)
                else:
                    # if the overlay and base level do not match set the overlay in the overlay control
                    if overlay_control and overlay_control.has_method("select"):
                        overlay_control.select(overlay_index)
                        overlay_control.emit_signal("item_selected", overlay_index)
            else:
                #Disable overlay level export string button if it is not selected
                ui_config["overlay_levels"]["export_string_button"].pressed = false

            # Configure the base level selection, if show warning is true we select via the gui
            # If it is not true then we select the level directly in the editor
            # ===========================================
            if show_warning:
                # Use export dialog method
                var source_level_control = export_dialog.find_node("SourceLevelOptions", true, false)
                if source_level_control and source_level_control.has_method("select"):
                    source_level_control.select(level_index)
                    source_level_control.emit_signal("item_selected", level_index)
            else:
                if Global.Editor.LevelOptions.get_item_count() > 0:
                    Global.Editor.LevelOptions.select(level_index)
                    Global.Editor.LevelOptions.emit_signal("item_selected", level_index)

            # Wait for level to be ready
            timer.start(0.5)
            yield(timer, "timeout")

            # Processing all grid options
            # ========================================
            
            var grid_popup = ui_config["grid_options"]["menubutton"].get_popup()

            for grid_options_index in range(2):
                # Only process checked grid options
                if not grid_popup.is_item_checked(grid_options_index + 1):
                    continue

                # Configure grid setting
                if grid_options_index == 0:
                    Global.Editor.ToggleGrid(true)
                    export_string["grid_options"] = "Grid"
                else:
                    Global.Editor.ToggleGrid(false)
                    export_string["grid_options"] = "NoGrid"

                # Processing all lighting options
                # ========================================
                
                var lighting_popup = ui_config["lighting"]["menubutton"].get_popup()
    
                for lighting_options_index in range(2):
                    # Only process checked lighting options
                    if not lighting_popup.is_item_checked(lighting_options_index + 1):
                        continue

                    # Configure lighting setting
                    if lighting_options_index == 0:
                        Global.Editor.ToggleLighting(true)
                        export_string["lighting"] = "Lights"
                    else:
                        Global.Editor.ToggleLighting(false)
                        export_string["lighting"] = "NoLights"

                    # Processing all export modes
                    # ========================================
                    
                    var export_types_popup = ui_config["export_types"]["menubutton"].get_popup()
                    
                    for mode in range(export_types_popup.get_item_count() - 1):
                        # Only process checked export modes
                        if not export_types_popup.is_item_checked(mode + 1):
                            continue

                        # Build file name
                        # ========================================

                        # Capture the base name
                        file_path = output_dir + "/" + base_name + "/" + base_name

                        # Iterate through export string types and add them to the filename
                        for type in ["levels", "overlay_levels", "grid_options", "lighting", "gridppi", "map_grid_size", "resolution"]:
                            
                            var should_add_to_filename = false

                            if ui_config[type]["export_string_button"].pressed:
                                # User explicitly wants this in filename
                                should_add_to_filename = true

                            elif type in ["levels", "overlay_levels", "grid_options", "lighting"]:
                            
                                var checked_count = 0
                                var popup = ui_config[type]["menubutton"].get_popup()
                                
                                for i in range(popup.get_item_count()):
                                    if popup.is_item_checked(i):
                                        checked_count += 1

                                # Special case: don't add levels if only one level exists
                                if type == "levels" and popup.get_item_count() == 2:
                                    should_add_to_filename = false
                                elif checked_count > 1:
                                    should_add_to_filename = true
                            
                            # If true we add to file name
                            if should_add_to_filename:
                                file_path += "-" + export_string[type]

                        # If you have the webp dv2tt export type selected we need to hack it to append the -WebP suffix
                        # If you do not and you select both d2vtt it will cause a conflict
                        if mode == 4:
                            file_path += "-WebP"
                        # Add file extension
                        file_path += export_type_list[mode]["file_extension"]
                        
                        # Perform the export
                        # ========================================
                        
                        outputlog("Exporting in mode(" + str(mode) + "): " + file_path)
                        Global.Exporter.Start(mode, gridppi, file_path)
                        
                        # Wait between exports to prevent crashes
                        # ========================================
                        timer.start(export_delay)
                        yield(timer, "timeout")
                        
            # if we modified the overlay name toggle then we need to reset it
            # this occurs when the user leaves the overlay level selection
            if original_overlay_name_toggle != ui_config["overlay_levels"]["export_string_button"].pressed:
                ui_config["overlay_levels"]["export_string_button"].pressed = original_overlay_name_toggle

        # if we modified the level name toggle then we need to reset it
        # this occurs when we select an overlay level that matches the base level
        if original_level_name_toggle != ui_config["levels"]["export_string_button"].pressed:
            ui_config["levels"]["export_string_button"].pressed = original_level_name_toggle
    
    # Hide export dialog if it was shown so user does not need to interact with it
    # ========================================
    if show_warning:
        if Global.Editor.Windows.has("Export") and Global.Editor.Windows["Export"]:
            Global.Editor.Windows["Export"].hide()

    # Open output folder if requested
    # ========================================
    if ui_config["open_folder"]["checkbox"].pressed:
        var separator = "\\" if OS.get_name() == "Windows" else "/"
        var folder_path = output_dir + separator + base_name
        outputlog("Opening folder: " + folder_path)
        OS.shell_open(folder_path)

    # Show completion message
    # ========================================
    Global.Editor.Warn("Multiple File Exports", "The file exports have finished, you can find them in the target directory.")

# Function to handle selection of overlay menu items
# ========================================
func on_select_overlay_menu_item(id, popupmenu):
    if id == 0:
        # If index 0 is selected, uncheck all items and check only index 0
        for i in popupmenu.get_item_count():
            popupmenu.set_item_checked(i, false)
        popupmenu.set_item_checked(0, true)
    else:
        # For other indices, allow multi-selection
        # First uncheck index 0 if it's checked (since we're selecting something else)
        if popupmenu.is_item_checked(0):
            popupmenu.set_item_checked(0, false)
        
        # Toggle the selected item
        var current_state = popupmenu.is_item_checked(id)
        popupmenu.set_item_checked(id, not current_state)
        
        # If no items are checked after unchecking, automatically check index 0
        var any_checked = false
        for i in range(1, popupmenu.get_item_count()):  # Skip index 0
            if popupmenu.is_item_checked(i):
                any_checked = true
                break
        
        if not any_checked:
            popupmenu.set_item_checked(0, true)

# Function to handle selection of file types and layers
# ========================================
func on_select_check_menu_item(id,popupmenu):
    var check = false

    if id != 0:
        if popupmenu.is_item_checked(id):
            popupmenu.set_item_checked(id, false)
            popupmenu.set_item_checked(0, false)
            check = false
            for index in range(1, popupmenu.get_item_count()):
                if popupmenu.is_item_checked(index):
                    check = true
                    break
            if not check:
                popupmenu.set_item_checked(1, true)
        else:
            popupmenu.set_item_checked(id, true)
            check = true
            for index in range(1, popupmenu.get_item_count()):
                if not popupmenu.is_item_checked(index):
                    check = false
                    break
            if check:
                popupmenu.set_item_checked(0, true)
    else:
        if popupmenu.is_item_checked(id):
            for index in range(popupmenu.get_item_count()):
                popupmenu.set_item_checked(index, false)
            popupmenu.set_item_checked(1, true)
        else:
            for index in range(popupmenu.get_item_count()):
                popupmenu.set_item_checked(index, true)


# Function to select at least one of the two options presented with the first item being "Both" for lighting and grid options
# ========================================
func on_select_one_or_other(id,popupmenu):

    if id != 0:
        if popupmenu.is_item_checked(id):
            popupmenu.set_item_checked(0,false)
            popupmenu.set_item_checked(id,false)
            if not popupmenu.is_item_checked(3-id):
                popupmenu.set_item_checked(3-id,true)
        else:
            popupmenu.set_item_checked(id,true)
            if popupmenu.is_item_checked(3-id):
                popupmenu.set_item_checked(0,true)
    else:
        if popupmenu.is_item_checked(id):
            popupmenu.set_item_checked(1,true)	
        else:
            for _i in popupmenu.get_item_count():
                popupmenu.set_item_checked(_i,true)


# When the choose overlay levels button is pressed, populate the overlay levels menu pop up
# ========================================
func on_choose_overlay_levels_button_pressed():

    # If the number of levels list in the menu is not the same as the levels in the map then regenerate the list
    if ui_config["overlay_levels"]["menubutton"].get_popup().get_item_count()-1 != Global.World.levels.size():

        ui_config["overlay_levels"]["menubutton"].get_popup().clear()
        ui_config["overlay_levels"]["menubutton"].get_popup().add_check_item("--") 
        
        for level in Global.World.levels:
            ui_config["overlay_levels"]["menubutton"].get_popup().add_check_item(level.Label)
        
        ui_config["overlay_levels"]["menubutton"].get_popup().set_item_checked(0, true)
        if Global.World.levels.size() == 1:
            ui_config["overlay_levels"]["menubutton"].get_popup().set_item_checked(0, true)
            
# When the choose export levels button is pressed, populate the levels menu pop up
# ========================================
func on_choose_export_levels_button_pressed():

    # If the number of levels list in the menu is not the same as the levels in the map then regenerate the list
    if ui_config["levels"]["menubutton"].get_popup().get_item_count()-1 != Global.World.levels.size():

        ui_config["levels"]["menubutton"].get_popup().clear()
        ui_config["levels"]["menubutton"].get_popup().add_check_item("All")
        for level in Global.World.levels:
            ui_config["levels"]["menubutton"].get_popup().add_check_item(level.Label)
        
        ui_config["levels"]["menubutton"].get_popup().set_item_checked(Global.World.GetCurrentLevel().ID + 1,true)
        if Global.World.levels.size() == 1:
            ui_config["levels"]["menubutton"].get_popup().set_item_checked(0,true)

# Once a directory has been selected
# ========================================
func on_output_dir_selected(dir: String):

    # Check if this a sub directory of the documents folder and warn and exit if not
    if not OS.get_system_dir(2) in dir:
        outputlog("Error in selecting directory: " + str(OS.get_system_dir(2)) + " " + str(dir))
        Global.Editor.Warn("Error Selecting Directory","Unfortunately you need to select a sub directory of " + str(OS.get_system_dir(2)) + " in order for this mod to work properly.")
    else:
        # Set the label to the value selected
        ui_config["output_files"]["dir_label"].text = dir
        ui_config["output_files"]["dir_label"].hint_tooltip = dir

# When athe choose dir button is hit then pop up the file dialog to choose a directory.
# ========================================
func on_choose_dir_button_pressed():
    ui_config["output_files"]["choose_dir_dialog"].popup_centered_ratio()

# Function to make and return a menu button based on a dictionary of values: "title", "icon_path", "items", "id_pressed_func", "default_index"
# ========================================
func make_menu_button(container, values: Dictionary):
    # Make menu selection for export types
    var menu_button = MenuButton.new()
    menu_button.size_flags_horizontal = 3
    menu_button.icon = load_image_texture(values["icon_path"])
    menu_button.text = values["title"]
    menu_button.get_popup().hide_on_checkable_item_selection = false
    for entry in values["items"]:
        menu_button.get_popup().add_check_item(entry)
    if menu_button.get_popup().get_item_count() > 0:
        menu_button.get_popup().set_item_checked(values["default_index"],true)
    menu_button.get_popup().connect("id_pressed",self,values["id_pressed_func"],[menu_button.get_popup()])

    container.add_child(menu_button)

    return menu_button

# Function to create a toggle button for adding export strings to filenames
# ========================================
func make_toggle_export_string_button(container, type: String):

    var button = Button.new()

    button.toggle_mode = true
    button.pressed = true
    button.hint_tooltip = "If enabled or multiple options selected, an appropriate string will be added to the export filename."
    button.icon = load_image_texture("res://ui/icons/menu/new.png")
    ui_config[type]["export_string_button"] = button
    container.add_child(button)

# Populate the configuration dropdown with available config files
# ========================================
func populate_config_dropdown():
    var config_folder = Global.Root + "/config/"
    var dir = Directory.new()

    # Ensure the folder exists
    if dir.open(config_folder) != OK:
        outputlog("Config folder not found. Creating: " + config_folder)
        dir.make_dir(config_folder)

    # Clear existing items in the dropdown
    ui_config["config_dropdown"]["dropdown"].clear()

    # Add each `.json` file in the folder to the dropdown
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".json"):
            var config_name = file_name.replace(".json", "")
            ui_config["config_dropdown"]["dropdown"].add_item(config_name)
        file_name = dir.get_next()
    dir.list_dir_end()

    # Set the first item as the default selection
    if ui_config["config_dropdown"]["dropdown"].get_item_count() > 0:
        ui_config["config_dropdown"]["dropdown"].select(0)
        ui_config["config_name"] = ui_config["config_dropdown"]["dropdown"].get_item_text(0)
        _read_config_file()
    else:
        outputlog("No configuration files found in: " + config_folder)

func _on_config_selected(index: int):
    ui_config["config_name"] = ui_config["config_dropdown"]["dropdown"].get_item_text(index)
    _read_config_file()

# Save the current settings as a new config name
# ========================================
func on_save_new_config_pressed():
    var name = ui_config["save_new_config"]["lineedit"].text.strip_edges()
    
    # Validate the input
    if name == "":
        outputlog("Configuration name cannot be empty.")
        return
    
    # Construct the file path
    var config_path = Global.Root + "/config/" + name + ".json"
    
    # Check if the file already exists
    var dir = Directory.new()
    if dir.file_exists(config_path):
        outputlog("A configuration file with this name already exists: " + name)
        return
    
    # Save the current settings to the new file
    var data: Dictionary = {}
    data["config_name"] = name
    data["grid_visible"] = ui_config["grid_options"]["menubutton"].get_popup().is_item_checked(1)
    data["grid_not_visible"] = ui_config["grid_options"]["menubutton"].get_popup().is_item_checked(2)
    data["lighting_visible"] = ui_config["lighting"]["menubutton"].get_popup().is_item_checked(1)
    data["lighting_not_visible"] = ui_config["lighting"]["menubutton"].get_popup().is_item_checked(2)
    data["ppi_export"] = ui_config["gridppi"]["spinbox"].value
    data["export_quality"] = ui_config["export_quality"]["slider"].value
    data["export_delay"] = ui_config["export_delay"]["slider"].value
    data["open_folder"] = ui_config["open_folder"]["checkbox"].pressed
    data["filename_ppi"] = ui_config["gridppi"]["export_string_button"].pressed
    data["filename_grid"] = ui_config["grid_options"]["export_string_button"].pressed
    data["filename_lighting"] = ui_config["lighting"]["export_string_button"].pressed
    data["filename_level_base"] = ui_config["levels"]["export_string_button"].pressed
    data["filename_level_overlay"] = ui_config["overlay_levels"]["export_string_button"].pressed
    data["filename_resolution"] = ui_config["resolution"]["export_string_button"].pressed
    data["filename_grid_size"] = ui_config["map_grid_size"]["export_string_button"].pressed

    data["export_formats"] = []
    var export_popup = ui_config["export_types"]["menubutton"].get_popup()
    for i in range(export_popup.get_item_count()):
        if export_popup.is_item_checked(i):
            data["export_formats"].append(export_popup.get_item_text(i))

    # Write the data to the file
    var file = File.new()
    var err = file.open(config_path, File.WRITE)
    if err == OK:
        file.store_string(JSON.print(data, "\t"))
        file.close()
        outputlog("Configuration saved to: " + config_path)
        
        # Refresh the dropdown to include the new config
        populate_config_dropdown()
        
        # Automatically select the newly saved configuration
        var dropdown = ui_config["config_dropdown"]["dropdown"]
        for i in range(dropdown.get_item_count()):
            if dropdown.get_item_text(i) == name:
                dropdown.select(i)
                ui_config["config_name"] = name
                _read_config_file()
                break

        # Clear the LineEdit
        ui_config["save_new_config"]["lineedit"].text = ""
    else:
        outputlog("Failed to save configuration: " + config_path)
        return

# Read the configuration file and update the UI
# ========================================
func _read_config_file():
    var selected_config = ui_config["config_name"]
    var config_path = Global.Root + "/config/" + selected_config + ".json"

    var file = File.new()
    var err = file.open(config_path, File.READ)

    if err != OK:
        outputlog("Config file not found: " + config_path + ". Using default configuration.")
        return

    var content = file.get_as_text()
    file.close()

    var json_result = JSON.parse(content)
    if json_result.error != OK:
        outputlog("JSON Parse Error: " + json_result.error_string() + " in " + content + " at line " + str(json_result.error_line()))
        return

    var data = json_result.result

    # Update UI based on loaded configuration
    ui_config["grid_options"]["menubutton"].get_popup().set_item_checked(1, data["grid_visible"])
    ui_config["grid_options"]["menubutton"].get_popup().set_item_checked(2, data["grid_not_visible"])
    ui_config["lighting"]["menubutton"].get_popup().set_item_checked(1, data["lighting_visible"])
    ui_config["lighting"]["menubutton"].get_popup().set_item_checked(2, data["lighting_not_visible"])
    ui_config["gridppi"]["spinbox"].value = data["ppi_export"]
    ui_config["export_quality"]["slider"].value = data["export_quality"]
    ui_config["export_delay"]["slider"].value = data["export_delay"]
    ui_config["open_folder"]["checkbox"].pressed = data["open_folder"]

    # Load new filename-related fields
    ui_config["gridppi"]["export_string_button"].pressed = data.get("filename_ppi", true)
    ui_config["grid_options"]["export_string_button"].pressed = data.get("filename_grid", true)
    ui_config["lighting"]["export_string_button"].pressed = data.get("filename_lighting", true)
    ui_config["levels"]["export_string_button"].pressed = data.get("filename_level_base", true)
    ui_config["overlay_levels"]["export_string_button"].pressed = data.get("filename_level_overlay", true)
    ui_config["resolution"]["export_string_button"].pressed = data.get("filename_resolution", true)
    ui_config["map_grid_size"]["export_string_button"].pressed = data.get("filename_grid_size", true)
    
    var export_popup = ui_config["export_types"]["menubutton"].get_popup()
    var saved_formats = data.get("export_formats", [])  # Default to an empty list if not present
    for i in range(export_popup.get_item_count()):
        var item_text = export_popup.get_item_text(i)
        if item_text in saved_formats:
            export_popup.set_item_checked(i, true)  # Check the item if it matches a saved format
        else:
            export_popup.set_item_checked(i, false)  # Uncheck the item if it doesn't match

    outputlog("Loaded configuration: " + selected_config)

# All of the UI magic
# ========================================
func make_multiple_exports_ui():

    # ========================================
    # Output Directory Selection
    # ========================================
    ui_config["output_files"] = {}
    ui_config["output_files"]["choose_dir_hbox"] = HBoxContainer.new()
    tool_panel.Align.add_child(ui_config["output_files"]["choose_dir_hbox"])

    # File dialog for selecting the output directory
    ui_config["output_files"]["choose_dir_dialog"] = FileDialog.new()
    ui_config["output_files"]["choose_dir_dialog"].mode = FileDialog.MODE_OPEN_DIR
    ui_config["output_files"]["choose_dir_dialog"].access = FileDialog.ACCESS_FILESYSTEM
    ui_config["output_files"]["choose_dir_dialog"].current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
    ui_config["output_files"]["choose_dir_dialog"].window_title = "Choose Target Directory"
    Global.Editor.get_child("Windows").add_child(ui_config["output_files"]["choose_dir_dialog"])
    ui_config["output_files"]["choose_dir_dialog"].connect("dir_selected", self, "on_output_dir_selected")

    # Directory label and button
    ui_config["output_files"]["dir_label"] = Label.new()
    ui_config["output_files"]["dir_label"].text = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
    ui_config["output_files"]["dir_label"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ui_config["output_files"]["choose_dir_button"] = Button.new()
    ui_config["output_files"]["choose_dir_button"].icon = ResourceLoader.load("res://ui/icons/menu/open.png")
    ui_config["output_files"]["choose_dir_button"].connect("pressed", self, "on_choose_dir_button_pressed")
    ui_config["output_files"]["choose_dir_button"].hint_tooltip = "Select base directory for the exports to be saved in."
    ui_config["output_files"]["choose_dir_hbox"].add_child(ui_config["output_files"]["dir_label"])
    ui_config["output_files"]["choose_dir_hbox"].add_child(ui_config["output_files"]["choose_dir_button"])

    # Directory name input
    ui_config["output_files"]["new_dir_hbox"] = HBoxContainer.new()
    ui_config["output_files"]["new_dir_label"] = Label.new()
    ui_config["output_files"]["new_dir_label"].text = "Name"
    ui_config["output_files"]["new_dir_lineedit"] = LineEdit.new()
    ui_config["output_files"]["new_dir_lineedit"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ui_config["output_files"]["new_dir_lineedit"].text = Global.World.Title
    ui_config["output_files"]["new_dir_lineedit"].hint_tooltip = "Enter a base name for the newly created output files."
    ui_config["output_files"]["new_dir_hbox"].add_child(ui_config["output_files"]["new_dir_label"])
    ui_config["output_files"]["new_dir_hbox"].add_child(ui_config["output_files"]["new_dir_lineedit"])
    tool_panel.Align.add_child(ui_config["output_files"]["new_dir_hbox"])

    # ========================================
    # Export Type Selection
    # ========================================
    ui_config["export_types"] = {}
    var menu_config = {
        "title": "Select Export Types",
        "icon_path": "res://ui/icons/menu/new.png",
        "items": ["All"],
        "id_pressed_func": "on_select_check_menu_item",
        "default_index": 1
    }
    for i in Global.Editor.Windows["Export"].find_node("ExportModeOptions").get_item_count():
        if Global.Editor.Windows["Export"].find_node("ExportModeOptions").get_item_text(i) != "Universal VTT (WebP)":
            menu_config["items"].append(Global.Editor.Windows["Export"].find_node("ExportModeOptions").get_item_text(i))
    ui_config["export_types"]["menubutton"] = make_menu_button(tool_panel.Align, menu_config)

    tool_panel.Align.add_child(HSeparator.new())  # Separator for visual clarity

    # ========================================
    # Export Quality and Grid PPI
    # ========================================
    ui_config["export_quality"] = {}
    ui_config["export_quality"]["slider"] = tool_panel.CreateSlider("ExportQualitySliderID", 85, 0, 100, 1, false)
    ui_config["export_quality"]["hbox"] = ui_config["export_quality"]["slider"].get_parent()
    ui_config["export_quality"]["label"] = Label.new()
    ui_config["export_quality"]["label"].text = "Quality"
    ui_config["export_quality"]["hbox"].add_child(ui_config["export_quality"]["label"])
    ui_config["export_quality"]["hbox"].move_child(ui_config["export_quality"]["label"], 0)

    ui_config["gridppi"] = {}
    ui_config["gridppi"]["hbox"] = HBoxContainer.new()
    ui_config["gridppi"]["label"] = Label.new()
    ui_config["gridppi"]["label"].text = "GridPPI"
    ui_config["gridppi"]["label"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ui_config["gridppi"]["spinbox"] = SpinBox.new()
    ui_config["gridppi"]["spinbox"].suffix = "pixels"
    ui_config["gridppi"]["spinbox"].min_value = 50
    ui_config["gridppi"]["spinbox"].max_value = 300
    ui_config["gridppi"]["spinbox"].value = 140
    ui_config["gridppi"]["spinbox"].align = SpinBox.ALIGN_CENTER
    ui_config["gridppi"]["spinbox"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ui_config["gridppi"]["hbox"].add_child(ui_config["gridppi"]["label"])
    ui_config["gridppi"]["hbox"].add_child(ui_config["gridppi"]["spinbox"])
    make_toggle_export_string_button(ui_config["gridppi"]["hbox"], "gridppi")
    tool_panel.Align.add_child(ui_config["gridppi"]["hbox"])

    tool_panel.Align.add_child(HSeparator.new())  # Separator for visual clarity

    # ========================================
    # Grid and Lighting Options
    # ========================================
    ui_config["grid_options"] = {}
    ui_config["grid_options"]["hbox"] = HBoxContainer.new()
    tool_panel.Align.add_child(ui_config["grid_options"]["hbox"])
    menu_config = {
        "title": "Select Grid Options",
        "icon_path": "res://ui/icons/buttons/rectangle.png",
        "items": ["Both", "Grid Enabled", "Grid Disabled"],
        "id_pressed_func": "on_select_one_or_other",
        "default_index": 1
    }
    ui_config["grid_options"]["menubutton"] = make_menu_button(ui_config["grid_options"]["hbox"], menu_config)
    make_toggle_export_string_button(ui_config["grid_options"]["hbox"], "grid_options")

    ui_config["lighting"] = {}
    ui_config["lighting"]["hbox"] = HBoxContainer.new()
    tool_panel.Align.add_child(ui_config["lighting"]["hbox"])
    menu_config = {
        "title": "Select Lighting Options",
        "icon_path": "res://ui/icons/tools/light_tool.png",
        "items": ["Both", "Lighting Enabled", "Lighting Disabled"],
        "id_pressed_func": "on_select_one_or_other",
        "default_index": 1
    }
    ui_config["lighting"]["menubutton"] = make_menu_button(ui_config["lighting"]["hbox"], menu_config)
    make_toggle_export_string_button(ui_config["lighting"]["hbox"], "lighting")

    # ========================================
    # Levels and Overlay Levels
    # ========================================
    ui_config["levels"] = {}
    ui_config["levels"]["hbox"] = HBoxContainer.new()
    tool_panel.Align.add_child(ui_config["levels"]["hbox"])
    menu_config = {
        "title": "Select Levels",
        "icon_path": "res://ui/icons/tools/level_settings.png",
        "items": [],
        "id_pressed_func": "on_select_check_menu_item",
        "default_index": 0
    }
    ui_config["levels"]["menubutton"] = make_menu_button(ui_config["levels"]["hbox"], menu_config)
    make_toggle_export_string_button(ui_config["levels"]["hbox"], "levels")
    ui_config["levels"]["menubutton"].connect("pressed", self, "on_choose_export_levels_button_pressed")
    on_choose_export_levels_button_pressed()

    ui_config["overlay_levels"] = {}
    ui_config["overlay_levels"]["hbox"] = HBoxContainer.new()
    tool_panel.Align.add_child(ui_config["overlay_levels"]["hbox"])
    menu_config = {
        "title": "Select Overlay Levels",
        "icon_path": "res://ui/icons/tools/level_settings.png",
        "items": [],
        "id_pressed_func": "on_select_overlay_menu_item",
        "default_index": 0
    }
    ui_config["overlay_levels"]["menubutton"] = make_menu_button(ui_config["overlay_levels"]["hbox"], menu_config)
    make_toggle_export_string_button(ui_config["overlay_levels"]["hbox"], "overlay_levels")
    ui_config["overlay_levels"]["menubutton"].connect("pressed", self, "on_choose_overlay_levels_button_pressed")
    on_choose_overlay_levels_button_pressed()

    # ========================================
    # Resolution Selection and Map size for file name on export
    # ========================================
    ui_config["resolution"] = {}
    ui_config["resolution"]["hbox"] = HBoxContainer.new()
    tool_panel.Align.add_child(ui_config["resolution"]["hbox"])

    # Create the resolution label
    ui_config["resolution"]["label"] = Label.new()
    ui_config["resolution"]["label"].text = "Map Resolution"
    ui_config["resolution"]["label"].hint_tooltip = "Select resolution options for export."
    ui_config["resolution"]["label"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ui_config["resolution"]["label"].icon = ResourceLoader.load("res://ui/icons/menu/export.png")
    ui_config["resolution"]["hbox"].add_child(ui_config["resolution"]["label"])

    # Add the toggle export string button
    make_toggle_export_string_button(ui_config["resolution"]["hbox"], "resolution")


    # Map Grid Size Selection
    ui_config["map_grid_size"] = {}
    ui_config["map_grid_size"]["hbox"] = HBoxContainer.new()
    tool_panel.Align.add_child(ui_config["map_grid_size"]["hbox"])

    # Create the Map Grid Size label
    ui_config["map_grid_size"]["label"] = Label.new()
    ui_config["map_grid_size"]["label"].text = "Map Grid Size"
    ui_config["map_grid_size"]["label"].hint_tooltip = "Select map grid size options for export."
    ui_config["map_grid_size"]["label"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ui_config["map_grid_size"]["hbox"].add_child(ui_config["map_grid_size"]["label"])

    # Add the toggle export string button
    make_toggle_export_string_button(ui_config["map_grid_size"]["hbox"], "map_grid_size")


    # ========================================
    # Export Delay and Export Button
    # ========================================
    ui_config["export_delay"] = {}
    ui_config["export_delay"]["slider"] = tool_panel.CreateSlider("ExportDelaySliderID", 10, 5, 180, 1, false)
    ui_config["export_delay"]["slider"].hint_tooltip = "Change the delay in seconds between export jobs starting."
    ui_config["export_delay"]["hbox"] = ui_config["export_delay"]["slider"].get_parent()
    ui_config["export_delay"]["label"] = Label.new()
    ui_config["export_delay"]["label"].text = "Export Delay"
    ui_config["export_delay"]["label"].hint_tooltip = "Change the delay between export jobs starting."
    ui_config["export_delay"]["hbox"].add_child(ui_config["export_delay"]["label"])
    ui_config["export_delay"]["hbox"].move_child(ui_config["export_delay"]["label"], 0)

    tool_panel.Align.add_child(HSeparator.new())

    ui_config["do_export"] = {}
    ui_config["do_export"]["button"] = Button.new()
    ui_config["do_export"]["button"].text = "Start Export"
    ui_config["do_export"]["button"].hint_tooltip = "Note that exporting multiple levels & formats will take some time."
    ui_config["do_export"]["button"].connect("pressed", self, "on_export_button_pressed")
    ui_config["do_export"]["button"].icon = ResourceLoader.load("res://ui/icons/menu/export.png")
    tool_panel.Align.add_child(ui_config["do_export"]["button"])

    # ========================================
    # Open Folder Checkbox
    # ========================================
    ui_config["open_folder"] = {}
    ui_config["open_folder"]["checkbox"] = CheckBox.new()
    ui_config["open_folder"]["checkbox"].text = "Open Target Folder on Completion"
    ui_config["open_folder"]["checkbox"].hint_tooltip = "Automatically open the target folder in file explorer when a new export directory is created."
    ui_config["open_folder"]["checkbox"].pressed = true
    tool_panel.Align.add_child(ui_config["open_folder"]["checkbox"])

    tool_panel.Align.add_child(HSeparator.new())

    # ========================================
    # Configuration Management
    # ========================================
    ui_config["config_dropdown"] = {}
    ui_config["config_dropdown"]["vbox"] = VBoxContainer.new()
    var config_margin = MarginContainer.new()
    config_margin.custom_constants.margin_top = 250
    ui_config["config_dropdown"]["vbox"].add_child(config_margin)
    ui_config["config_dropdown"]["label"] = Label.new()
    ui_config["config_dropdown"]["label"].text = "Select Configuration"
    ui_config["config_dropdown"]["label"].align = Label.ALIGN_CENTER
    ui_config["config_dropdown"]["dropdown"] = OptionButton.new()
    ui_config["config_dropdown"]["dropdown"].connect("item_selected", self, "_on_config_selected")
    ui_config["config_dropdown"]["vbox"].add_child(ui_config["config_dropdown"]["label"])
    ui_config["config_dropdown"]["vbox"].add_child(ui_config["config_dropdown"]["dropdown"])
    tool_panel.Align.add_child(ui_config["config_dropdown"]["vbox"])
    populate_config_dropdown()

    ui_config["save_new_config"] = {}
    ui_config["save_new_config"]["vbox"] = VBoxContainer.new()
    var save_margin = MarginContainer.new()
    save_margin.custom_constants.margin_top = 250
    ui_config["save_new_config"]["vbox"].add_child(save_margin)
    ui_config["save_new_config"]["label"] = Label.new()
    ui_config["save_new_config"]["label"].text = "Save New Configuration"
    ui_config["save_new_config"]["label"].align = Label.ALIGN_CENTER
    ui_config["save_new_config"]["lineedit"] = LineEdit.new()
    ui_config["save_new_config"]["lineedit"].placeholder_text = "New Configuration Name"
    ui_config["save_new_config"]["button"] = Button.new()
    ui_config["save_new_config"]["button"].text = "Save"
    ui_config["save_new_config"]["button"].connect("pressed", self, "on_save_new_config_pressed")
    ui_config["save_new_config"]["vbox"].add_child(ui_config["save_new_config"]["label"])
    ui_config["save_new_config"]["vbox"].add_child(ui_config["save_new_config"]["lineedit"])
    ui_config["save_new_config"]["vbox"].add_child(ui_config["save_new_config"]["button"])
    tool_panel.Align.add_child(ui_config["save_new_config"]["vbox"])

# this method is automatically called every frame. delta is a float in seconds. can be removed from script.
# ===========================================
func update(delta: float):

    # Check whether the search entry fields have focus
    var has_focus = Global.Editor.Toolset.get_focus_owner()

    # If the previous search entry does not have focus, then we have moved the focus to something else so set the SearchHasFocus property back to false
    if has_focus != search_focus && search_focus != null:
        # Set the previous search value to null so we don't overwrite DD setting the SearchHasFocus process
        search_focus = null
        Global.Editor.SearchHasFocus = false

    # This seems excessive for just checking an search entry field but it works so...
    if has_focus == ui_config["output_files"]["new_dir_lineedit"]:
        search_focus = ui_config["output_files"]["new_dir_lineedit"]
        Global.Editor.SearchHasFocus = true
        
# Main Script
# =========================================
func start() -> void:

    outputlog("Multiple File Exporter Mod Has been loaded.")

    # Make a new tool under the Objects menu option
    var category = "Effects"
    var id = "MultipleFileExporter"
    var name = "Multiple File Exporter"
    var icon = "res://ui/icons/menu/export.png"
    tool_panel = Global.Editor.Toolset.CreateModTool(self, category, id, name, icon)

    ui_config = {}
    make_multiple_exports_ui()