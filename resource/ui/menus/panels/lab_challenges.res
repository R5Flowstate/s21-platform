"resource/ui/menus/panels/lab_challenges.res"
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
			tall                    830
			visible                 1
            tabPosition             1

            ChallengeHeader
            {
                ControlName				ImagePanel
                InheritProperties		SubheaderBackgroundWide
                className               "SettingScrollSizer"
                xpos					0
                ypos					6
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
                childGroupAlways        MultiChoiceButtonAlways
                navUp                   SwitchAimMode
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
                navDown                 ButtonChallengeStop
                pin_to_sibling			ButtonChallengeStart
                pin_corner_to_sibling	TOP_LEFT
                pin_to_sibling_corner	BOTTOM_LEFT
            }
        }
    }
}
