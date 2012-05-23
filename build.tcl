#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}
set me [file normalize [info script]]
proc main {} {
    global argv
    if {![llength $argv]} { set argv help}
    if {[catch {
	eval _$argv
    }]} usage
    exit 0
}
proc usage {{status 1}} {
    global errorInfo
    if {[info exists errorInfo] && ($errorInfo ne {}) &&
	![string match {invalid command name "_*"*} $errorInfo]
    } {
	puts stderr $::errorInfo
	exit
    }

    global argv0
    set prefix "Usage: "
    foreach c [lsort -dict [info commands _*]] {
	set c [string range $c 1 end]
	if {[catch {
	    H${c}
	} res]} {
	    puts stderr "$prefix$argv0 $c args...\n"
	} else {
	    puts stderr "$prefix$argv0 $c $res\n"
	}
	set prefix "       "
    }
    exit $status
}
proc +x {path} {
    catch { file attributes $path -permissions u+x }
    return
}
proc grep {file pattern} {
    set lines [split [read [set chan [open $file r]]] \n]
    close $chan
    return [lsearch -all -inline -glob $lines $pattern]
}
proc version {file} {
    set provisions [grep $file {*package provide*}]
    #puts /$provisions/
    return [lindex $provisions 0 3]
}
proc Hhelp {} { return "\n\tPrint this help" }
proc _help {} {
    usage 0
    return
}
proc Hrecipes {} { return "\n\tList all brew commands, without details." }
proc _recipes {} {
    set r {}
    foreach c [info commands _*] {
	lappend r [string range $c 1 end]
    }
    puts [lsort -dict $r]
    return
}
proc Hdoc {} { return "\n\t(Re)Generate the embedded documentation." }
proc _doc {} {
    cd [file dirname $::me]/doc

    puts "Removing old documentation..."
    file delete -force ../embedded/man
    file delete -force ../embedded/www

    file mkdir ../embedded/man
    file mkdir ../embedded/www

    puts "Generating man pages..."
    exec 2>@ stderr >@ stdout dtplite -ext n -o ../embedded/man nroff .
    puts "Generating html..."
    exec 2>@ stderr >@ stdout dtplite        -o ../embedded/www html .

    cd  ../embedded/man
    file delete -force .idxdoc .tocdoc
    cd  ../www
    file delete -force .idxdoc .tocdoc

    return
}
proc Hfigures {} { return "\n\t(Re)Generate the figures and diagrams for the documentation." }
proc _figures {} {
    cd [file dirname $::me]/doc/include

    puts "Generating (tklib) diagrams..."
    eval [linsert [glob *.dia] 0 exec 2>@ stderr >@ stdout dia convert -t -o . png]

    return
}
proc Hrelease {} { return "\n\tGenerate a release from the current commit.\n\tAssumed to be properly tagged.\n\tLeaves checkout in the gh-pages branch, ready for commit+push" }
proc _release {} {

    # # ## ### ##### ######## #############
    # Get scratchpad to assemble the release in.
    package require fileutil

    set tmpraw [fileutil::tempfile critcl-release]
    set tmpdir $tmpraw.[pid]
    file delete -force $tmpdir
    file mkdir $tmpdir
    file delete -force $tmpraw

    puts "Assembly in: $tmpdir"

    # # ## ### ##### ######## #############
    # Get version and hash of the commit to be released.
    set commit  [exec git log -1 --pretty=format:%H]
    set version [exec git describe]

    puts "Commit:      $commit"
    puts "Version:     $version"

    # # ## ### ##### ######## #############
    puts {Collecting the documentation ...}
    file copy -force embedded/www $tmpdir/doc

    # # ## ### ##### ######## #############
    puts {Generate starkit...}
    _starkit $tmpdir/critcl3.kit

    # # ## ### ##### ######## #############
    puts {Collecting starpack prefix...}
    # which we use the existing starpack for, from the gh-pages branch

    exec 2>@ stderr >@ stdout git checkout gh-pages
    file copy download/critcl3.exe $tmpdir/prefix.exe
    exec 2>@ stderr >@ stdout git checkout $commit

    # # ## ### ##### ######## #############
    puts {Generate starpack...}
    _starpack $tmpdir/prefix.exe $tmpdir/critcl3.exe
    # TODO: vacuum the thing. fix permissions if so.

    # # ## ### ##### ######## #############
    puts {Assembly now, switching to gh-pages...}
    exec 2>@ stderr >@ stdout git checkout gh-pages

    file delete -force doc
    file copy -force $tmpdir/doc doc
    file copy -force $tmpdir/critcl3.kit download/critcl3.kit
    file copy -force $tmpdir/critcl3.exe download/critcl3.exe

    set index [fileutil::cat index.html]
    regsub \
	{Download \[commit .*\] \(v[^)]*\)}      $index \
	"Download \[commit $commit\] (v$version)" index
    fileutil::writeFile index.html $index

    # # ## ### ##### ######## #############
    puts ""
    puts "We are in branch gh-pages now, coming from $commit"
    puts ""

    # # ## ### ##### ######## #############
    return
}
proc Hinstall {} { return "?destination?\n\tInstall all packages, and application.\n\tdestination = path of package directory, default \[info library\]." }
proc _install {{dst {}}} {
    set version  [version [file dirname $::me]/lib/critcl/critcl.tcl]

    if {[llength [info level 0]] < 2} {
	set dstl [info library]
	set dsta [file dirname [file normalize [info nameofexecutable]]]
    } else {
	set dstl $dst
	set dsta [file dirname $dst]/bin
    }

    # Create directories, might not exist.
    file mkdir $dstl
    file mkdir $dsta

    # Package: critcl
    file copy   -force [file dirname $::me]/lib/critcl     $dstl/critcl-new
    file delete -force $dstl/critcl$version
    file rename        $dstl/critcl-new     $dstl/critcl$version

    puts "Installed package:     $dstl/critcl$version"

    # Package: critcl::util
    set uversion [version [file dirname $::me]/lib/critcl-util/util.tcl]
    file copy   -force [file dirname $::me]/lib/critcl-util     $dstl/critcl-util-new
    file delete -force $dstl/critcl-util$uversion
    file rename        $dstl/critcl-util-new     $dstl/critcl-util$uversion

    puts "Installed package:     $dstl/critcl-util$uversion"

    # Package: critcl::app
    file copy   -force [file dirname $::me]/lib/app-critcl $dstl/critcl-app-new
    file delete -force $dstl/critcl-app$version
    file rename        $dstl/critcl-app-new $dstl/critcl-app$version

    puts "Installed package:     $dstl/critcl-app$version"

    # Package: dict84, lassign84, both under util84
    file copy   -force [file dirname $::me]/lib/util84 $dstl/util84-new
    file delete -force $dstl/util84
    file rename        $dstl/util84-new $dstl/util84

    puts "Installed package:     $dstl/util84 (dict84, lassign84 bundle)"

    # Package: stubs::*, all under stubs
    file copy   -force [file dirname $::me]/lib/stubs $dstl/stubs-new
    file delete -force $dstl/stubs
    file rename        $dstl/stubs-new $dstl/stubs

    puts "Installed package:     $dstl/stubs (stubs::* bundle)"

    set    c [open $dsta/critcl w]
    puts  $c "#!/bin/sh\n# -*- tcl -*- \\\nexec tclsh \"\$0\" \$\{1+\"\$@\"\}\npackage require critcl::app\ncritcl::app::main \$argv"
    close $c
    +x $dsta/critcl

    puts "Installed application: $dsta/critcl"
    return
}
proc Hstarkit {} { return "?destination? ?interpreter?\n\tGenerate a starkit\n\tdestination = path of result file, default 'critcl.kit'\n\tinterpreter = (path) name of tcl shell to use for execution, default 'tclkit'" }
proc _starkit {{dst critcl.kit} {interp tclkit}} {
    package require vfs::mk4

    set c [open $dst w]
    fconfigure $c -translation binary -encoding binary
    puts -nonewline $c "#!/bin/sh\n# -*- tcl -*- \\\nexec $interp \"\$0\" \$\{1+\"\$@\"\}\npackage require starkit\nstarkit::header mk4 -readonly\n\032################################################################################################################################################################"
    close $c

    vfs::mk4::Mount $dst /KIT
    file copy -force lib /KIT
    file copy -force main.tcl /KIT
    vfs::unmount /KIT
    +x $dst

    puts "Created starkit: $dst"
    return
}
proc Hstarpack {} { return "prefix ?destination?\n\tGenerate a fully-selfcontained executable, i.e. a starpack\n\tprefix      = path of tclkit/basekit runtime to use\n\tdestination = path of result file, default 'critcl'" }
proc _starpack {prefix {dst critcl}} {
    package require vfs::mk4

    file copy -force $prefix $dst

    vfs::mk4::Mount $dst /KIT
    file mkdir /KIT/lib

    foreach d [glob -directory lib *] {
	file delete -force  /KIT/lib/[file tail $d]
	file copy -force $d /KIT/lib
    }

    file copy -force main.tcl /KIT
    vfs::unmount /KIT
    +x $dst

    puts "Created starpack: $dst"
    return
}
proc Hexamples {} { return "?args...?\n\tWithout arguments, list the examples.\n\tOtherwise run the recipe with its arguments on the examples." }
proc _examples {args} {
    global me
    set selfdir [file dirname $me]
    set self    [file tail    $me]

    # List examples, or run the build code on the examples, passing any arguments.

    set examples [glob -directory $selfdir/examples */$self]

    puts ""
    if {![llength $args]} {
	foreach b $examples {
	    puts "* [file dirname $b]"
	}
    } else {
	foreach b $examples {
	    puts "$b _______________________________________________"
	    eval [linsert $args 0 exec 2>@ stderr >@ stdout [info nameofexecutable] $b]
	    puts ""
	    puts ""
	}
    }
    return
}
main