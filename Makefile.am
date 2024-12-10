AUTOMAKE_OPTIONS = foreign
SUBDIRS = doc

bin_SCRIPTS = $(scripts)

aiw_scripts = aiwII_level2 level2_darwin.csh level2_melbourne.csh \
	singlevos_2A-53-d_aiw singlevos_2A-53-w_aiw singlevos_2A-55_aiw

all_tape_scripts = all_tape_level_1 all_tape_level_1n2 all_tape_common.pl \
        level_3 all_tape_2A-52

all_cd_scripts = all_tapes all_cd

monthly_scripts = monthly_2A-52

scripts = $(aiw_scripts) $(all_tape_scripts) $(all_cd_scripts) \
	hdf2img_for_dir hdf2img gvs_production_common.pl $(monthly_scripts) \
	level_1_singlevos_uf_to_granule_hdf


datadir = $(prefix)/data
data_DATA = products_version_numbers

all_tape_level_1n2: Makefile
	@for p in $(scripts); do \
	   echo -n "Checking file $$p ... ";\
	   cp $$p $$p.in;\
	   sed -e 's&PROG_VERSION[ ]*=.*&PROG_VERSION = \"$(PACKAGE)-$(VERSION)\";&' \
		-e 's&#\!.*perl&#\! $(perlbin)&' \
		-e 's&(\@INC,.*&(\@INC, \".\", \"$(bindir)\"\)\;&' \
	   < $$p.in > $$p.new;\
	   if cmp -s $$p $$p.new; then \
          rm $$p.new; \
          echo "$$p remains untouched."; \
       else \
          mv $$p.new $$p; \
          echo "substitutions made in $$p."; \
       fi;\
	   rm -f $$p.in;\
    done

# These are installed if not already present. They are place holders
# in the event you don't install the monitorps package.
monitorps_progs = send_status send_product

EXTRA_DIST = $(bin_SCRIPTS) CHANGES $(data_DATA) Copyright GPL \
             $(monitorps_progs)

install-exec-hook:
	@for p in $(monitorps_progs); do \
		if [ ! -r $(bindir)/$$p ]; then \
			cp $$p $(bindir); \
		fi; \
	done
