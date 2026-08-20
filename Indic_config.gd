class_name IndicatorConfig
extends Resource
## One rule for the area indicator: "anything in THIS group shows THIS button".
##
## Add one config per group you care about. The indicator checks them in order
## and uses the first one whose group the nearby thing belongs to.

## Group the nearby node must be in, e.g. &"Item" or &"Door".
@export var target_group: StringName = &""

## Button shown when playing on keyboard/mouse.
@export var icon: Texture2D

## Button shown when playing on a controller. Leave empty to always use
## `icon` — the indicator falls back to it rather than showing nothing.
@export var icon_gamepad: Texture2D
