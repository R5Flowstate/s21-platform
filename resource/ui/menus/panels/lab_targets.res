"resource/ui/menus/panels/lab_targets.res"
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
			tall                    1560
			visible                 1
            tabPosition             1

            StraferHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                xpos					0
                ypos					6
            }

            StraferHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			StraferHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"#LAB_TARGETS_HDR_STRAFING"
            }

            SwitchStraferBody
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "Dummy"	dummy
                    "Legend"	legend
                }
                childGroupAlways        ChoiceButtonAlways
                navUp                   SwitchStraferBody
                navDown                 SwitchStraferClass
                pin_to_sibling			StraferHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchStraferClass
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "Same as me"	-1
                }
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   SwitchStraferBody
                navDown                 SwitchStraferLegend
                pin_to_sibling			SwitchStraferBody
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchStraferLegend
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "Same as me"	same
                }
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   SwitchStraferClass
                navDown                 ButtonStrafer
                pin_to_sibling			SwitchStraferClass
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonStrafer
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                navUp                   SwitchStraferLegend
                navDown                 ButtonStraferFast
                pin_to_sibling			SwitchStraferLegend
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonStraferFast
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                navUp                   ButtonStrafer
                navDown                 SwitchDummyArmor
                pin_to_sibling			ButtonStrafer
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SettingsHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonStraferFast
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SettingsHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			SettingsHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"#LAB_TARGETS_HDR_SETTINGS"
            }

            SwitchDummyArmor
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "White"	1
                    "Blue"	2
                    "Purple"	3
                    "Red"	4
                    "Random"	10
                }
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   ButtonStraferFast
                navDown                 SldStrafeSpeed
                pin_to_sibling			SettingsHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SldStrafeSpeed
            {
                ControlName				SliderControl
                InheritProperties		SliderControl
                className               "SettingScrollSizer"
                minValue				0.5
                maxValue				2.0
                stepSize				0.1
                showLabel               3
                navUp                   SwitchDummyArmor
                navDown                 SwitchBotHealth
                pin_to_sibling			SwitchDummyArmor
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchBotHealth
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   SldStrafeSpeed
                navDown                 SwitchBotFire
                pin_to_sibling			SldStrafeSpeed
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchBotFire
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   SwitchBotHealth
                navDown                 SldBotAim
                pin_to_sibling			SwitchBotHealth
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SldBotAim
            {
                ControlName				SliderControl
                InheritProperties		SliderControl
                className               "SettingScrollSizer"
                minValue				0.0
                maxValue				1.0
                stepSize				0.05
                showLabel               3
                navUp                   SwitchBotFire
                navDown                 SwitchStrafeTimeMin
                pin_to_sibling			SwitchBotFire
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchStrafeTimeMin
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   SldBotAim
                navDown                 SwitchStrafeTimeMax
                pin_to_sibling			SldBotAim
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchStrafeTimeMax
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   SwitchStrafeTimeMin
                navDown                 SwitchFixedSpawn
                pin_to_sibling			SwitchStrafeTimeMin
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchFixedSpawn
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   SwitchStrafeTimeMax
                navDown                 ButtonSetSpawn
                pin_to_sibling			SwitchStrafeTimeMax
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonSetSpawn
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                navUp                   SwitchFixedSpawn
                navDown                 SwitchAimMode
                pin_to_sibling			SwitchFixedSpawn
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ChallengeHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonSetSpawn
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ChallengeHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			ChallengeHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"#LAB_TARGETS_HDR_CHALLENGE"
            }

            SwitchAimMode
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "Target Switch"	0
                    "Popcorn"	1
                    "Floating Target"	2
                    "Smoothbot"	3
                }
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   ButtonSetSpawn
                navDown                 SwitchDuration
                pin_to_sibling			ChallengeHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchDuration
            {
                ControlName				RuiButton
                InheritProperties		SwitchButton
                className               "SettingScrollSizer"
                style					DialogListButton
                list
                {
                    "30s"	30
                    "60s"	60
                    "90s"	90
                    "120s"	120
                    "Unlimited"	999
                }
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   SwitchAimMode
                navDown                 ButtonChallengeStart
                pin_to_sibling			SwitchAimMode
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonChallengeStart
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                navUp                   SwitchDuration
                navDown                 ButtonChallengeStop
                pin_to_sibling			SwitchDuration
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonChallengeStop
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                navUp                   ButtonChallengeStart
                navDown                 SwitchReloadKill
                pin_to_sibling			ButtonChallengeStart
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ReloadHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonChallengeStop
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ReloadHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			ReloadHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"#LAB_TARGETS_HDR_RELOAD"
            }

            SwitchReloadKill
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   ButtonChallengeStop
                navDown                 SwitchReloadHit
                pin_to_sibling			ReloadHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchReloadHit
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   SwitchReloadKill
                navDown                 SwitchReloadShot
                pin_to_sibling			SwitchReloadKill
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchReloadShot
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   SwitchReloadHit
                navDown                 SwitchDynStats
                pin_to_sibling			SwitchReloadHit
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            HudHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                pin_to_sibling			SwitchReloadShot
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            HudHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			HudHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"#LAB_TARGETS_HDR_HUD"
            }

            SwitchDynStats
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   SwitchReloadShot
                navDown                 SwitchReconBars
                pin_to_sibling			HudHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchReconBars
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   SwitchDynStats
                navDown                 SwitchHighlight
                pin_to_sibling			SwitchDynStats
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            SwitchHighlight
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
                childGroupAlways        ChoiceButtonAlways
                navUp                   SwitchReconBars
                navDown                 ButtonQuitAimTrainer
                pin_to_sibling			SwitchReconBars
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonQuitAimTrainer
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                navUp                   SwitchHighlight
                navDown                 ButtonQuitAimTrainer
                pin_to_sibling			SwitchHighlight
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }
        }
    }
}
