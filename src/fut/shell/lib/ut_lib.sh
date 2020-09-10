#!/bin/sh

# Copyright (c) 2015, Plume Design Inc. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#    2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#    3. Neither the name of the Plume Design Inc. nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL Plume Design Inc. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# Include basic environment config
if [ -e "/tmp/fut_set_env.sh" ]; then
    source /tmp/fut_set_env.sh
else
    source ${FUT_TOPDIR}/shell/config/default_shell.sh
fi
source ${FUT_TOPDIR}/shell/lib/cm2_lib.sh
source ${LIB_OVERRIDE_FILE}

############################################ INFORMATION SECTION - START ###############################################
#
#   Base library of common Upgrade Manager functions (Plume specific)
#
############################################ INFORMATION SECTION - STOP ################################################


############################################ SETUP SECTION - START #####################################################

ut_setup_test_environment()
{
    log -deb "UT SETUP"

    stop_healthcheck ||
        die "lib/um_lib: ut_setup_test_environment - Failed stop_healthcheck"

    cm_disable_fatal_state ||
        die "lib/cm2_lib: ut_setup_test_environment - Failed: cm_disable_fatal_state"

    # Ignoring failures
    /etc/init.d/manager restart || true
}

############################################ SETUP SECTION - STOP ######################################################