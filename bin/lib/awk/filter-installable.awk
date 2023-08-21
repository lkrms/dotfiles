# Variables:
# - df_root_len
# - app_len
BEGIN {
	OFS = "\t"
}

/\t/ {
	printf("illegal tab in filename: %s", $0) > "/dev/stderr"
	exit (1)
}

{
	path = substr($0, df_root_len + 2)
	sub(/^(private\/)?by-(default|(platform|host)\/[^\/]+)\//, "", path)
	path = substr(path, app_len + 2)
	icount = iseen[inode($0)]++
	if (seen[path]++ || icount) {
		next
	}
	sort_by = 0
}

path == "target" {
	sort_by = -2
}

path == "configure" {
	sort_by = -1
}

path == "apply" {
	sort_by = 1
}

sort_by {
	print sort_by, path, $0
	next
}

sub(/^files\//, "", path) {
	print 0, path, $0
}


function inode(file, _cmd, _line, _arr)
{
	_cmd = "ls -Ldi " quote(file)
	if ((_cmd | getline _line) != 1) {
		printf("command failed: %s", _cmd) > "/dev/stderr"
		exit (1)
	}
	close(_cmd)
	split(_line, _arr, FS)
	return _arr[1]
}

function quote(str)
{
	gsub("'", "'\\''", str)
	return ("'" str "'")
}
