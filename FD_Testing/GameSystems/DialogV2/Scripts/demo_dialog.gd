class_name DemoDialog


static func build() -> Dialog:
	var kw := DialogKeyword.new()
	kw.word = "apple"
	kw.unlock_flag = "apple_eaten"   # word lights up only after this flag is set
	kw.topic_branch = "apple"        # clicking it plays the "apple" branch
	kw.topic_label = "The apple"     # topic button label


	var entry_line := DialogLine.new()
	entry_line.text = "Oh, that apple? Yeah, it's still new."
	entry_line.set_flags = ["talked_to_java"]
	entry_line.keywords = [kw]

	var entry := DialogBranch.new()
	entry.id = "entry"
	entry.lines = [entry_line]

	var apple_line := DialogLine.new()
	apple_line.text = "Wait... what happened to the [i]apple[/i]?\nSomebody got to it before you. Don't look at me."
	apple_line.set_flags = ["asked_about_apple"]

	var apple := DialogBranch.new()
	apple.id = "apple"
	apple.lines = [apple_line]


	var d := Dialog.new()
	d.branches = [entry, apple]
	return d
