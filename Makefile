# SPDX-License-Identifier: GPL-3.0-or-later

# Makefile Create libpmc and pmc for testing
#
# @author Erez Geva <ErezGeva2@@gmail.com>
# @copyright 2021 Erez Geva
# @copyright GNU General Public License 3.0 or later

PMC_USE_LIB?=a # 'a' for static and 'so' for dynamic

define help
################################################################################
#  Make file targets                                                           #
################################################################################
#                                                                              #
#   all              Build all targets.                                        #
#                                                                              #
#   clean            Clean intermediate files.                                 #
#                                                                              #
#   distclean        Perform full clean includes build application and         #
#                    generated documents.                                      #
#                                                                              #
#   format           Format source code and warn of format issues.             #
#                                                                              #
#   doxygen          Create library documentation.                             #
#                                                                              #
#   checkall         Call doxygen and format targets.                          #
#                                                                              #
#   help             See this help.                                            #
#                                                                              #
#   install          Install application, libraries, and headers in system.    #
#                                                                              #
#   deb              Build Debian packages.                                    #
#                                                                              #
#   deb_src          Build Debian source package.                              #
#                                                                              #
#   deb_clean        Clean Debian intermediate files.                          #
#                                                                              #
################################################################################
#  Make file parameters                                                        #
################################################################################
#                                                                              #
#   PMC_USE_LIB      Select the pmc tool library link,                         #
#                    use 'a' for static library or 'so' for shared library.    #
#                                                                              #
#   DESTDIR          Destination folder for install target.                    #
#                    Installation prefix.                                      #
#                                                                              #
#   LIBDIR           Library folder for installation                           #
#                                                                              #
#   LD_SONAME        Link with soname                                          #
#                                                                              #
#   SONAME_USE_MAJ   Use soname with major version                             #
#                                                                              #
#   DEV_PKG          Development package name, default libpmc-dev.             #
#                                                                              #
#   PY_LIBDIR        Python libraries folder, default /usr/lib/python          #
#                                                                              #
#   CPPFLAGS_OPT     Compilation optimization, default for debug               #
#                                                                              #
#   TARGET_ARCH      Taget architectue, used for cross compilation.            #
#                    On Amd and Intel 64 bits default is x86_64-linux-gnu      #
#                                                                              #
#   BUILD_ARCH       Build machine architectue, used for cross compilation.    #
#                    On Amd and Intel 64 bits default is x86_64-linux-gnu      #
#                                                                              #
#   PY2_ARCH         Python version 2 architectue for shared library           #
#                    Default is TARGET_ARCH                                    #
#                                                                              #
#   PY3_ARCH         Python version 2 architectue for shared library           #
#                    Default is TARGET_ARCH                                    #
#                                                                              #
#   NO_COL           Prevent colour output.                                    #
#                                                                              #
#   USE_COL          Force colour when using pipe for tools like 'aha'.        #
#                    For example: make -j USE_COL=1 | aha > out.html           #
#                                                                              #
#   NO_SWIG          Prevent compiling Swig plugins.                           #
#                                                                              #
#   NO_PERL          Prevent compiling Perl Swig plugin.                       #
#                                                                              #
#   NO_LUA           Prevent compiling Lua swig plugin.                        #
#                                                                              #
#   NO_RUBY          Prevent compiling Ruby Swig plugin.                       #
#                                                                              #
#   NO_PYTHON        Prevent compiling Python Swig plugin.                     #
#                                                                              #
#   NO_PHP           Prevent compiling PHP Swig plugin.                        #
#                                                                              #
#   PMC_USE_CJSON    Use C JSON for parsing JSON into PTP management message.  #
#                                                                              #
#   PMC_USE_FCJSON   Use C JSON for parsing JSON into PTP management message.  #
#                    Use fast JSON library.                                    #
#                                                                              #
################################################################################

endef
which=$(shell which $1 2>/dev/null)
define depend
$1: $2

endef
SP:=$(subst X, ,X)
verCheckDo=$(shell if [ $1 -eq $4 ];then test $2 -eq $5 && a=$3 b=$6 || \
  a=$2 b=$5; else a=$1 b=$4;fi;test $$a -lt $$b && echo l)
verCheck=$(call verCheckDo,$(firstword $(subst ., ,$1 0 0 0)),$(word 2,\
  $(subst ., ,$1 0 0 0)),$(word 3,$(subst ., ,$1 0 0 0)),$(firstword\
  $(subst ., ,$2 0)),$(word 2,$(subst ., ,$2 0)),$(word 3,$(subst ., ,$2 0)))

# Use tput to check if we have ANSI Color code
# tput works only if TERM is set
ifneq ($(and $(TERM),$(call which,tput)),)
ifeq ($(shell tput setaf 1),)
NO_COL:=1
endif
endif # which tput
# Detect output is not device (terminal), it must be a pipe or a file
# In case of using 'aha' just call: $ make -j USE_COL=1 | aha > out.html
ifndef USE_COL
ifndef MAKE_TERMOUT
NO_COL:=1
endif
endif # USE_COL

# Terminal colors
ifndef NO_COL
ESC!= printf '\033['
COLOR_BLACK:=      $(ESC)30m
COLOR_RED:=        $(ESC)31m
COLOR_GREEN:=      $(ESC)32m
COLOR_YELLOW:=     $(ESC)33m
COLOR_BLUE:=       $(ESC)34m
COLOR_MAGENTA:=    $(ESC)35m
COLOR_CYAN:=       $(ESC)36m
COLOR_LTGRAY:=     $(ESC)37m
COLOR_DRKGRAY:=    $(ESC)1;30m
COLOR_NORM:=       $(ESC)00m
COLOR_BACKGROUND:= $(ESC)07m
COLOR_BRIGHTEN:=   $(ESC)01m
COLOR_UNDERLINE:=  $(ESC)04m
COLOR_BLINK:=      $(ESC)05m
endif

ifneq ($(V),1)
Q:=@
Q_DOXY=$(info $(COLOR_MAGENTA)Doxygen$(COLOR_NORM))
Q_FRMT=$(info $(COLOR_MAGENTA)Format$(COLOR_NORM))
Q_TAGS=$(info $(COLOR_MAGENTA)[TAGS]$(COLOR_NORM))
Q_GEN=$(info $(COLOR_MAGENTA)[GEN] $@$(COLOR_NORM))
Q_SWIG=$(info $(COLOR_MAGENTA)[SWIG] $@$(COLOR_NORM))
Q_CLEAN=$(info $(COLOR_MAGENTA)Cleaning$(COLOR_NORM))
Q_DISTCLEAN=$(info $(COLOR_MAGENTA)Cleaning all$(COLOR_NORM))
Q_LD=$(info $(COLOR_MAGENTA)[LD] $@$(COLOR_NORM))
Q_AR=$(info $(COLOR_MAGENTA)[AR] $@$(COLOR_NORM))
Q_LCC=$(info $(COLOR_MAGENTA)[LCC] $(basename $@).cpp$(COLOR_NORM))
Q_CC=$(info $(COLOR_MAGENTA)[CC] $(basename $@).cpp$(COLOR_NORM))
LIBTOOL_QUIET:=--quiet
MAKE_NO_DIRS:=--no-print-directory
endif

include version
# Ensure linker use C++
RL:=ranlib
LN:=ln -fs
SED:=sed
MD:=mkdir -p
TAR:=tar cfJ
CPPFLAGS_OPT?=-Og
CPPFLAGS+=-Wdate-time -Wall -std=c++11 -g $(CPPFLAGS_OPT)
# SWIG warnings
CPPFLAGS_LUA:=-Wno-maybe-uninitialized
CPPFLAGS_PY:=-Wno-stringop-overflow
CPPFLAGS_RUBY:=-Wno-sign-compare -Wno-catch-value -Wno-maybe-uninitialized
CPPFLAGS_PHP:=-Wno-unused-label
CPPFLAGS+= -MT $@ -MMD -MP -MF $(basename $@).d
CPPFLAGS_SO:=-fPIC -DPIC -I.
LIBTOOL_CC=$(Q_LCC)$(Q)libtool --mode=compile --tag=CXX $(LIBTOOL_QUIET)
LIB_VER:=$(ver_maj).$(ver_min)
ifdef SONAME_USE_MAJ
SONAME:=.$(ver_maj)
endif
LIB_NAME:=libpmc
LIB_NAME_SO:=$(LIB_NAME).so
LIB_FNAME_SO:=$(LIB_NAME_SO).$(LIB_VER)
LIB_SNAME_SO:=$(LIB_NAME_SO)$(SONAME)
ifdef LD_SONAME
LDFLAGS_NM=-Wl,--version-script,scripts/lib.ver -Wl,-soname,$@$(SONAME)
endif
LDLIBS_LIB:=-lm
PMC_OBJS:=$(patsubst %.cpp,%.o,$(wildcard pmc*.cpp))
LIB_OBJS:=$(filter-out $(PMC_OBJS),$(patsubst %.cpp,%.o,$(wildcard *.cpp)))
PMC_NAME:=pmc
ver.o: CPPFLAGS+=-DVER_MAJ=$(ver_maj) -DVER_MIN=$(ver_min)
ifdef PMC_USE_CJSON
ifneq ($(wildcard /usr/include/json-c/json.h),)
json.o: CPPFLAGS+=-DPMC_USE_CJSON -isystem /usr/include/json-c
LDLIBS_LIB+=-ljson-c
endif # wildcard json.h
else # PMC_USE_CJSON
ifdef PMC_USE_FCJSON
ifneq ($(wildcard /usr/include/libfastjson/json.h),)
json.o: CPPFLAGS+=-DPMC_USE_CJSON -isystem /usr/include/libfastjson
LDLIBS_LIB+=-lfastjson
endif # wildcard json.h
endif # PMC_USE_FCJSON
endif # PMC_USE_CJSON

ifeq ($(call verCheck,$(shell $(CXX) -dumpversion),4.9),)
# GCC output colors
ifndef NO_COL
CPPFLAGS_COLOR:=-fdiagnostics-color=always
else
CPPFLAGS_COLOR:=-fdiagnostics-color=never
endif
endif # verCheck CXX 4.9
CPPFLAGS+=$(CPPFLAGS_COLOR)

ALL:=$(PMC_NAME) $(LIB_NAME_SO) $(LIB_NAME).a

# Compile library source code
$(LIB_OBJS):
	$(LIBTOOL_CC) $(CXX) -c $(CPPFLAGS) $(basename $@).cpp -o $@
# Depened shared library objects on the static library to ensure build
$(eval $(foreach obj,$(LIB_OBJS), $(call depend,.libs/$(obj),$(obj))))

$(LIB_NAME).a: $(LIB_OBJS)
	$(Q_AR)
	$Q$(AR) rcs $@ $^
	$Q$(RL) $@
$(LIB_NAME_SO): $(foreach obj,$(LIB_OBJS),.libs/$(obj))
	$(Q_LD)
	$Q$(CXX) $(LDFLAGS) $(LDFLAGS_NM) -shared $^ $(LOADLIBES) \
	$(LDLIBS_LIB) $(LDLIBS) -o $@

# pmc tool
pm%.o: pm%.cpp
	$(Q_CC)
	$Q$(CXX) $(CPPFLAGS) -c -o $@ $<
$(PMC_NAME): $(PMC_OBJS) $(LIB_NAME).$(PMC_USE_LIB)
	$(Q_LD)
	$Q$(CXX) $(LDFLAGS) $^ $(LOADLIBES) $(LDLIBS) -o $@

include $(wildcard *.d)

CLEAN:=*.o *.lo *.d .libs/*
DISTCLEAN:=$(ALL)
DISTCLEAN_DIRS:=.libs

clean:
	$Q$(Q_CLEAN)
	$Q$(RM) $(CLEAN)
distclean: deb_clean clean
	$(Q_DISTCLEAN)
	$Q$(RM) $(DISTCLEAN)
	$Q$(RM) -R $(DISTCLEAN_DIRS)

HEADERS:=$(filter-out mngIds.h,$(wildcard *.h))
HEADERS_ALL:=$(HEADERS) mngIds.h
# MAP for  mngIds.cc:
#  %@ => '/'    - Use when a slash is next to a star character
#  %! => '%'    - Self escape, escape precent sign character
#  %# => '#'    - Use on line start when starting a preproccesor in result file
#  %_ =>        - Place marker, retain empty lines
#  %- => ' '    - When need 2 spaces or more. Use with a space between
#  %^ => '\n'   - Add new line in a preprocessor definition only
mngIds.h: mngIds.cc
	$(Q_GEN)
	$Q$(CXX) -E $< | $(SED) 's/^#.*//;/^\s*$$/d;s#%@#/#g' > $@
	$Q$(SED) -i 's/^%#/#/;s/%-/ /g;s/%^/\n/g;s/%_//;s/%!/%/g' $@

DISTCLEAN+=mngIds.h

ifneq ($(call which,astyle),)
astyle_ver:=$(lastword $(shell astyle -V))
ifeq ($(call verCheck,$(astyle_ver),3.1),)
format:
	$(Q_FRMT)
	$(Q)astyle --project=none --options=astyle.opt $(wildcard *.h *.cpp)
	$(Q)./format.pl
endif
endif # which astyle

ifneq ($(call which,dpkg-architecture),)
DEB_TARGET_MULTIARCH?=$(shell dpkg-architecture -qDEB_TARGET_MULTIARCH)
DEB_BUILD_MULTIARCH?=$(shell dpkg-architecture -qDEB_BUILD_MULTIARCH)
endif # which dpkg-architecture
TARGET_ARCH?=$(DEB_TARGET_MULTIARCH)
BUILD_ARCH?=$(DEB_BUILD_MULTIARCH)

ifndef NO_SWIG
ifneq ($(call which,swig),)
swig_ver=$(lastword $(shell swig -version | grep Version))
ifeq ($(call verCheck,$(swig_ver),3.0),)
SWIG:=swig
SWIG_ALL:=
SWIG_NAME:=PmcLib

ifndef NO_PERL
ifneq ($(call which,perl),)
PERL_INC_B!= perl -e 'for(@INC){print "$$_/CORE" if-f "$$_/CORE/EXTERN.h"}'
PERLDIR_B:=$(DESTDIR)$(lastword $(shell perl -e '$$_=$$^V;s/^v//;\
  s/^(\d+\.\d+).*/\1/;$$v=$$_;for(@INC){print "$$_\n" if /$$v/ and /lib/}'))
# Perl does not "know" how to cross properly
ifneq ($(BUILD_ARCH),$(TARGET_ARCH)) # Cross compilation
PERL_INC:=$(subst /$(BUILD_ARCH)/,/$(TARGET_ARCH)/,$(PERL_INC_B))
PERLDIR:=$(subst /$(BUILD_ARCH)/,/$(TARGET_ARCH)/,$(PERLDIR_B))
else
PERL_INC:=$(PERL_INC_B)
PERLDIR:=$(PERLDIR_B)
endif
PERL_NAME:=perl/$(SWIG_NAME)
$(PERL_NAME).cpp: $(LIB_NAME).i $(HEADERS_ALL)
	$(Q_SWIG)
	$Q$(SWIG) -Wall -c++ -I. -outdir perl -o $@ -perl5 $<
$(PERL_NAME).o: $(PERL_NAME).cpp $(HEADERS)
	$(Q_LCC)
	$Q$(CXX) $(CPPFLAGS) $(CPPFLAGS_SO) -I$(PERL_INC) -c $< -o $@
	$Q$(SED) -i 's#$(PERL_INC)#\$$(PERL_INC)#' $(PERL_NAME).d
$(PERL_NAME).so: $(PERL_NAME).o $(LIB_NAME_SO)
	$(Q_LD)
	$Q$(CXX) $(LDFLAGS) -shared $^ $(LOADLIBES) $(LDLIBS) -o $@
SWIG_ALL+=$(PERL_NAME).so
CLEAN+=$(foreach e,d o,$(PERL_NAME).$e)
DISTCLEAN+=$(foreach e,cpp pm so,$(PERL_NAME).$e)
else # which perl
NO_PERL=1
endif
endif # NO_PERL

ifndef NO_LUA
ifneq ($(call which,lua),)
LUA_LIB_NAME:=pmc.so
lua/$(SWIG_NAME).cpp: $(LIB_NAME).i $(HEADERS_ALL)
	$(Q_SWIG)
	$Q$(SWIG) -Wall -c++ -I. -outdir lua -o $@ -lua $<
DISTCLEAN+=lua/$(SWIG_NAME).cpp lua/$(LUA_LIB_NAME)
define lua
LUA_FLIB_$1:=liblua$1-$(LUA_LIB_NAME)
ifdef LD_SONAME
LD_LUA_$1:=-Wl,-soname,$$(LUA_FLIB_$1)$(SONAME)
endif
LUA_LIB_$1:=lua/$1/$(LUA_LIB_NAME)
lua/$1/$(SWIG_NAME).o: lua/$(SWIG_NAME).cpp $(HEADERS)
	$Q$(MD) lua/$1
	$$(Q_LCC)
	$Q$(CXX) $$(CPPFLAGS) $(CPPFLAGS_SO) $(CPPFLAGS_LUA) -I/usr/include/lua$1 \
	-c $$< -o $$@
$$(LUA_LIB_$1): lua/$1/$(SWIG_NAME).o $(LIB_NAME_SO)
	$$(Q_LD)
	$Q$(CXX) $(LDFLAGS) -shared $$^ $(LOADLIBES) $(LDLIBS) \
	$$(LD_LUA_$1) -o $$@
SWIG_ALL+=$$(LUA_LIB_$1)
DISTCLEAN_DIRS+=lua/$1

endef
# Build multiple Lua versions
LUA_VERSIONS:=$(subst /,,$(subst /usr/include/lua,,$(dir\
  $(wildcard /usr/include/lua*/lua.h))))
$(eval $(foreach n,$(LUA_VERSIONS),$(call lua,$n)))
# Build single Lua version
ifneq ($(wildcard /usr/include/lua.h),)
# Get Lua version and library base
LUA_VER:=$(lastword $(shell lua -e 'print(_VERSION)'))
# Do we have default lua lib, or is it versioned?
ifeq ($(shell /sbin/ldconfig -p | grep liblua.so),)
LUA_BASE:=$(firstword $(subst .so, ,$(notdir $(lastword $(shell\
   /sbin/ldconfig -p | grep "lua.*$(LUA_VER)\.so$$")))))
LUA_FLIB:=$(LUA_BASE)-$(LUA_LIB_NAME)
else
LUA_FLIB:=liblua-$(LUA_LIB_NAME)
endif
ifdef LD_SONAME
LD_LUA:=-Wl,-soname,$(LUA_FLIB)$(SONAME)
endif
LUA_LIB:=lua/$(LUA_LIB_NAME)
lua/$(SWIG_NAME).o: lua/$(SWIG_NAME).cpp $(HEADERS)
	$(Q_LCC)
	$Q$(CXX) $(CPPFLAGS) $(CPPFLAGS_SO) $(CPPFLAGS_LUA) -c $< -o $@
$(LUA_LIB): lua/$(SWIG_NAME).o $(LIB_NAME_SO)
	$(Q_LD)
	$Q$(CXX) $(LDFLAGS) -shared $^ $(LOADLIBES) $(LDLIBS) \
	$(LD_LUA) -o $@
SWIG_ALL+=$(LUA_LIB)
DISTCLEAN+=$(LUA_LIB)
endif # /usr/include/lua.h
CLEAN+=$(wildcard lua/*.[od]) $(wildcard lua/*/*.[od])
else # which lua
NO_LUA=1
endif
endif # NO_LUA

ifndef NO_PYTHON
ifneq ($(call which,python),)
PY_BASE:=python/$(SWIG_NAME)
PY_LIB_NAME:=_pmc
PY_LIBDIR?=/usr/lib/python
$(PY_BASE).cpp: $(LIB_NAME).i $(HEADERS_ALL)
	$(Q_SWIG)
	$Q$(SWIG) -Wall -c++ -I. -outdir python -o $@ -python $<
define python
ifneq ($$(call which,python$1-config),)
PY_BASE_$1:=python/$1/$(SWIG_NAME)
PY_SO_$1:=python/$1/$(PY_LIB_NAME).so
PY_INC_$1!=python$1-config --includes
PY_LD_$1!=python$1-config --libs
PY$1_DIR:=$(DESTDIR)$$(lastword $$(shell python$1 -c 'import site; \
  print("\n".join(site.getsitepackages()))' | grep $(PY_LIBDIR)))
$$(PY_BASE_$1).o: $(PY_BASE).cpp $(HEADERS)
	$Q$(MD) python/$1
	$$(Q_LCC)
	$Q$(CXX) $$(CPPFLAGS) $(CPPFLAGS_SO) $(CPPFLAGS_PY) $$(PY_INC_$1) -c $$< -o $$@
$$(PY_SO_$1): $$(PY_BASE_$1).o $(LIB_NAME_SO)
	$$(Q_LD)
	$Q$(CXX) $(LDFLAGS) -shared $$^ $(LOADLIBES) $(LDLIBS) $$(PY_LD_$1) -o $$@
SWIG_ALL+=$$(PY_SO_$1)
CLEAN+=$$(wildcard python/$1/*.[od])
DISTCLEAN_DIRS+=python/$1
endif

endef
DISTCLEAN+=$(PY_BASE).cpp $(wildcard python/*.so) python/pmc.py python/pmc.pyc
DISTCLEAN_DIRS+=python/__pycache__
$(eval $(call python,2))
$(eval $(call python,3))
else # which python
NO_PYTHON=1
endif
endif # NO_PYTHON

ifndef NO_RUBY
ifneq ($(call which,ruby),)
# configuration comes from /usr/lib/*/ruby/*/rbconfig.rb
RUBY_SCRIPT_INCS:='puts "-I" + RbConfig::CONFIG["rubyhdrdir"] +\
                       " -I" + RbConfig::CONFIG["rubyarchhdrdir"]'
RUBY_SCRIPT_LIB:='puts "-l" + RbConfig::CONFIG["RUBY_SO_NAME"]'
RUBY_SCRIPT_VDIR:='puts RbConfig::CONFIG["vendorarchdir"]'
RUBY_INC_B!= ruby -rrbconfig -e $(RUBY_SCRIPT_INCS)
RUBY_LIB_B!= ruby -rrbconfig -e $(RUBY_SCRIPT_LIB)
RUBYDIR_B:=$(DESTDIR)$(shell ruby -rrbconfig -e $(RUBY_SCRIPT_VDIR))
# Ruby does not "know" how to cross properly
ifneq ($(BUILD_ARCH),$(TARGET_ARCH)) # Cross compilation
RUBY_INC:=$(subst /$(BUILD_ARCH)/,/$(TARGET_ARCH)/,$(RUBY_INC_B))
RUBY_LIB:=$(subst /$(BUILD_ARCH)/,/$(TARGET_ARCH)/,$(RUBY_LIB_B))
RUBYDIR:=$(subst /$(BUILD_ARCH)/,/$(TARGET_ARCH)/,$(RUBYDIR_B))
else
RUBY_INC:=$(RUBY_INC_B)
RUBY_LIB:=$(RUBY_LIB_B)
RUBYDIR:=$(RUBYDIR_B)
endif
RUBY_NAME:=ruby/$(SWIG_NAME).cpp
RUBY_LNAME:=ruby/pmc
$(RUBY_NAME): $(LIB_NAME).i $(HEADERS_ALL)
	$(Q_SWIG)
	$Q$(SWIG) -c++ -I. -outdir ruby -o $@ -ruby $<
$(RUBY_LNAME).o: $(RUBY_NAME) $(HEADERS)
	$(Q_LCC)
	$Q$(CXX) $(CPPFLAGS) $(CPPFLAGS_SO) $(CPPFLAGS_RUBY) $(RUBY_INC) -c $< -o $@
$(RUBY_LNAME).so: $(RUBY_LNAME).o $(LIB_NAME_SO)
	$(Q_LD)
	$Q$(CXX) $(LDFLAGS) -shared $^ $(LOADLIBES) $(LDLIBS) $(RUBY_LIB) -o $@
SWIG_ALL+=$(RUBY_LNAME).so
CLEAN+=$(RUBY_NAME) $(foreach e,d o,$(RUBY_LNAME).$e)
DISTCLEAN+=$(RUBY_LNAME).so
else # which ruby
NO_RUBY=1
endif
endif # NO_RUBY

ifndef NO_PHP
ifneq ($(call which,php-config),)
ifneq ($(call which,php-config7),)
PHPCFG:=php-config7
else
PHPCFG:=php-config
endif
php_ver=$(subst $(SP),.,$(wordlist 1,2,$(subst ., ,$(shell $(PHPCFG) --version))))
ifeq ($(call verCheck,$(php_ver),7.0),)
# Old SWIG does not support PHP 7
ifeq ($(call verCheck,$(swig_ver),3.0.12),)
PHPEDIR:=$(DESTDIR)$(shell $(PHPCFG) --extension-dir)
PHPIDIR:=$(DESTDIR)$(lastword $(subst :, ,$(shell\
        php -r 'echo get_include_path();')))
PHP_INC:=-Iphp $(shell $(PHPCFG) --includes)
PHP_NAME:=php/$(SWIG_NAME).cpp
PHP_LNAME:=php/pmc
$(PHP_NAME): $(LIB_NAME).i $(HEADERS_ALL)
	$(Q_SWIG)
	$Q$(SWIG) -c++ -I. -outdir php -o $@ -php7 $<
$(PHP_LNAME).o: $(PHP_NAME) $(HEADERS)
	$(Q_LCC)
	$Q$(CXX) $(CPPFLAGS) $(CPPFLAGS_SO) $(CPPFLAGS_PHP) $(PHP_INC) -c $< -o $@
$(PHP_LNAME).so: $(PHP_LNAME).o $(LIB_NAME_SO)
	$(Q_LD)
	$Q$(CXX) $(LDFLAGS) -shared $^ $(LOADLIBES) $(LDLIBS) -o $@
SWIG_ALL+=$(PHP_LNAME).so
CLEAN+=$(PHP_NAME) $(foreach e,d o,$(PHP_LNAME).$e) php/php_pmc.h
DISTCLEAN+=$(PHP_LNAME).so $(PHP_LNAME).php php/php.ini
else # SWIG 3.0.12
NO_PHP=1
endif
else # PHP 7
NO_PHP=1
endif
else # which php-config
NO_PHP=1
endif
endif # NO_PHP

ALL+=$(SWIG_ALL)
else # swig 3.0
NO_SWIG=1
endif
else  # which swig
NO_SWIG=1
endif
endif # NO_SWIG

ifneq ($(call which,doxygen),)
ifeq ($(call verCheck,$(shell doxygen -v),1.8),)
doxygen: $(HEADERS_ALL)
	$(Q_DOXY)
	$(Q)doxygen doxygen.cfg 2>&1 >/dev/null
DISTCLEAN_DIRS+=doc
endif
endif # which doxygen

ifneq ($(call which,ctags),)
tags: $(filter-out $(wildcard ids*.h),$(wildcard *.h *.cpp))
	$(Q_TAGS)
	$(Q)ctags -R $^
ALL+=tags
DISTCLEAN+=tags
endif # which ctags

all: $(ALL)
	@:
.DEFAULT_GOAL=all

####### Debain build #######
ifneq ($(and $(wildcard debian/rules),$(call which,dpkg-buildpackage)),)
deb_src: distclean
	$(Q)dpkg-source -b .
deb:
	$(Q)MAKEFLAGS=$(MAKE_NO_DIRS) Q=$Q dpkg-buildpackage -b -us -uc
	$Q$(RM) $(PMC_NAME) $(LIB_NAME_SO) $(PERL_NAME).so $(wildcard */*/*.so)
deb_clean:
	$Q$(MAKE) $(MAKE_NO_DIRS) -f debian/rules deb_clean Q=$Q
endif # and wildcard debian/rules, which dpkg-buildpackage

SRC_FILES:=$(HEADERS) $(wildcard *.c* *.i */test.* scripts/* *.sh *.pl *.md)\
  LICENSE $(wordlist 1,2,$(MAKEFILE_LIST))
SRC_NAME:=libpmc-$(LIB_VER)
####### rpm build #######
RPM_SRC:=rpm/SOURCES/$(SRC_NAME).txz
$(RPM_SRC): $(SRC_FILES)
	$Q$(MD) rpm/SOURCES
	$Q$(TAR) $@ $^ --transform "s#^#$(SRC_NAME)/#S"
ifneq ($(call which,rpmbuild),)
rpm: $(RPM_SRC)
	$(Q)rpmbuild --define "_topdir $(PWD)/rpm" -bb rpm/libpmc.spec
endif # which rpmbuild
rpmsrc: $(RPM_SRC)
DISTCLEAN_DIRS+=$(wildcard rpm/[BRS]*)

####### archlinux build #######
ARCHL_SRC:=archlinux/$(SRC_NAME).txz
ARCHL_BLD:=archlinux/PKGBUILD
$(ARCHL_SRC): $(SRC_FILES)
	$Q$(TAR) $@ $^
$(ARCHL_BLD): $(ARCHL_BLD).org | $(ARCHL_SRC)
	$(Q)cp $^ $@
	$(Q)printf "md5sums=('%s')" $(firstword $(shell md5sum $(ARCHL_SRC))) >> $@
ifneq ($(call which,makepkg),)
pkg: $(ARCHL_BLD)
	$(Q)cd archlinux && makepkg
endif # which makepkg
pkgsrc: $(ARCHL_BLD)
DISTCLEAN+=$(ARCHL_SRC) $(ARCHL_BLD) $(wildcard archlinux/*.pkg.tar.zst)
DISTCLEAN_DIRS+=archlinux/src archlinux/pkg

####### installation #######
URL:=html/index.html
REDIR:="<meta http-equiv=\"refresh\" charset=\"utf-8\" content=\"0; url=$(URL)\"/>"
INSTALL?=install -p
NINST:=$(INSTALL) -m 644
DINST:=$(INSTALL) -d
BINST:=$(INSTALL)
ifneq ($(TARGET_ARCH),)
LIBDIR?=/usr/lib/$(TARGET_ARCH)
else
LIBDIR?=/usr/lib
endif
DEV_PKG?=libpmc-dev
SBINDIR?=/usr/sbin
LUADIR:=$(DESTDIR)$(LIBDIR)
DOCDIR:=$(DESTDIR)/usr/share/doc/libpmc-doc
MANDIR:=$(DESTDIR)/usr/share/man/man8
PY3_VER:=$(subst .,,$(subst libpython,,$(basename \
  $(notdir $(wildcard $(LIBDIR)/libpython3.*.so)))))
ifndef PY2_ARCH
ifneq ($(TARGET_ARCH),)
PY2_ARCH:=.$(TARGET_ARCH)
endif
endif # PY2_ARCH
ifndef PY3_ARCH
ifneq ($(TARGET_ARCH),)
PY3_ARCH:=$(TARGET_ARCH)
else
PY3_ARCH:=$(shell uname -m)-linux-gnu
endif
endif # PY3_ARCH

install: $(ALL) doxygen
ifdef SONAME_USE_MAJ
	$Q$(NINST) -D $(LIB_NAME_SO) $(DESTDIR)$(LIBDIR)/$(LIB_FNAME_SO)
	$Q$(LN) $(LIB_FNAME_SO) $(DESTDIR)$(LIBDIR)/$(LIB_SNAME_SO)
	$Q$(LN) $(LIB_SNAME_SO) $(DESTDIR)$(LIBDIR)/$(LIB_NAME_SO)
else
	$Q$(NINST) -D $(LIB_NAME_SO) $(DESTDIR)$(LIBDIR)/$(LIB_NAME_SO)
endif
	$Q$(NINST) libpmc.a $(DESTDIR)$(LIBDIR)
	$Q$(NINST) -D $(HEADERS) -t $(DESTDIR)/usr/include/pmc
	$Q$(foreach f,$(HEADERS),$(SED) -i\
	  's!#include\s*\"\([^"]\+\)\"!#include <pmc/\1>!'\
	  $(DESTDIR)/usr/include/pmc/$f;)
	$Q$(NINST) -D scripts/*.mk -t $(DESTDIR)/usr/share/$(DEV_PKG)
	$Q$(BINST) -D pmc $(DESTDIR)$(SBINDIR)/pmc.lib
	$Q$(DINST) $(MANDIR)
	$(Q)ln -fs pmc.8.gz $(MANDIR)/pmc.lib.8.gz
	$Q$(RM) doc/html/*.md5
	$Q$(DINST) $(DOCDIR)
	$(Q)cp -a doc/html $(DOCDIR)
	$(Q)printf $(REDIR) > $(DOCDIR)/index.html
ifndef NO_SWIG
ifndef NO_PERL
	$Q$(NINST) -D perl/$(SWIG_NAME).so -t $(PERLDIR)/auto/$(SWIG_NAME)
	$Q$(NINST) perl/$(SWIG_NAME).pm $(PERLDIR)
endif # NO_PERL
ifndef NO_LUA
	$Q$(foreach n,$(LUA_VERSIONS),\
	  $(NINST) -D $(LUA_LIB_$n) $(LUADIR)/$(LUA_FLIB_$n).$(LIB_VER);\
	  $(LN) $(LUA_FLIB_$n).$(LIB_VER) $(LUADIR)/$(LUA_FLIB_$n)$(SONAME);\
	  $(DINST) $(LUADIR)/lua/$n;\
	  $(LN) ../../$(LUA_FLIB_$n).$(LIB_VER) $(LUADIR)/lua/$n/$(LUA_LIB_NAME);)
ifdef LUA_VER
	$Q$(NINST) -D $(LUA_LIB) $(LUADIR)/$(LUA_FLIB)
	$Q$(DINST) $(LUADIR)/lua/$(LUA_VER)
	$Q$(LN) ../../$(LUA_FLIB) $(LUADIR)/lua/$(LUA_VER)/$(LUA_LIB_NAME)
endif # LUA_VER
endif # NO_LUA
ifndef NO_PYTHON
ifdef PY2_DIR
	$Q$(NINST) -D python/2/$(PY_LIB_NAME).so\
	  $(PY2_DIR)/$(PY_LIB_NAME)$(PY2_ARCH).so
	$Q$(NINST) python/pmc.py $(PY2_DIR)
endif
ifdef PY3_DIR
	$Q$(NINST) -D python/3/$(PY_LIB_NAME).so\
	  $(PY3_DIR)/$(PY_LIB_NAME).cpython-$(PY3_VER)-$(PY3_ARCH).so
	$Q$(NINST) python/pmc.py $(PY3_DIR)
endif
endif # NO_PYTHON
ifndef NO_RUBY
	$Q$(NINST) -D $(RUBY_LNAME).so -t $(RUBYDIR)
endif # NO_RUBY
ifndef NO_PHP
	$Q$(NINST) -D $(PHP_LNAME).so -t $(PHPEDIR)
	$Q$(NINST) -D $(PHP_LNAME).php -t $(PHPIDIR)
endif # NO_PHP
endif # NO_SWIG

checkall: format doxygen

help:
	$(info $(help))
	@:

.PHONY: all clean distclean format install deb_src deb deb_clean doxygen\
        checkall help rpm rpmsrc pkg pkgsrc
