"resource/ui/menus/panels/lab_mods.res"
{
	ScreenFrame
    {
        ControlName				ImagePanel
        xpos					0
        ypos					0
        wide					%100
        tall					%100
        visible					1
        enabled 				1
        scaleImage				1
        image					"vgui/HUD/white"
        drawColor				"0 0 0 0"
    }


	ModeOptionsPanel
    {
        ControlName			    CNestedPanel
        InheritProperties       SettingsTabPanel
        tall                    830

		visible                 1
        pin_to_sibling			ScreenFrame
        pin_corner_to_sibling	TOP
        pin_to_sibling_corner	TOP

        ScrollFrame
        {
            ControlName				ImagePanel
            InheritProperties       SettingsScrollFrame
            tall                    830
        }

        ScrollBar
        {
            ControlName				RuiButton
            InheritProperties       SettingsScrollBar

            pin_to_sibling			ScrollFrame
            pin_corner_to_sibling	TOP_RIGHT
            pin_to_sibling_corner	TOP_RIGHT
        }

        ContentPanel
        {
            ControlName				CNestedPanel
            InheritProperties       SettingsContentPanel
			tall                    1400
			visible                 1
            tabPosition             1

            HeirloomHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                xpos					0
                ypos					6
            }
            HeirloomHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			HeirloomHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"HEIRLOOM"
            }

            SwitchHeirloom
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "..."	0
                }
                pin_to_sibling			HeirloomHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        MultiChoiceButtonAlways
                navDown                 SwitchHeirloomColor
            }

            SwitchHeirloomColor
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "..."	0
                }
                pin_to_sibling			SwitchHeirloom
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   SwitchHeirloom
            }
            HeirloomRgbPanel
            {
                ControlName				CNestedPanel
                className               "SettingScrollSizer"
                xpos					0
                ypos					0
                wide					1040
                tall					300
                visible					0
                pin_to_sibling			SwitchHeirloomColor
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT

                Plate
                {
                    ControlName				RuiPanel
                    xpos					0
                    ypos					0
                    wide					1040
                    tall					300
                    visible					1
                    rui						"ui/fs_heirloom_rgb.rpak"
                }
                H_Slider
                {
                    ControlName				SliderControl
                    InheritProperties		ColorSlider
                    xpos					-20
                    ypos					-50
                    zpos					100
                    minValue				0.0
                    maxValue				0.99
                    stepSize				0.001
                    inverseFill				0
                    showLabel				0
                    navDown					SV_Slider
                    pin_to_sibling			Plate
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_LEFT
                }
                SV_Slider
                {
                    ControlName				SliderControl
                    InheritProperties		ColorSlider
                    ypos					8
                    zpos					100
                    minValue				0.0
                    maxValue				1.0
                    stepSize				0.001
                    inverseFill				0
                    showLabel				0
                    navUp					H_Slider
                    navDown					BtnSwatch0
                    pin_to_sibling			H_Slider
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	BOTTOM_LEFT
                }
                BtnSwatch0
                {
                    ControlName				RuiButton
                    wide					52
                    tall					52
                    zpos					100
                    selectOnFocus			1
                    cursorVelocityModifier	0.7
                    rui						"ui/reticle_palette.rpak"
                    navUp					SV_Slider
                    navRight					BtnSwatch1
                    xpos					-360
                    ypos					-232
                    pin_to_sibling			Plate
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_LEFT
                }
                BtnSwatch1
                {
                    ControlName				RuiButton
                    wide					52
                    tall					52
                    zpos					100
                    selectOnFocus			1
                    cursorVelocityModifier	0.7
                    rui						"ui/reticle_palette.rpak"
                    navUp					SV_Slider
                    navLeft					BtnSwatch0
                    navRight					BtnSwatch2
                    xpos					10
                    ypos					0
                    pin_to_sibling			BtnSwatch0
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_RIGHT
                }
                BtnSwatch2
                {
                    ControlName				RuiButton
                    wide					52
                    tall					52
                    zpos					100
                    selectOnFocus			1
                    cursorVelocityModifier	0.7
                    rui						"ui/reticle_palette.rpak"
                    navUp					SV_Slider
                    navLeft					BtnSwatch1
                    navRight					BtnSwatch3
                    xpos					10
                    ypos					0
                    pin_to_sibling			BtnSwatch1
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_RIGHT
                }
                BtnSwatch3
                {
                    ControlName				RuiButton
                    wide					52
                    tall					52
                    zpos					100
                    selectOnFocus			1
                    cursorVelocityModifier	0.7
                    rui						"ui/reticle_palette.rpak"
                    navUp					SV_Slider
                    navLeft					BtnSwatch2
                    navRight					BtnSwatch4
                    xpos					10
                    ypos					0
                    pin_to_sibling			BtnSwatch2
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_RIGHT
                }
                BtnSwatch4
                {
                    ControlName				RuiButton
                    wide					52
                    tall					52
                    zpos					100
                    selectOnFocus			1
                    cursorVelocityModifier	0.7
                    rui						"ui/reticle_palette.rpak"
                    navUp					SV_Slider
                    navLeft					BtnSwatch3
                    navRight					ColorRTextEntry
                    xpos					10
                    ypos					0
                    pin_to_sibling			BtnSwatch3
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_RIGHT
                }
                ColorR
                {
                    xpos					-880
                    ypos					-245
                    ControlName				RuiPanel
                    wide					42
                    tall					27
                    visible					1
                    rui						"ui/reticle_color_textframe.rpak"
                    ruiArgs
                    {
                        name		"#MENU_RETICLE_R"
                        subtitle	""
                    }
                    pin_to_sibling			Plate
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_LEFT
                }
                ColorRTextEntry
                {
                    ControlName				TextEntry
                    zpos					100
                    wide					42
                    tall					27
                    visible					1
                    enabled					1
                    textHidden				0
                    editable				1
                    maxchars				3
                    textAlignment			center
                    ruiFont					TitleRegularFont
                    ruiFontHeight			25
                    allowRightClickMenu		0
                    allowSpecialCharacters	0
                    NumericInputOnly		1
                    charBlackList			" "
                    unicode					0
                    selectOnFocus			1
                    cursorVelocityModifier	0.7
                    navLeft					BtnSwatch4
                    navUp					SV_Slider
                    navRight				ColorGTextEntry
                    pin_to_sibling			ColorR
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_LEFT
                }
                ColorG
                {
                    ControlName				RuiPanel
                    wide					42
                    tall					27
                    visible					1
                    rui						"ui/reticle_color_textframe.rpak"
                    ruiArgs
                    {
                        name		"#MENU_RETICLE_G"
                        subtitle	""
                    }
                    xpos					2
                    pin_to_sibling			ColorR
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_RIGHT
                }
                ColorGTextEntry
                {
                    ControlName				TextEntry
                    zpos					100
                    wide					42
                    tall					27
                    visible					1
                    enabled					1
                    textHidden				0
                    editable				1
                    maxchars				3
                    textAlignment			center
                    ruiFont					TitleRegularFont
                    ruiFontHeight			25
                    allowRightClickMenu		0
                    allowSpecialCharacters	0
                    NumericInputOnly		1
                    charBlackList			" "
                    unicode					0
                    selectOnFocus			1
                    cursorVelocityModifier	0.7
                    navLeft					ColorRTextEntry
                    navUp					SV_Slider
                    navRight				ColorBTextEntry
                    pin_to_sibling			ColorG
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_LEFT
                }
                ColorB
                {
                    ControlName				RuiPanel
                    wide					42
                    tall					27
                    visible					1
                    rui						"ui/reticle_color_textframe.rpak"
                    ruiArgs
                    {
                        name		"#MENU_RETICLE_B"
                        subtitle	""
                    }
                    xpos					2
                    pin_to_sibling			ColorG
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_RIGHT
                }
                ColorBTextEntry
                {
                    ControlName				TextEntry
                    zpos					100
                    wide					42
                    tall					27
                    visible					1
                    enabled					1
                    textHidden				0
                    editable				1
                    maxchars				3
                    textAlignment			center
                    ruiFont					TitleRegularFont
                    ruiFontHeight			25
                    allowRightClickMenu		0
                    allowSpecialCharacters	0
                    NumericInputOnly		1
                    charBlackList			" "
                    unicode					0
                    selectOnFocus			1
                    cursorVelocityModifier	0.7
                    navLeft					ColorGTextEntry
                    navUp					SV_Slider
                    pin_to_sibling			ColorB
                    pin_corner_to_sibling	TOP_LEFT
                    pin_to_sibling_corner	TOP_LEFT
                }
            }

            ModWeaponsHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                xpos					0
                ypos					6
                pin_to_sibling			HeirloomRgbPanel
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }
            ModWeaponsHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			ModWeaponsHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"MOD WEAPONS"
            }

            SwitchModWeapon
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "..."	0
                }
                pin_to_sibling			ModWeaponsHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        MultiChoiceButtonAlways
            }

            ServerModsHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                xpos					0
                ypos					6
                pin_to_sibling			SwitchModWeapon
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }
            ServerModsHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			ServerModsHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"SERVER MODS"
            }

            SwitchMod0
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			ServerModsHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod1
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod0
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod2
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod1
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod3
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod2
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod4
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod3
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod5
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod4
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod6
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod5
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod7
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod6
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod8
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod7
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod9
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod8
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod10
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod9
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            SwitchMod11
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "#SETTING_OFF"	0
                    "#SETTING_ON"	1
                }
                pin_to_sibling			SwitchMod10
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            ButtonDisableAllMods
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			SwitchMod11
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

        }
    }
}
