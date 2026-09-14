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
			tall                    1500
			visible                 1
            tabPosition             1

            SpawnHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                xpos					0
                ypos					6
            }
            SpawnHeaderText
            {
                ControlName				Label
                InheritProperties		SubheaderText
                pin_to_sibling			SpawnHeader
                pin_corner_to_sibling	LEFT
                pin_to_sibling_corner	LEFT
                use_pin_locale_direction    1
                labelText				"SPAWN AT CROSSHAIR"
            }

            ButtonDummy
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			SpawnHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonSandbag
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonDummy
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonStrafer
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonSandbag
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonStraferFast
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonStrafer
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonFakePlayer
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonStraferFast
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonFakeEnemy
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonFakePlayer
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
                navUp                   ButtonFakeEnemy
                navDown                 SwitchBotHealth
                pin_to_sibling			ButtonFakeEnemy
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
                navUp                   SldStrafeSpeed
                navDown                 SwitchAimMode
                pin_to_sibling			SldStrafeSpeed
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            ChallengeHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                xpos					0
                ypos					6
                pin_to_sibling			SwitchBotHealth
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
                labelText				"AIM CHALLENGE"
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
                pin_to_sibling			ChallengeHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        MultiChoiceButtonAlways
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
                pin_to_sibling			SwitchAimMode
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        MultiChoiceButtonAlways
            }

            ButtonChallengeStart
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			SwitchDuration
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ButtonChallengeStop
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			ButtonChallengeStart
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

            ReloadHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                xpos					0
                ypos					6
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
                labelText				"AUTO RELOAD"
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
                pin_to_sibling			ReloadHeader
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
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
                pin_to_sibling			SwitchReloadKill
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
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
                pin_to_sibling			SwitchReloadHit
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
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
                pin_to_sibling			SwitchReloadShot
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
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
                pin_to_sibling			SwitchDynStats
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
                childGroupAlways        ChoiceButtonAlways
            }

            ButtonQuitAimTrainer
            {
                ControlName				RuiButton
                InheritProperties		SettingBasicButton
                className               "SettingScrollSizer"
                pin_to_sibling			SwitchReconBars
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }

        }
    }
}
