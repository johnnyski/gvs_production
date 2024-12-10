#!/bin/csh -f

if ($#argv != 1) then
        echo "Usage: $0 volid"
    exit
endif

set tapeid = $argv[1]

# For example, set tapeid = "W950921_950922" # You need "'s

## Set these correctly.
setenv GVS_DATA_PATH /usr/local/trmm/data
setenv GTS_DATA_PATH /usr/local/trmm/data
setenv TSDISTK /usr/local/toolkit_2.5

# Let's assume the tapeid = W950921_950922, then
# you have to be in the directory where gts_1C-51_W950921_950922 and
# gts_2A-54_W950921_950922 exist.  I'll assume these two directories are
# in the current directory.
#

echo ' -v                ' > 2A-53-w.opt
echo "  -b 1.5 -f 4.6 -n 0 -p 1000 -t 303 -d 295 -k 300. -a 1.4 -m 0 -g mlb_sitelist" > 2A-53-d.opt
echo '  -v' > 2A-55.opt
aiwII_level2 $tapeid 2A-53-w 2A-53-w.opt 2A-53-d 2A-53-d.opt 2A-55 2A-55.opt >& $tapeid.log

