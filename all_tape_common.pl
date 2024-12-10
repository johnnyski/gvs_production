#! /usr/bin/perl
#-*-Perl-*-
#
# Common definitions and routines for the all_tape* scripts.
#
#
unshift (@INC, ".", "/usr/local/trmm/GVBOX/bin");
do 'gvs_production_common.pl';

$in = "0";       # Input
$out = "1";      # Output

# out of disk space
$WORKING_FILE_SYSTEM_ONLY = 1;
$OUTPUT_FILE_SYSTEM_ONLY  = 2;
$WORKING_N_OUTPUT_FILE_SYSTEMS  = 3;
$NONE_SYSTEM = 0;

# Supporting sites. These name should be the same as the names 
# defined in 'level_1'.
$melb = "MELB";
$kwaj = "KWAJ";  # level 1 only
$darw = "DARW";  # Gunn Point
$darb = "DARB";  # Berrimah
$unknown = "UNKN"; # unknown site. Default


$gvs_data_path = $ENV{'GVS_DATA_PATH'};
if ($gvs_data_path eq "") {
	$gvs_data_path = "/usr/local/trmm/GVBOX/data";  # Default
}


sub get_available_disk_space {
	local($filename) = @_;
	# Return the available disk space in blocks; -1 if unable to
	# obtain it using 'df'--may have encountered unrecognized format 
	# of 'df'.
	#
	# Different flatforms have different df output, i.e., 'df' gives the 
	# following results from different machines:
	# Linux: 
	#  Filesystem         1024-blocks  Used Available Capacity Mounted on
	#  /dev/sda1            1895817 1190475   607348     66%   /
	#
	# HP:
	#  /              (/dev/dsk/c207d6s0   ):   223626 blocks    226435 i-nodes
	#
	# SGI:
	#  Filesystem             Type  blocks     use     avail  %use Mounted on
	#  /dev/root               efs  1582460  1135559   446901  72  /

	local($hosttype) = $ENV{'HOSTTYPE'};
	local($file_sys) = $filename;

	local(@file_sys_elem) = split(/\//, $file_sys);
	$file_sys = "/".$file_sys_elem[1];
	local($cmd) = "df $file_sys |";
	open(DF_OUTPUT, $cmd) || (do clean_up("", 0) && exit($SEVERE_ERROR_CODE));
	local(@df_output_lines) = <DF_OUTPUT>;
	close(DF_OUTPUT);
	local(@disk_info);  # Should be the last line from df_output_lines
	local(@avail_dkspace);
	while (@df_output_lines) {
		local($str) = shift @df_output_lines;
		@avail_dkspace = split(' ', $str);
	}

	# Get available blocks in the third from last field.  This takes into
        # account possible line breaks in df output caused by long device names.

	local($num_of_elements);
	$num_of_elements = @avail_dkspace;
	$avail_dkspace = $avail_dkspace[$num_of_elements - 3];

	if ($avail_dkspace eq "") {
		print STDERR "$this_prog: Expect available block to be on the 4th field of df output\n";
		return -1;
	}
	return $avail_dkspace;
}

sub read_dirs_from_file {
	local($fname, $lock_file) = @_;
	
	# Lock file if $lock_file = 1.
	# Returns a list of dir names from the file.

	local(@dirs_list, @tmp_list) = ();
	return @dirs_list if ($fname eq "" || !(-e $fname));

	open (DFILE, $fname) || return @dirs_list;
	flock(DFILE, $LOCK_EX) if ($lock_file == 1);  # lock file
	@tmp_list = <DFILE>;
	flock(DFILE, $LOCK_UN) if ($lock_file == 1);  # unlock file
	close(DFILE);
	return @dirs_list if ($#tmp_list <= -1);
	while (@tmp_list) {
		local($tmp_str) = shift @tmp_list;
		chop($tmp_str) if $tmp_str =~ /(\r)|(\n)/;
		next if ($tmp_str eq "");   # blank line, skip
		# Change top output dir
		local($dir) = &change2absolute_dir2($save_curr_dir, $tmp_str);
		push(@dirs_list, $dir);
	}

	return @dirs_list;
} # read_dirs_from_file 

sub remove_processed_files_from_list {
	# Returns a list of files needed to be processed
	# (It includes the $first_infile to the end of list).
	# @infile_list must be sorted.
	# It will delete processed file(s) from disk if requested.
	# If dir eq "", then filename(s) in file_list are absolute names; 
	# otherwise, they are just filename with no prefix dir.
	# $first_unprocessed_fname can be a pattern.
	local($dir, $delete_from_disk, $first_unprocessed_fname, @file_list) = @_;
	
	local(@fname_path) = split(/\//, $first_unprocessed_fname);
	local($start_fname) = $first_unprocessed_fname;
	$start_fname = $fname_path[$#fname_path] if ($dir ne "");
	$start_fname =~ s/(\.gz)|(\.Z)//g;  # Remove extension

# If the $first_unprocessed_fname is not on the list, but, could
# be listed earlier than the first non header file, then return
# the filelist.

	while(@file_list) {
		local($fname) = shift @file_list;
		$f = $fname;
		$f =~ s/(\.gz)|(\.Z)//g;  # Remove extension
		if ($f ge /$start_fname/) {
			# Found the start file; put it back to list; break
			unshift(@file_list, $f);
			last;
		}
		unlink $dir.$fname if $delete_from_disk == 1;
	}

	return @file_list;
									  
} # remove_processed_files_from_list


sub remove_bottom_unwanted_files_from_list {
	# Returns a list of files (excluding all files followed the last_file).
	# @infile_list must be sorted.
	# It will delete the unselected files from disk if specified.
	# If dir eq "", then filename(s) in file_list are absolute names; 
	# otherwise, they are just filename with no prefix dir.
	# $last_fname can be a pattern.
	local($dir, $delete_from_disk, $last_fname, @file_list) = @_;
	
	local(@fname_path) = split(/\//, $last_fname);
	$last_fname = $fname_path[$#fname_path] if ($dir ne "");

	$last_fname =~ s/(\.gz)|(\.Z)//g;  # Remove extension
	local(@new_file_list) = ();

	while(@file_list) {
		local($fname) = shift @file_list;
		push(@new_file_list, $fname);
		if ($fname =~ /$last_fname/) {
			last;
		}
	}
	if ($delete_from_disk && $#file_list >= 0) {
		do do_system_call("cd $dir; rm -f @file_list");
	}
	return @new_file_list;
									  
} # remove_bottom_unwanted_files_from_list 


# Get options from options file. 
sub get_options_from_file {
	local($fname) = @_;
	local($opts);

	open (OPTIONS, $fname) ||
		(do clean_up() && die "Couldn't run $cmd: $!\n");
	$opts = <OPTIONS>; 
	close(OPTIONS);
	chop $opts if $opts =~ /(\n)|(\r)/;
	$opts;
}

sub get_prod_version_num {
	local($product, $in_or_out) = @_;

	# Returns version number from file for product depending on $in_or_out.
	# If version file does not exist or version number does not exist for
	# product, return 1.

	# Version file contains version number for each product.  The file
	# has 3 columns defined as followed:
	#  [product]   [version # for output file]  [version # for input file] 
	#

	open(VERSION_FILE, "< $version_fname") || return 1;
	
	local(@lines) = <VERSION_FILE>;
	close(VERSION_FILE);
	while (@lines) {
		local($line) = shift @lines;
		chop $line if $line =~ /\n/;
#		print STDERR "LINE: <$line>\n";
		# line: 
		# [product]   [version # for output file]  [version # for input file] 
		# -- Comment line

		next if ($line =~ /^\s*--/);  # Comment line, skip
		local($p, $out_version, $in_version) = 
			$line =~ /^\s*([a-zA-Z0-9_-]+)\s+(\d+)\s+(\d+)/;

		if ($p eq $product)  {
			return $in_version if ($in_or_out eq $in && $in_version != 0);
			return $out_version if ($in_or_out eq $out && $out_version != 0);
		}
	}
	return 1;
		
} # get_prod_version_num

sub send_status_msg {
	local($jobnum, $p, $infile, $stat_str) = @_;
	# Use global tape_id and device
	local($options) = "-e ";
	
	local($stat_msg) = "$options $jobnum $tape_id $device $p $infile $stat_str";

	local($send_status_prog) = "send_status";
	$send_status_prog = "echo" if ($not_report_monitorps == 1);
	local($send_cmd) = "$send_status_prog $stat_msg";

	system($send_cmd);
	local($status) = $? >> 8;
	local($signal) = $? & 255;
	do doexit_handler($signal) 
		if ($signal eq 'INT' || $signal eq 'KILL' || $signal eq 'STOP' ||
			$signal == 9 || $signal == 2);

	do doexit_handler('INT') if (&interrupted($status));
}


sub send_prod_msg_to_gvics {
	local($tape_id, $prod, $prod_processed_num, $prod_version, $device,
		  $device_location, $prod_status_str, $prod_processed_date, 
		  $prod_processed_time) = @_;
    # Send message to 'gvics' to update product info from the GV 
    # inventory database.

	return if ($tape_id eq "" || $prod eq "" || $prod_processed_num eq "");

	local($update_cmd) = "echo \"ADD_PROD TAPE_ID $tape_id PROD_NAME $prod PROD_PROCESSED_NUM $prod_processed_num";

	$update_cmd .= " PROD_VERSION_NUM $prod_version" if ($prod_version ne "");
    $update_cmd .= " PROD_PROCESSED_DATE $prod_processed_date" 
		if ($prod_processed_date ne "");
	$update_cmd .= " PROD_PROCESSED_TIME $prod_processed_time"
		if ($prod_processed_time ne "");
	$update_cmd .= " PROD_DEVICE_TYPE $device"
		if ($device ne "");
	$update_cmd .= " PROD_DEVICE_LOCATION $device_location"
		if ($device_location ne "");
	$update_cmd .= " PROD_PROCESSED_STATUS $prod_status_str"
		if ($prod_status_str ne "");
	$update_cmd .= "\"|gvics";
	print STDERR "Executing <$update_cmd>...\n";
	system($update_cmd);
	local($status) = $? >> 8;
	local($signal) = $? & 255;
	do doexit_handler($signal) 
		if ($signal eq 'INT' || $signal eq 'KILL' || $signal eq 'STOP' ||
			$signal == 9 || $signal == 2);

	do doexit_handler('INT') if (&interrupted($status));
}


sub send_tape_msg_to_gvics {
	local($tape_id, $tape_start_time_sec, 
		  $tape_end_time_sec, $tape_num_of_files, $device, $device_location,
		  $site_name) = @_;
    # Send message to 'gvics' to update tape info from the GV 
    # inventory database.

	return if ($tape_id eq "" || $tape_start_time_sec <= 0 ||
			   $tape_end_time_sec <= 0);

	# Check with the db to get the actual start/end time.
	local($get_cmd) = "echo \"get TAPE_START_DATE TAPE_START_TIME TAPE_END_DATE TAPE_END_TIME where TAPE_ID = $tape_id\"|gvics|";
	print STDERR "Executing <$get_cmd>...\n";
	open(GET_RESULT, $get_cmd) || return;

	local(@lines) = <GET_RESULT>;
	close(GET_RESULT);
	# @lines format: header
    #                ------
    #                result
	local($update_start_time) = 0;
	local($update_end_time) = 0;
	if ($#lines >= 2) {
		local(@result) = split(/\|/, $lines[$#lines]);
		if ($result[0] =~ /\s*\d+\-\d+\-\d+\s*/ && $result[1]  =~ /\s*\d+:\d+\s*/) {
			local($db_start_time_sec) = &date_time_strs2seconds2($result[0], $result[1]);

			if ($db_start_time_sec > $tape_start_time_sec) {
				$update_start_time = 1;
			}
		}
		else {
			$update_start_time = 1;
		}
		if ($result[2] =~ /\s*\d+\-\d+\-\d+\s*/ && $result[3]  =~ /\s*\d+:\d+\s*/) {
			local($db_end_time_sec) = &date_time_strs2seconds2($result[2], $result[3]);		
			if ($db_end_time_sec < $tape_end_time_sec) {
				$update_end_time = 1;
			}
		}
		else {
			$update_end_time = 1;
		}
			
	}
	else {
		# Date,time doesnot exist yet.
		$update_end_time = 1;
		$update_start_time = 1;
	}
	local($update_cmd) = "";
	if ($update_start_time) {
		local($sdate_str, $stime_str) = "";
		do time_seconds2date_time_strs($tape_start_time_sec, *sdate_str, *stime_str);
		# Update start time
		$update_cmd .= " TAPE_START_DATE $sdate_str" 
			if ($sdate_str ne "");
		$update_cmd .= " TAPE_START_TIME $stime_str"
			if ($stime_str ne "");
	}
	if ($update_end_time) {

		local($edate_str, $etime_str) = "";
		do time_seconds2date_time_strs($tape_end_time_sec, *edate_str, *etime_str);
		# Update start time
		$update_cmd .= " TAPE_END_DATE $edate_str" 
			if ($edate_str ne "");
		$update_cmd .= " TAPE_END_TIME $etime_str"
			if ($etime_str ne "");

	}

	$update_cmd = "echo \"ADD_TAPE TAPE_ID $tape_id ".$update_cmd;
	$update_cmd .= " TAPE_NUM_OF_FILES $tape_num_of_files"
		if ($tape_num_of_files ne "");
	$update_cmd .= " DEVICE_TYPE $device"
		if ($device ne "");
	$update_cmd .= " DEVICE_LOCATION $device_location"
		if ($device_location ne "");
	$update_cmd .= " SITE_NAME $site_name"
		if ($site_name ne "");
	$update_cmd .= "\"|gvics";
	print STDERR "Executing <$update_cmd>...\n";
	system($update_cmd);
	local($status) = $? >> 8;
	local($signal) = $? & 255;
	do doexit_handler($signal) 
		if ($signal eq 'INT' || $signal eq 'KILL' || $signal eq 'STOP' ||
			$signal == 9 || $signal == 2);

	do doexit_handler('INT') if (&interrupted($status));

} #send_tape_msg_to_gvics

sub send_site_msg_to_gvics {
	local($site_name, $tsdis_name, $site_data_type) = @_;
    # Send message to 'gvics' to update site info from the GV 
    # inventory database.

	return if (site_name eq "");
	local($update_cmd) = "echo \"ADD_SITE SITE_NAME  \\\"$site_name \\\"";
	$update_cmd .= " SITE_ACRONYM $tsdis_name"
		if ($tsdis_name ne "");
	$update_cmd .= " SITE_DATA_TYPE $site_data_type"
		if ($site_data_type ne "");
	$update_cmd .= "\"|gvics";
	print STDERR "Executing <$update_cmd>...\n";
	system($update_cmd);
	local($status) = $? >> 8;
	local($signal) = $? & 255;
	do doexit_handler($signal) 
		if ($signal eq 'INT' || $signal eq 'KILL' || $signal eq 'STOP' ||
			$signal == 9 || $signal == 2);

	do doexit_handler('INT') if (&interrupted($status));

} # send_site_msg_to_gvics


sub send_file_msg_to_gvics {
	local($file_name, $tape_id, $prod, $prod_processed_num,
		  $tape_file_num, $file_size,
		  $reflectivity_percent, $file_type, $file_date, $file_time,
		   $file_is_compressed, $runtime_params_list) = @_;
    # Send message to 'gvics' to update file info from the GV 
    # inventory database.

	return if ($file_name eq "" || $tape_id eq "" || $prod eq "");
	local($update_cmd) = "echo \"ADD_FILE FILE_NAME $file_name TAPE_ID $tape_id PROD_NAME $prod PROD_PROCESSED_NUM $prod_processed_num";
	$update_cmd .= " TAPE_FILE_NUM $tape_file_num"
		if ($tape_file_num ne "");
	$update_cmd .= " FILE_SIZE $file_size"
		if ($file_size ne "");
	$update_cmd .= " REFLECTIVITY_PERCENT $reflectivity_percent"
		if ($reflectivity_percent ne "");
	$update_cmd .= " FILE_TYPE $file_type"
		if ($file_type ne "");
	$update_cmd .= " FILE_DATE $file_date"
		if ($file_date ne "");
	$update_cmd .= " FILE_TIME $file_time"
		if ($file_time ne "");
	$update_cmd .= " FILE_IS_COMPRESSED $file_is_compressed"
		if ($file_is_compressed ne "");
	$update_cmd .= " RUNTIME_PARAMS_LIST\\\" $runtime_params_list\\\""
		if ($runtime_params_list ne "");

	$update_cmd .= "\"|gvics";

	print STDERR "Executing <$update_cmd>...\n";
	system($update_cmd);
	local($status) = $? >> 8;
	local($signal) = $? & 255;
	do doexit_handler($signal) 
		if ($signal eq 'INT' || $signal eq 'KILL' || $signal eq 'STOP' ||
			$signal == 9 || $signal == 2);

	do doexit_handler('INT') if (&interrupted($status));

} # send_file_msg_to_gvics



sub send_product_info_to_inventory {
	local($tape_id, *prods_list, *prods_options_list,
		  $prod_processed_num, *prods_status, $level1_prod_dir) = @_;
	# Send file for each product and product info to the 
    # GV inventory db.

	local ($p);
	foreach $p (@prods_list) {
		local($output_dir);
		if ($p eq "level_1") {
			$output_dir = $level1_prod_dir;
		}
		else {
			 $output_dir = $top_output_dir.&get_dir_name($p, $tape_id); 
		}
		opendir(THISDIR, $output_dir);
		local(@files) = grep(/\.(HDF)|(uf)|(asc)|([0-9])/, readdir(THISDIR));
		closedir(THISDIR);
		local($fnum) = 0;

		while (@files) {
			local($fname) = shift @files;
			local($dev, $ino, $mod, $nlink, $uid, $gid, $rdv, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($output_dir.$fname);

			$fnum++;
			local($date_str, $time_str) = "";

			time_seconds2date_time_strs($mtime, *date_str, *time_str);

			local($compress_str) = "FALSE";
			$compress_str = "TRUE" if ($fname =~ /(\.gz$)|(\.Z$)/);
		    if ($fname =~ /uf/) {
				$ftype = $UF_type;
			}
		    elsif ($fname =~ /HDF/) {
				$ftype = $HDF_type;									   
			}
			else {
				$ftype = $ASCII_type;
			}
			
			$ftype = $UF_type if ($fname =~ /uf/);
			# Send info on file (size, date, etc...)
			do send_file_msg_to_gvics($fname, $tape_id, $p, 
									  $prod_processed_num, $fnum, 
									  $size, "", 
									  $ftype, $date_str, $time_str,
									  $compress_str,
									  $prods_options_list{$p});

												   
			local($prod_version_float) = sprintf("%f", &get_prod_version_num($p, $out));
	   }

	   # Only send info on product once.
									   
	   # Status: failed dominants warning, successful
	   #         Warning dominants successful.
       #
	   #         aborted dominants finished, running.
	   #         finished dominants running.
	   local($prod_status_str) = "";
	   $prod_status_str = $SUCCESSFUL_STR
		   if ($prods_status{$p} & $SUCCESSFUL);
	   $prod_status_str = $WARNING_STR
		   if ($prods_status{$p} & $WARNING);
	   $prod_status_str = $FAILED_STR
		   if ($prods_status{$p} & $FAILED);
		   
	   local($separator) = "/";
		   
	   if ($prods_status{$p} & $ABORTED) {
		   $prod_status_str .= $separator.$ABORTED_STR;
	   }
	   elsif ($prods_status{$p} & $FINISHED) {
		   $prod_status_str .= $separator.$FINISHED_STR;
	   }
	   elsif ($prods_status{$p} & $RUNNING) {
		   $prod_status_str .= $separator.$RUNNING_STR;
	   }
	   local($curr_date_str, $curr_time_str);
	   do get_current_date_time(*curr_date_str, *curr_time_str);

	   do send_prod_msg_to_gvics($tape_id, $p, $prod_processed_num,
								 $prod_version_float,		  
								 $device, $output_dir, 
								 $prod_status_str, $curr_date_str,
								 $curr_time_str);

   } # foreach
} # send_product_info_to_inventory


1;








