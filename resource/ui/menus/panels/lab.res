"resource/ui/menus/panels/lab.res"
{
	ScreenFrame
    {
		ControlName				Label
		xpos					0
		ypos					0
		wide					%100
		tall					%100
		labelText				""
		visible				    1
    }

	PanelFrame
    {
		ControlName				Label
		xpos					0
		ypos					0
		wide					%100
		tall					%100
		labelText				""
		visible				    1
        paintbackground         0

        proportionalToParent    1
    }

	TabsBackground
	{
	   ControlName           RuiPanel
	   InheritProperties     TabsBackgroundShort

	   zpos                  4
	   visible               0

	   pin_to_sibling           PanelFrame
	   pin_corner_to_sibling    TOP_LEFT
	   pin_to_sibling_corner    TOP_LEFT
	}

	TabsCommon
	{
	   ControlName           CNestedPanel
	   classname             "TabsCommonClass"
	   zpos                  5
	   xpos                  0
	   ypos                  -85
	   wide                  f0
	   tall                  47
	   visible               1
	   controlSettingsFile   "resource/ui/menus/panels/common_tabs_short.res"

	   pin_to_sibling         PanelFrame
	   pin_corner_to_sibling    TOP_LEFT
	   pin_to_sibling_corner    TOP_LEFT
	}

	LabPlayerPanel
    {
        ControlName				CNestedPanel
        classname				"TabPanelClass"
		wide					%100
        tall			        %100
        xpos                    0
        ypos                    -48
        zpos                    1
        visible                 0
        enabled                 1
        tabPosition             1
        controlSettingsFile		"resource/ui/menus/panels/lab_player.res"

        xcounterscroll			0.0
        ycounterscroll			0.0

        pin_to_sibling			PanelFrame
        pin_corner_to_sibling	TOP
        pin_to_sibling_corner	TOP
    }

	LabArmoryPanel
    {
        ControlName				CNestedPanel
        classname				"TabPanelClass"
		wide					%100
        tall			        %100
        xpos                    0
        ypos                    -48
        zpos                    1
        visible                 0
        enabled                 1
        tabPosition             1
        controlSettingsFile		"resource/ui/menus/panels/lab_armory.res"

        xcounterscroll			0.0
        ycounterscroll			0.0

        pin_to_sibling			PanelFrame
        pin_corner_to_sibling	TOP
        pin_to_sibling_corner	TOP
    }

	LabTargetsPanel
    {
        ControlName				CNestedPanel
        classname				"TabPanelClass"
		wide					%100
        tall			        %100
        xpos                    0
        ypos                    -48
        zpos                    1
        visible                 0
        enabled                 1
        tabPosition             1
        controlSettingsFile		"resource/ui/menus/panels/lab_targets.res"

        xcounterscroll			0.0
        ycounterscroll			0.0

        pin_to_sibling			PanelFrame
        pin_corner_to_sibling	TOP
        pin_to_sibling_corner	TOP
    }

	LabRecorderPanel
    {
        ControlName				CNestedPanel
        classname				"TabPanelClass"
		wide					%100
        tall			        %100
        xpos                    0
        ypos                    -48
        zpos                    1
        visible                 0
        enabled                 1
        tabPosition             1
        controlSettingsFile		"resource/ui/menus/panels/lab_recorder.res"

        xcounterscroll			0.0
        ycounterscroll			0.0

        pin_to_sibling			PanelFrame
        pin_corner_to_sibling	TOP
        pin_to_sibling_corner	TOP
    }

	LabMatchPanel
    {
        ControlName				CNestedPanel
        classname				"TabPanelClass"
		wide					%100
        tall			        %100
        xpos                    0
        ypos                    -48
        zpos                    1
        visible                 0
        enabled                 1
        tabPosition             1
        controlSettingsFile		"resource/ui/menus/panels/lab_match.res"

        xcounterscroll			0.0
        ycounterscroll			0.0

        pin_to_sibling			PanelFrame
        pin_corner_to_sibling	TOP
        pin_to_sibling_corner	TOP
    }

	LabModsPanel
    {
        ControlName				CNestedPanel
        classname				"TabPanelClass"
		wide					%100
        tall			        %100
        xpos                    0
        ypos                    -48
        zpos                    1
        visible                 0
        enabled                 1
        tabPosition             1
        controlSettingsFile		"resource/ui/menus/panels/lab_mods.res"

        xcounterscroll			0.0
        ycounterscroll			0.0

        pin_to_sibling			PanelFrame
        pin_corner_to_sibling	TOP
        pin_to_sibling_corner	TOP
    }

	DetailsPanel
    {
        ControlName				RuiPanel
        InheritProperties       SettingsDetailsPanel
        visible					1
        ypos					-177
        tall					830

        pin_to_sibling			PanelFrame
        pin_corner_to_sibling	TOP
        pin_to_sibling_corner	TOP
    }
}
