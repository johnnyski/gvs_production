#!/bin/csh -f

if ($#argv != 1) then
        echo "Usage: $0 volid"
    exit
endif

set tapeid = $argv[1]

# For example, set tapeid = "L950118_950129"; # You need "'s

## Set these correctly.
setenv GVS_DATA_PATH /usr/local/trmm/data
setenv GTS_DATA_PATH /usr/local/trmm/data
setenv TSDISTK /usr/local/toolkit_2.5

# Let's assume the tapeid = L950118_950129, then
# you have to be in the directory where gts_1C-51_L950118_950129 and
# gts_2A-54_L950118_950129 exist.  I'll assume these two directories are
# in the current directory.
#

echo ' -v -t L              ' > 2A-53-w.opt
echo " -b 1.5 -f 4.0 -n 0 -p 1000 -t 303 -d 295 -z zr_drw.out -g drw_sitelist -k 180. -a 1.45 -m 0 " > 2A-53-d.opt
echo '  -v -t L' > 2A-55.opt
aiwII_level2 $tapeid 2A-53-w 2A-53-w.opt 2A-53-d 2A-53-d.opt 2A-55 2A-55.opt >& $tapeid.log

