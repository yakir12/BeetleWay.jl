const head_xml = """<?xml version="1.0" encoding="UTF-8"?>
<!-- Generated with glade 3.20.0 -->
<interface>
<requires lib="gtk+" version="3.20"/>
<object class="GtkWindow" id="window.run.wJqRk">
<property name="can_focus">False</property>
<property name="title" translatable="yes">BeetleWay</property>
<child>
<object class="GtkBox" id="some1.wJqRk">
<property name="visible">True</property>
<property name="can_focus">False</property>
<property name="orientation">vertical</property>
<child>
<object class="GtkBox" id="some2.wJqRk">
<property name="visible">True</property>
<property name="can_focus">False</property>
<child>
<object class="GtkButton" id="done.run.wJqRk">
<property name="label" translatable="yes">Done</property>
<property name="visible">True</property>
<property name="can_focus">True</property>
<property name="receives_default">True</property>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">0</property>
</packing>
</child>
<child>
<object class="GtkButton" id="cancel.run.wJqRk">
<property name="label" translatable="yes">Cancel</property>
<property name="visible">True</property>
<property name="can_focus">True</property>
<property name="receives_default">True</property>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">1</property>
</packing>
</child>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">0</property>
</packing>
</child>
<child>
<object class="GtkBox" id="some3.wJqRk">
<property name="visible">True</property>
<property name="can_focus">False</property>
<property name="orientation">vertical</property>
<child>
<object class="GtkGrid" id="grid.run.wJqRk">
<property name="visible">True</property>
<property name="can_focus">False</property>
"""
label_xml(row::Int, text::String) = """<child>
<object class="GtkLabel" id="some4$row.$text.wJqRk">
<property name="visible">True</property>
<property name="can_focus">False</property>
<property name="label" translatable="yes">$text</property>
</object>
<packing>
<property name="left_attach">0</property>
<property name="top_attach">$row</property>
</packing>
</child>
"""
dropdown_xml(row::Int, id::String) = """<child>
<object class="GtkComboBoxText" id="$id">
<property name="visible">True</property>
<property name="can_focus">True</property>
</object>
<packing>
<property name="left_attach">1</property>
<property name="top_attach">$row</property>
</packing>
</child>
"""
textbox_xml(row::Int, id::String) = """<child>
<object class="GtkTextView" id="$id">
<property name="visible">True</property>
<property name="can_focus">True</property>
</object>
<packing>
<property name="left_attach">1</property>
<property name="top_attach">$row</property>
</packing>
</child>
"""
const tail_xml = """</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">0</property>
</packing>
</child>
<child>
<object class="GtkBox" id="some5.wJqRk">
<property name="visible">True</property>
<property name="can_focus">False</property>
<child>
<object class="GtkLabel" id="some6.wJqRk">
<property name="visible">True</property>
<property name="can_focus">False</property>
<property name="label" translatable="yes">Comment</property>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">0</property>
</packing>
</child>
<child>
<object class="GtkTextView" id="comment.run.wJqRk">
<property name="width_request">100</property>
<property name="visible">True</property>
<property name="can_focus">True</property>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">1</property>
</packing>
</child>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">1</property>
</packing>
</child>
</object>
<packing>
<property name="expand">False</property>
<property name="fill">True</property>
<property name="position">1</property>
</packing>
</child>
</object>
</child>
</object>
</interface>"""
parse2glade(x) = open(joinpath(@__DIR__, "run.glade"), "w") do o
    print(o, head_xml)
    for (i, (t,l)) in enumerate(x)
        print(o, label_xml(i - 1, l))
    end
    for (i, (t,l)) in enumerate(x)
        #TODO: maybe fix this type equation
        txt = t == SetLevels ? dropdown_xml(i - 1, l) : textbox_xml(i - 1, l)
        print(o, txt)
    end
    print(o, tail_xml)
end

