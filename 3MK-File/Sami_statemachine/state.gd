class_name state extends Node

static var player: Player

## What happens when the player enters this State?
func Enter() -> void:
	pass

## What happens when the player exits this State?
func Exit() -> void:
	pass

## What happens during the _process update in this State?
func Process( _delta : float ) -> state:
	return null

## What happens during the _physics_process update in this State?
func Physics( _delta : float ) -> state:
	return null

## What happens with input events in this State?
func HandleInput( _event: InputEvent ) -> state:
	return null
