#! /usr/bin/perl
#-*-Perl-*-
#
# Common definitions and routines for perl scripts in gvs_production.
#
#
unshift (@INC, ".", "/usr/local/trmm/GVBOX/bin");
do 'gv_utilities.pl';

$PROG_VERSION = "gvs_production-v3.21";
$save_curr_dir = `pwd`;
chop $save_curr_dir;
$save_curr_dir = $save_curr_dir."/";
$first_time_exit_handler = 1;

$SIG{'INT'} = 'doexit_handler';
$SIG{'KILL'} = 'doexit_handler';
$SIG{'STOP'} = 'doexit_handler';
$SIG{'SEGV'} = 'doexit_handler';
$SIG{'ILL'} = 'doexit_handler';
$SIG{'FPE'} = 'doexit_handler';

# Prefix names for products
$L1_1C51 = "1C51";
$L1_1B51 = "1B51";

# lock file
$LOCK_UN = 8;
$LOCK_EX = 2;

$FAILED_STR = "failed";
$SUCCESSFUL_STR = "successful";
$WARNING_STR = "warning";
$RUNNING_STR = "running";
$FINISHED_STR = "finished";
$ABORTED_STR = "aborted";
# status string used when calling 'send_status'. index starts at 0
@stat_array = ($FAILED_STR, $SUCCESSFUL_STR, $WARNING_STR,  $RUNNING_STR, $FINISHED_STR, $ABORTED_STR);

$FAILED     = 1;
$SUCCESSFUL = 2;
$WARNING    = 4;
$RUNNING    = 8;
$FINISHED   = 16;
$ABORTED    = 32;

$default_stat = $SUCCESSFUL;
%products_status = (
#  PRODUCT      STATUS  -- Status based on the whole tape (data set).
   'level_1',  $default_stat,
   '2A-52i',   $default_stat,
   '2A-53-w',  $default_stat,
   '2A-53-d',  $default_stat,
   '2A-53-c',  $default_stat,
   '2A-53-v4', $default_stat,
   '2A-54',    $default_stat,
   '2A-55',    $default_stat,
   '3A-53',    $default_stat,
   '3A-54',    $default_stat,
   '3A-55',    $default_stat
						);

# Nothing is selected, by default.
foreach $p (keys(%products_status)) {
	$product_list{$p} = 0;
}
$HDF_type = "HDF";
$uf_type = "UF";
$ASCII_type = "ASCII";

# defining some global variables
@path = split(/\//, $0);
$this_prog = $path[$#path];


# Define exit codes;
$SUCCESS_CODE = 0;
$OUT_OF_SPACE_CODE = 2;
$SEVERE_ERROR_CODE = -1;
$INTER_CODE = -2;
$MINOR_ERROR_CODE = -3;



# Define exit code strings
%exit_code_names = (
					# Exit_code  Exit_code_name
					$SUCCESS_CODE,      'SUCCESS',
                    $OUT_OF_SPACE_CODE, 'OUT_OF_SPACE',
					$SEVERE_ERROR_CODE, 'SEVERE_ERROR',
					$INTER_CODE,        'ABORTED',
					$MINOR_ERROR_CODE,  'MINOR_ERROR'
				);



sub interrupted {
	local($stat) = @_;
	return 1 if ($stat == $INTER_CODE || $stat ==254);
	return 0;
}


sub is_severe_error {
	local($stat) = @_;
	return 1 if ($stat == $SEVERE_ERROR_CODE || $stat ==255);
	return 0;
}

sub out_of_space {
	local($stat) = @_;
	return 1 if ($stat == $OUT_OF_SPACE_CODE);
	return 0;
}

sub is_minor_error {
	local($stat) = @_;
	return 1 if ($stat == $MINOR_ERROR_CODE || $stat ==253);
	return 0;
}

sub change2absolute_dir {
	local($dir) = @_;

	return $dir if ($dir eq "");

	# Remove leading blank for dir
	$dir =~ s/^\s+//;
	local($curr_dir) = `pwd`;
	chop $curr_dir; # Remove \r
	$curr_dir = $curr_dir."/";
	# Change '.' or './[dir_name]' to $curr_dir/[dir_name]
	$dir =~ s/(^\.$)|(^\.\/)/$curr_dir/;
	# Change dir_name to $curr_dir/dir_name
    $dir = $curr_dir.$dir if ($dir =~ /^[^\/]/);
	# Append "/" at the end if it's not there yet.
    $dir = $dir."/" if $dir =~ /[^\/]$/;	
	return $dir;
}

sub change2absolute_dir2 {
	local($pref_dir, $dir) = @_;

	return $dir if ($dir eq "");
	# Remove leading blank for dir
	$dir =~ s/^\s+//;
	# Remove trailing blank for pref dir
	$pref_dir =~ s/\s+$//;
	# Change '.' or './[dir_name]' to $pref_dir/[dir_name]
	$dir =~ s/(^\.$)|(^\.\/)/$pref_dir/;
	# Change dir_name to $pref_dir/dir_name
    $dir = $pref_dir.$dir if ($dir =~ /^[^\/]/);
	# Append "/" at the end if it's not there yet.
    $dir = $dir."/" if $dir =~ /[^\/]$/;	
	return $dir;
}

sub  read_files_from_dir_to_list {
	local($dir,$file_ext, *prod_files_list) = @_;
	# Read products ' filenames ending with file_ext[.gz|.Z] from 
    # dir to prod_files_list.

	return if $dir eq "";
	opendir(THISDIR, $dir) ||
		(print STDERR "$this_prog: Failed to open dir <$dir>. \n" && 
		 return);
	local(@tmp_list) = ();
	# Files ends with file_ext
	@prod_files_list = grep(/[0-9].+\.$file_ext$/, readdir(THISDIR));	

	# Files ends with file_ext and .gz
	rewinddir(THISDIR);
	@tmp_list = grep(/[0-9].+\.$file_ext\.gz$/, readdir(THISDIR));	
	do combine_lists(*prod_files_list, *tmp_list);

	# Files ends with file_ext and .Z
	rewinddir(THISDIR);
	@tmp_list = grep(/[0-9].+\.$file_ext\.Z$/, readdir(THISDIR));	
	do combine_lists(*prod_files_list, *tmp_list);

	closedir(THISDIR);
} 

sub combine_lists {
	local(*list1, *list2) = @_;

	# Add elems from list 2 to list1 if they are not in list1 yet.
	# list1 will be changed in the calling routine.
	#
	# Max num of elems in list 1
	local($j) = $#list1 + 1;
	$j = 0 if ($j < 0);
	local($i);

	for ($i=0; $i <=$#list2; $i++) {
		next if (&elem_in_list(*list1, $list2[$i]));
		$list1[$j+$i] = $list2[$i];
	}

}

sub get_dir_name {
	local($product, $tape_id) = @_;
	
	return "gvs_" . $product . "_" . $tape_id."/";
}

sub restore_tty {
    #Restore STDERR and STDOUT.  This is required since both stderr and stdout
    # might have been redirected by the calling program
	close(1);
	close(2);
	open(STDOUT, ">/dev/tty");
	open(STDERR, ">/dev/tty");
}

sub compress_product {
	local($prod_dir, $is_final, $max_infiles_per_hour, $top_tmp_dir,
		  $prod_prefix) = @_;
	# Compress level 1 HDF file(s) when they are (guessed to be) fully 
    # granulized 
	# or when $is_final = 1.		
	#
	# $processed_infile_count_for_granule and $max_infiles_per_hour are used 
    # to determine if an HDF file is completely granulized.
	# The processed_infile_count_for_granule for an HDF file is incremented 
    # by one and written to a temporary file each time this routine is being
	# called. $processed_infile_count_for_granule will be checked against 
    # $max_infiles_per_hour.
    # If $processed_infile_count_for_granule <= $max_infiles_per_hour,
	# then we assume that the file is fully granulized -- compress
	# it.   This method assumes that raw input files are feeded into the 
	# program in the right order.
	#

	# Only consider the uncompressed HDF files
	# Use open ls here since we assume that there aren't many HDF files in
	# $prod_dir.

	open(HDF_FILES, "/bin/ls -1 $prod_dir/$prod_prefix*.HDF |") ||
		(print STDERR "Can't open $prod_dir for compression: $!\n" && return);
	local(@hdf_file_list) = <HDF_FILES>;
	close(HDF_FILES);
	while (@hdf_file_list) {
		local($hdf_file) = shift @hdf_file_list;
		chop $hdf_file if $hdf_file =~ /(\n)|(\r)/;

		# If this file is being compressed, then go to the next file.
		open(LS, "/bin/ls $hdf_file*[zZ]");
		local(@this_compressed_file) = <LS>;
		close(LS);
		next if ($#this_compressed_file >= 0);
		local($processed_infile_count_for_granule) = 1;
		# Construct a tmp filename. 
		# Remove path from filename -- use as array key.
		local(@path) = split(/\//, $hdf_file);
		local($hdf_tmp_file) = "$top_tmp_dir$path[$#path]"."vn";

		if (!(-e $hdf_tmp_file)) { # First time
			if ($is_final == 1) {
				print STDERR "$this_prog: Compressing $hdf_file...\n";
				do do_system_call("gzip -f $hdf_file", "");
				next;
			}
			do do_system_call("echo \"$processed_infile_count_for_granule\" >$hdf_tmp_file", "");
			next;
		}
			
		open(VOSNUM, "/bin/cat $hdf_tmp_file|") || 
			(do do_system_call("echo \"$processed_infile_count_for_granule\" >$hdf_tmp_file", "") &&
			 next);
		$processed_infile_count_for_granule = <VOSNUM>;
		close(VOSNUM);
		chop $processed_infile_count_for_granule if ($processed_infile_count_for_granule =~ /(\r)|(\n)/);
		$processed_infile_count_for_granule++;
		# Eithr is final or file's processed_infile_count_for_granule exceed the max_vos_#, compress it
		if ($is_final == 1 ||
			$processed_infile_count_for_granule >= $max_infiles_per_hour) {
			unlink $hdf_tmp_file;
			print STDERR "$this_prog: Compressing $hdf_file...\n";
			do do_system_call("gzip -f $hdf_file", "");
			next;
		}
		else {

			do do_system_call("echo \"$processed_infile_count_for_granule\" >$hdf_tmp_file", "");
		}

	}
} #compress_product


sub extract_level1_dirs_from_options {
	local(*dir_1C, *dir_1B, *dir_1C_UF, *gif_image_dir, 
		  *no_1C, *no_1B, @options) = @_;
	local($options_str) = "@options";

	local($tmp_gif_image_dir)  = $options_str =~ /.*\-g\s+(\S+).*$/;
	local($tmp_dir_1C_UF)  = $options_str =~ /.*\-u\s+(\S+).*$/;
	local($tmp_dir_1C)  = $options_str =~ /.*\-c\s+(\S+).*$/;
	local($tmp_dir_1B)  = $options_str =~ /.*\-b\s+(\S+).*$/;
	$dir_1C = $tmp_dir_1C if ($tmp_dir_1C ne "");
	$dir_1B = $tmp_dir_1B if ($tmp_dir_1B ne "");
	$dir_1C_UF = $tmp_dir_1C_UF if ($tmp_dir_1C_UF ne "");
	$gif_image_dir = $tmp_gif_image_dir if ($tmp_gif_image_dir ne "");

	if ($options_str =~ /\-C/) {
		# Produce no 1C -- was specified
		$dir_1C = "";
		$no_1C = 1;
	} 
	if ($options_str =~ /\-B/) {
	    # Produce no 1B --was specified
		$dir_1B = "";
		$no_1B = 1;
	}
}

sub get_site_name_from_1C51_hdf_file {
	local($hdf_file) = @_;
	# Get site name from the 1C-51 granule hdf file.
	return "unknown" if $hdf_file eq "";
	open(SITE, "get_radar_name_from_file HDF $hdf_file|") || 
		return "unknown";
	return <SITE>;
}

######################################################################
#                                                                    #
#                  get_info_from_granule_product_filename            #
#                                                                    #
######################################################################
sub get_info_from_granule_product_filename {
	local($fname, *mon, *day, *yr, *site) = @_;
	# fname: [pathname]4-char.yymmdd.granule#.site.ver#.HDF[.gz|.Z]
	# Return yr in 4-digit.
	return if ($fname eq "");
	($yr, $mon, $day, $site) = $fname =~ /.*\w\w\w\w\.(\d\d)(\d\d)(\d\d)\.\d+\.(\w+).+HDF.*/;
	#Change 2 digit year to 4 digit year */

	if ($yr < 100) {
		if ($yr > 60) {
			$yr += 1900;
		}
		else {
			$yr += 2000;
		}
	}
}


sub uncompress_file {
	# Uncompress file. Leave the original file unmodified.
	# return 1 for successful; exit -2 if interrupt occurred; -1, otherwise.
	local($fname, $new_fname) = @_;
	local($cmd) = "gunzip -fc $fname >$new_fname";
	print STDERR "Uncompressing $fname to $new_fname...\n";
	system($cmd);
	local($status) = $? >> 8;
	local($signal) = $? & 255;
	return -1 if ($signal != 0);
	exit ($INTER_CODE) if (&interrupted($status));
	return -1 if (&is_severe_error($status));
	return 1;
}


sub uncompress_file_to_current_dir {
	# Uncompress file to a current dir. Set new_fname to the uncompressed
    # fname without any '.gz' or '.Z' and pathname. 
    # It will append ".tmp" to fname if fname has no '.gz' or '.Z' and is
    # in the current dir.
    # Leave the original file unmodified. 

    # Return 1 for successful; -1, otherwise.
	local($fname, *new_fname) = @_;
	
	return -1 if ($fname eq "" || !(-e $fname));
	local(@fname_path) = split(/\//, $fname);
	$new_fname = $fname_path[$#fname_path];
	$new_fname =~ s/(\.gz$)|(\.Z$)//;     # Remove .gz or .Z extension
	if ($new_fname eq $fname) {
		$new_fname = $new_fname."tmp";
	}
	local($curr_dir) = `pwd`;
	chop $curr_dir;
	$new_fname = $curr_dir."/".$new_fname;						 
    return (&uncompress_file($fname, $new_fname));

}


sub get_filesize {
	local($fname) = @_;
	# Get file size for the specified file in bytes.

	open(LS, "/bin/ls -l $fname|") || return 0;
	local(@ls_line) = <LS>;
	# Format of ls -l on hp, linux, sgi is:
    #  -rw-r--r--   1 nguyen   users    10  Oct  3 09:33 file1 
    #  Note: THe time field may be the year field instead.
  
	close(LS);
	local(@fields) = split(/[ \t]+/, $ls_line[0]);
	if ($#fields == 8) {
		return ($fields[4]);
	}
	return 0;
}

sub ignore_catched_signals {

	$SIG{'INT'} = 'ignore';
	$SIG{'KILL'} = 'ignore';
	$SIG{'STOP'} = 'ignore';
	$SIG{'SEGV'} = 'ignore';
	$SIG{'ILL'} = 'ignore';
	$SIG{'FPE'} = 'ignore';
}



sub create_dir {
	local($dir, $check_for_removal, $not_remove) = @_;
	# Create dir,
	# In case dir exists, 
	#   if $not_remove = 1, then donot remove anything and return
	#   if $check_for_removal = 1, then check remove_old_products flag
	#   before remove the dir; else remove dir's contents.
    #   Exit with $SEVERE_ERROR_CODE if $check_for_removal = 1 and 
    #   $remove_old_products = 0.

	#

	return if ($dir eq "");
	if (! -d $dir) {
		do do_system_call("mkdir -p  $dir", "");
		do do_system_call("chmod -R g+w $dir", "");
	}
	else {
		return if ($not_remove == 1);

		if ($check_for_removal == 1) {
			# Remove everything from this dir.
			if ($remove_old_products == 1) {
				print STDERR "$this_prog: Warning: Removing <$dir*>...\n";
				do do_system_call("rm -fr $dir*", "");
			}
			else {
				# Error, old products exist
				print STDERR "$this_prog:ERROR: Directory <$dir> exists. Please move it to somewhere else or rename it.\n";
				do do_exit($SEVERE_ERROR_CODE);
			}
		}
		else {
			# Remove everything from this dir.
				print STDERR "$this_prog: Warning: Removing <$dir*>...\n";
			do do_system_call("rm -fr $dir*", "");
		}
	}
}


sub do_exit {
	local($code) = @_;
	# Use global variables: $tape_id, $device, @save_prog_cmd, $yes_send_mail
	if ($#save_prog_cmd >= 0 && $tape_id ne "" && $device ne "") {
		# Only send mail if running production.
		local($msg) = "Finished executing <$this_prog @save_prog_cmd>\nExit code: $exit_code_names{$code}.";
		if ($yes_send_mail) {

		    local($mail_prog) = "";
		    # check if running on an SGI
		    if (`uname` =~ "IRIX") {
			$mail_prog = "mailx";
		    }
		    # else assume we are running on Linux
		    else {
			$mail_prog = "mail";
		    }			
		    
		    local($cmd) = "echo \" $msg\"|$mail_prog -s \"Status for $this_prog for '$tape_id' on '$device'\" $ENV{'USER'}";
		    
		    system($cmd);
		}
	}
	exit($code);
} #do_exit

sub gv_product_filenames_sort_compare_func {
	local(@a_fields) = split(/\./, $a);
	local(@b_fields) = split(/\./, $b);

	# a,b entries' format:
    # 2A5[3|5].yymmdd.granule#.site.ver#.HDF[.gz|.Z]
	# Compare product
	return 1 if ($a_fields[0] > $b_fields[0]);
	return -1 if ($a_fields[0] < $b_fields[0]);
	# Compare the yymmdd 
	return 1 if ($a_fields[1] > $b_fields[1]);
	return -1 if ($a_fields[1] < $b_fields[1]);
	# Entries on the same day, compare granule# 
    return 1 if ($a_fields[2] > $b_fields[2]);
    return -1 if ($a_fields[2] < $b_fields[2]);
	# Compare site
    return 1 if ($a_fields[3] > $b_fields[3]);
    return -1 if ($a_fields[3] < $b_fields[3]);
	# compare ver#
    return 1 if ($a_fields[4] > $b_fields[4]);
    return -1 if ($a_fields[4] < $b_fields[4]);
	return 0;  # Two entries are identical.
}

sub set_products_status {
	local(*products_status, $stat_str, @products) = @_;
	# Add status to products_status vi exclusive-OR.
	local($p,$stat);
	$stat = $FAILED if ($stat_str eq $FAILED_STR);
	$stat = $SUCCESSFUL if ($stat_str eq $SUCCESSFUL_STR);
	$stat = $WARNING if ($stat_str eq $WARNING_STR);
	$stat = $RUNNING if ($stat_str eq $RUNNING_STR);
    $stat = $FINISHED if ($stat_str eq $FINISHED_STR);
	$stat = $ABORTED if ($stat_str eq $ABORTED_STR);

	foreach $p (@products) {
		$products_status{$p} |= $stat;
	}
} # set_products_status


sub select_active_products {
	local(@prods_list) = @_;
	local($p);
	local(@active_prods_list) = ();
	foreach $p (@prods_list) {
		push(@active_prods_list, $p) if ($product_list{$p});
	}
	return @active_prods_list;
}
1;

