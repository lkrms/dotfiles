FILENAME == ARGV[1] {
	apps[$0] = $0
	app = $0
	$0 = tolower($0)
	gsub(/[ \t]+/, "", $0)
	if (seen[$0]++) {
		delete short_apps[$0]
	} else {
		short_apps[$0] = app
	}
	next
}

apps[$0] {
	print
	next
}

{
	app = $0
	$0 = tolower($0)
	gsub(/[ \t]+/, "", $0)
}

short_apps[$0] {
	print short_apps[$0]
	next
}

{
	print("Application not found: " app) > "/dev/stderr"
	errors++
}

END {
	if (errors) {
		print("") > "/dev/stderr"
	}
}

