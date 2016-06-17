# -*- tcl -*-
# -------------------------------------------------------------------------
# critcl::cdata
# -- Core tests.
#    Used via cdata.test and cdata-trace.test
# -- Parameters
#    (1) suffix  ('' | '-trace')
#        This parameter affects test naming and directory holding the
#        expected results.
# -------------------------------------------------------------------------
# Parameter validation

global suffix
if {![info exists suffix]} {
    error "Missing parameter 'suffix'. Please define as either empty string, or '-trace'"
} elseif {($suffix ne "") && ($suffix ne "-trace")} {
    error "Bad value '$suffix' for parameter 'suffix'. Please define as either empty string, or '-trace'"
}

# -------------------------------------------------------------------------
# Setup

source [file join \
            [file dirname [file dirname [file join [pwd] [info script]]]] \
            testutilities.tcl]

testsNeedTcl     8.4
testsNeedTcltest 2

support {
    useLocal lib/util84/lassign.tcl  lassign84
    useLocal lib/util84/dict.tcl     dict84

    useLocal lib/stubs/container.tcl stubs::container
    useLocal lib/stubs/reader.tcl    stubs::reader
    useLocal lib/stubs/genframe.tcl  stubs::gen

    useLocalFile test/support.tcl
}
testing {
    useLocal lib/critcl/critcl.tcl critcl

    on-traced-on
}

# -------------------------------------------------------------------------
## cdata syntax

test critcl-cdata${suffix}-1.0 {cdata, wrong args, not enough} -setup {
} -body {
    critcl::cdata
} -returnCodes error -result {wrong # args: should be "critcl::cdata name data"}

test critcl-cdata${suffix}-1.1 {cdata, wrong args, not enough} -setup {
} -body {
    critcl::cdata N
} -returnCodes error -result {wrong # args: should be "critcl::cdata name data"}

test critcl-cdata${suffix}-1.2 {cdata, wrong args, too many} -setup {
} -body {
    critcl::cdata N D X
} -returnCodes error -result {wrong # args: should be "critcl::cdata name data"}

# -------------------------------------------------------------------------
## Go through the various knobs we can use to configure the definition and output

test critcl-cdata${suffix}-2.0 {cdata, defaults} -body {
    get critcl::cdata alpha beta
} -result [viewFile [localPath test/support/cdata${suffix}/2.0]]

test critcl-cdata${suffix}-2.1 {cdata, Tcl vs C identifiers} -body {
    get critcl::cdata alpha-x beta
} -result [viewFile [localPath test/support/cdata${suffix}/2.1]]

test critcl-cdata${suffix}-2.2 {cdata, namespaced name} -body {
    get critcl::cdata the::alpha beta
} -result [viewFile [localPath test/support/cdata${suffix}/2.2]]

# -------------------------------------------------------------------------
testsuiteCleanup

# Local variables:
# mode: tcl
# indent-tabs-mode: nil
# End:
