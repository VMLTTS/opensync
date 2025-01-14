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
export FUT_NM2_LIB_SRC=true
[ "${FUT_UNIT_LIB_SRC}" != true ] && source "${FUT_TOPDIR}/shell/lib/unit_lib.sh"
echo "${FUT_TOPDIR}/shell/lib/nm2_lib.sh sourced"

####################### INFORMATION SECTION - START ###########################
#
#   Base library of common Network Manager functions
#
####################### INFORMATION SECTION - STOP ############################

####################### SETUP SECTION - START #################################

###############################################################################
# DESCRIPTION:
#   Function prepares device for NM tests.
#   Steps:
#       - Initialize device (stop watchdog, stop healthcheck and all managers)
#       - Start OVS (Open vSwitch)
#       - Start wireless driver
#       - Start specific manager: WM
#       - Wait for radio interfaces to appear in Wifi_Radio_State
#       - Start specific manager: NM
#       - Empty AW_Debug table
#       - Set log severity for WM to TRACE
#       - Set log severity for NM to TRACE
#   Raises an exception if any of the steps fails.
# INPUT PARAMETER(S):
# RETURNS:
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   nm_setup_test_environment <interface name>
###############################################################################
nm_setup_test_environment()
{
    fn_name="nm2_lib:nm_setup_test_environment"

    log "$fn_name - Running NM2 setup"

    device_init &&
        log -deb "$fn_name - Device initialized - Success" ||
        raise "FAIL: Could not initialize device: device_init" -l "$fn_name" -ds

    start_openswitch &&
        log -deb "$fn_name - OpenvSwitch started - Success" ||
        raise "FAIL: Could not start OpenvSwitch: start_openswitch" -l "$fn_name" -ds

    start_wireless_driver &&
        log -deb "$fn_name - Wireless driver started - Success" ||
        raise "FAIL: Could not start wireles driver: start_wireless_driver" -l "$fn_name" -ds

    start_specific_manager wm &&
        log -deb "$fn_name - start_specific_manager wm - Success" ||
        raise "FAIL: Could not start manager: start_specific_manager wm" -l "$fn_name" -ds

    # Check if all radio interfaces are created
    for if_name in "$@"
    do
        wait_ovsdb_entry Wifi_Radio_State -w if_name "$if_name" -is if_name "$if_name" &&
            log -deb "$fn_name - Wifi_Radio_State::if_name '$if_name' present - Success" ||
            raise "FAIL: Wifi_Radio_State::if_name for $if_name does not exist" -l "$fn_name" -ds
    done

    start_specific_manager nm &&
        log -deb "$fn_name - start_specific_manager nm - Success" ||
        raise "FAIL: Could not start manager: start_specific_manager nm" -l "$fn_name" -ds

    empty_ovsdb_table AW_Debug  &&
        log -deb "$fn_name - AW_Debug table emptied - Success" ||
        raise "FAIL: Could not empty table: empty_ovsdb_table AW_Debug" -l "$fn_name" -ds

    set_manager_log WM TRACE &&
        log -deb "$fn_name - Manager log for WM set to TRACE - Success" ||
        raise "FAIL: Could not set manager log severity: set_manager_log WM TRACE" -l "$fn_name" -ds

    set_manager_log NM TRACE &&
        log -deb "$fn_name - Manager log for NM set to TRACE - Success" ||
        raise "FAIL: Could not set manager log severity: set_manager_log NM TRACE" -l "$fn_name" -ds

    log "$fn_name - NM2 setup - end"

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function creates entry to Wifi_Inet_Config table.
#   It then waits for config to reflect in Wifi_Inet_State table.
#   Raises exception on fail.
# INPUT PARAMETER(S):
#   See fields in table Wifi_Inet_Config.
#   Mandatory parameter: if_name
# RETURNS:
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   create_inet_entry -if_name "br-wan" -if_type "vif"
#   create_inet_entry -if_name "eth1" -if_type "eth" -enabled "true"
###############################################################################
create_inet_entry()
{
    fn_name="nm2_lib:create_inet_entry"
    args=""
    add_cfg_args=""
    replace="func_arg"

    # Parse parameters
    while [ -n "$1" ]; do
        option=${1}
        shift
        case "${option}" in
            -if_name)
                nm2_if_name="${1}"
                args="${args} ${replace} ${option#?} ${1}"
                shift
                ;;
            -enabled | \
            -network | \
            -if_type | \
            -inet_addr | \
            -bridge | \
            -dns | \
            -gateway | \
            -broadcast | \
            -ip_assign_scheme | \
            -mtu | \
            -NAT | \
            -upnp_mode | \
            -dhcpd | \
            -vlan_id | \
            -parent_ifname | \
            -gre_ifname | \
            -gre_remote_inet_addr | \
            -gre_local_inet_addr)
                args="${args} ${replace} ${option#?} ${1}"
                shift
                ;;
            -dhcp_sniff)
                add_cfg_args="${add_cfg_args} ${replace} ${option#?} ${1}"
                shift
                ;;
            -broadcast_n)
                broadcast_n="${1}"
                shift
                ;;
            -inet_addr_n)
                inet_addr_n="${1}"
                shift
                ;;
            -subnet)
                subnet="${1}"
                shift
                ;;
            -netmask)
                netmask="${1}"
                args="${args} ${replace} ${option#?} ${1}"
                shift
                ;;
            *)
                raise "FAIL: Wrong option provided: $option" -l "$fn_name" -arg
                ;;
        esac
    done

    # Make sure if_name parameter is given
    [ -z "${nm2_if_name}" ] &&
        raise "FAIL: Interface name argument empty" -l "${fn_name}" -arg

    if [ -n "${broadcast_n}" ] && [ -n "${inet_addr_n}" ] && [ -n "${netmask}" ] && [ -n "${subnet}" ]; then
        log -deb "$fn_name - Setting additional parameters from partial info: broadcast, dhcpd_start, dhcpd_stop, inet_addr"
        broadcast="${subnet}.${broadcast_n}"
        dhcpd_start="${subnet}.$((inet_addr_n + 1))"
        dhcpd_stop="${subnet}.$((broadcast_n - 1))"
        inet_addr="${subnet}.${inet_addr_n}"
        dhcpd='["map",[["dhcp_option","26,1600"],["force","false"],["lease_time","12h"],["start","'${dhcpd_start}'"],["stop","'${dhcpd_stop}'"]]]'
        args="${args} ${replace} broadcast ${broadcast}"
        args="${args} ${replace} inet_addr ${inet_addr}"
        args="${args} ${replace} dhcpd ${dhcpd}"
    fi

    # Check if entry for given interface already exists, and if exists perform update action instead of insert
    check_ovsdb_entry Wifi_Inet_Config -w if_name "${nm2_if_name}"
    if [ $? -eq 0 ]; then
        log -deb "$fn_name - Updating existing Inet interface"
        function_to_call="update_ovsdb_entry"
        function_arg="-u"
    else
        log -deb "$fn_name - Creating Inet interface"
        function_to_call="insert_ovsdb_entry"
        function_arg="-i"
    fi

    # Perform action insert/update
    func_params=${args//$replace/$function_arg}
    func_params_add=${add_cfg_args//$replace/$function_arg}
    # shellcheck disable=SC2086
    $function_to_call Wifi_Inet_Config -w if_name "$nm2_if_name" $func_params $func_params_add &&
        log -deb "$fn_name - Success $function_to_call Wifi_Inet_Config -w if_name $nm2_if_name $func_params $func_params_add" ||
        raise "FAIL: $function_to_call Wifi_Inet_Config -w if_name $nm2_if_name $func_params $func_params_add" -l "$fn_name" -oe

    # Validate action insert/update
    func_params=${args//$replace/-is}
    # shellcheck disable=SC2086
    wait_ovsdb_entry Wifi_Inet_State -w if_name "$nm2_if_name" $func_params &&
        log -deb "$fn_name - Success wait_ovsdb_entry Wifi_Inet_State -w if_name $nm2_if_name $func_params" ||
        raise "FAIL: wait_ovsdb_entry Wifi_Inet_State -w if_name $nm2_if_name $func_params" -l "$fn_name" -ow

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function sets entry values for interface in Wifi_Inet_Config
#   table to default.
#   Raises exception on fail.
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   None.
# USAGE EXAMPLE(S):
#   reset_inet_entry eth0
#   reset_inet_entry wifi0
###############################################################################
reset_inet_entry()
{
    fn_name="nm2_lib:reset_inet_entry"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    nm2_if_name=$1

    log -deb "$fn_name - Setting Wifi_Inet_Config for $nm2_if_name to default values"
    update_ovsdb_entry Wifi_Inet_Config -w if_name "$nm2_if_name" \
        -u NAT "false" \
        -u broadcast "[\"set\",[]]" \
        -u dhcpd "[\"map\",[]]" \
        -u dns "[\"map\",[]]" \
        -u enabled "true" \
        -u gateway "[\"set\",[]]" \
        -u gre_ifname "[\"set\",[]]" \
        -u gre_local_inet_addr "[\"set\",[]]" \
        -u gre_remote_inet_addr "[\"set\",[]]" \
        -u inet_addr "[\"set\",[]]" \
        -u ip_assign_scheme "none" \
        -u mtu "[\"set\",[]]" \
        -u netmask "[\"set\",[]]" \
        -u network "true" \
        -u parent_ifname "[\"set\",[]]" \
        -u softwds_mac_addr "[\"set\",[]]" \
        -u softwds_wrap "[\"set\",[]]" \
        -u upnp_mode "[\"set\",[]]" \
        -u vlan_id "[\"set\",[]]" &&
            log -deb "$fn_name - Wifi_Inet_Config updated" ||
            raise "FAIL: Could not update Wifi_Inet_Config" -l "$fn_name" -oe

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function deletes entry values in Wifi_Inet_Config table.
#   It then waits for config to reflect in Wifi_Inet_State table.
#   It checks if configuration is reflected in system.
#   Raises exception if interface is not removed and then forces deletion.
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   None.
# USAGE EXAMPLE(S):
#   delete_inet_interface eth0
###############################################################################
delete_inet_interface()
{
    fn_name="nm2_lib:delete_inet_interface"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    nm2_if_name=$1

    log -deb "$fn_name - Removing interface '$nm2_if_name'"

    remove_ovsdb_entry Wifi_Inet_Config -w if_name "$nm2_if_name" ||
        raise "FAIL: Could not remove Wifi_Inet_Config::if_name" -l "$fn_name" -oe

    wait_ovsdb_entry_remove Wifi_Inet_State -w if_name "$nm2_if_name" ||
        raise "FAIL: Could not remove Wifi_Inet_State::if_name" -l "$fn_name" -ow

    wait_for_function_response 1 "ip link show $nm2_if_name" &&
        log "$fn_name - LEVEL2: Interface $nm2_if_name removed" ||
        interface_force_purge_die "$nm2_if_name"

    log -deb "$fn_name - Interface '$nm2_if_name' deleted"

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function deletes interface from system by force.
#   Raises exception if interface is not removed.
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   None.
#   See DESCRIPTION
# USAGE EXAMPLE(S):
#   interface_force_purge_die eth0
###############################################################################
interface_force_purge_die()
{
    fn_name="nm2_lib:interface_force_purge_die"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    nm2_if_name=$1

    log -deb "$fn_name - Interface force removal"
    ip link delete "$nm2_if_name" || true

    wait_for_function_response 1 "ip link show $nm2_if_name" &&
        raise "FAIL: Interface $nm2_if_name removed forcefully" -l "$fn_name" -tc ||
        raise "FAIL: Interface still present, could not delete interface $nm2_if_name" -l "$fn_name" -tc
}

###############################################################################
# DESCRIPTION:
#   Function enables or disables DHCP server on interface.
#   It waits for config to reflect in Wifi_Inet_State.
#   Raises exception if DHCP server is not configured.
# INPUT PARAMETER(S):
#   $1  interface name (required)
#   $2  IP address start pool (optional)
#   $3  IP address end pool (optional)
# RETURNS:
#   None.
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   configure_dhcp_server_on_interface eth1 10.10.10.20 10.10.10.50
#   configure_dhcp_server_on_interface eth1
###############################################################################
configure_dhcp_server_on_interface()
{
    fn_name="nm2_lib:configure_dhcp_server_on_interface"
    NARGS_MIN=1
    NARGS_MAX=3
    [ $# -eq ${NARGS_MIN} ] || [ $# -eq ${NARGS_MAX} ] ||
        raise "${fn_name} requires ${NARGS_MIN} or ${NARGS_MAX} input arguments, $# given" -arg
    nm2_if_name=$1
    nm2_start_pool=$2
    nm2_end_pool=$3

    if [ -z "$nm2_start_pool" ] && [ -z "$nm2_end_pool" ]; then
        # One or both arguments are missing.
        nm2_dhcpd=''
    else
        nm2_dhcpd='["start","'$nm2_start_pool'"],["stop","'$nm2_end_pool'"]'
    fi

    log -deb "$fn_name - Configuring DHCP server on $nm2_if_name"

    update_ovsdb_entry Wifi_Inet_Config -w if_name "$nm2_if_name" \
        -u enabled true \
        -u network true \
        -u dhcpd '["map",['$nm2_dhcpd']]' ||
            raise "FAIL: Could not update Wifi_Inet_Config" -l "$fn_name" -oe

    wait_ovsdb_entry Wifi_Inet_State -w if_name "$nm2_if_name" \
        -is enabled true \
        -is network true \
        -is dhcpd '["map",['$nm2_dhcpd']]' ||
            raise "FAIL: Wifi_Inet_State not reflected to Wifi_Inet_State" -l "$fn_name" -ow

    log -deb "$fn_name - DHCP server created on $nm2_if_name"

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function populates DNS settings for given interface to Wifi_Inet_Config.
#   It waits for config to reflect in Wifi_Inet_State.
#   Raises an exception on fail.
# INPUT PARAMETER(S):
#   $1  interface name (required)
#   $2  primary DNS IP (optional)
#   $3  secondary DNS IP (optional)
# RETURNS:
#   None.
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   configure_custom_dns_on_interface eth0 16.17.18.19 20.21.22.23
#   configure_custom_dns_on_interface eth0
###############################################################################
configure_custom_dns_on_interface()
{
    fn_name="nm2_lib:configure_custom_dns_on_interface"
    NARGS_MIN=1
    NARGS_MAX=3
    [ $# -eq ${NARGS_MIN} ] || [ $# -eq ${NARGS_MAX} ] ||
        raise "${fn_name} requires ${NARGS_MIN} or ${NARGS_MAX} input arguments, $# given" -arg
    nm2_if_name=$1
    nm2_primary_dns=$2
    nm2_secondary_dns=$3

    nm2_dns='["map",[["primary","'$nm2_primary_dns'"],["secondary","'$nm2_secondary_dns'"]]]'
    if [ -z "$nm2_primary_dns" ] && [ -z "$nm2_secondary_dns" ]; then
        nm2_dns=''
    fi

    log -deb "$fn_name - Creating DNS on $nm2_if_name"

    update_ovsdb_entry Wifi_Inet_Config -w if_name "$nm2_if_name" \
        -u enabled true \
        -u network true \
        -u ip_assign_scheme static \
        -u dns $nm2_dns ||
            raise "FAIL: Could not update Wifi_Inet_Config" -l "$fn_name" -oe

    wait_ovsdb_entry Wifi_Inet_State -w if_name "$nm2_if_name" \
        -is enabled true \
        -is network true \
        -is dns $nm2_dns ||
            raise "FAIL: Wifi_Inet_State not reflected to Wifi_Inet_State" -l "$fn_name" -ow

    log -deb "$fn_name - DNS created on $nm2_if_name"

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function sets port forwarding for interface.
#   Raises exception if port forwarding is not set.
# INPUT PARAMETER(S):
#   $1  source interface name (required)
#   $2  source port (required)
#   $3  destination IP address (required)
#   $4  destination port (required)
#   $5  protocol (required)
# RETURNS:
#   None.
#   See DESCRIPTION
# USAGE EXAMPLE(S):
#   set_ip_forward bhaul-sta-24 8080 10.10.10.123 80 tcp
###############################################################################
set_ip_forward()
{
    fn_name="nm2_lib:set_ip_forward"
    local NARGS=5
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    nm2_src_ifname=$1
    nm2_src_port=$2
    nm2_dst_ipaddr=$3
    nm2_dst_port=$4
    nm2_protocol=$5

    log -deb "$fn_name - Creating port forward on $nm2_src_ifname"

    insert_ovsdb_entry IP_Port_Forward \
        -i dst_ipaddr "$nm2_dst_ipaddr" \
        -i dst_port "$nm2_dst_port" \
        -i src_port "$nm2_src_port" \
        -i protocol "$nm2_protocol" \
        -i src_ifname "$nm2_src_ifname" ||
            raise "FAIL: Could not insert to IP_Port_Forward" -l "$fn_name" -oe

    log -deb "$fn_name - Port forward created on $nm2_src_ifname"

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function deletes port forwarding on interface by force.
#   Uses iptables tool.
#   Raises exception if port forwarding is not deleted.
# INPUT PARAMETER(S):
#   $1  interface name (required)
#   $2  table type in iptables list (string) (required)
#   $3  port and IP (required)
# RETURNS:
#   None.
#   See DESCRIPTION.
# USAGE EXAMPLE(S):
#   force_delete_ip_port_forward_die bhaul-sta-24 <tabletype> 10.10.10.123:80
###############################################################################
force_delete_ip_port_forward_die()
{
    fn_name="nm2_lib:force_delete_ip_port_forward_die"
    local NARGS=3
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    nm2_if_name=$1
    nm2_ip_table_type=$2
    nm2_ip_port_forward_ip=$3

    log -deb "$fn_name - iptables not empty. Force delete"

    nm2_port_forward_line_number=$(iptables -t nat --list -v --line-number | tr -s ' ' | grep "$nm2_ip_table_type" | grep "$nm2_if_name" | grep  "$nm2_ip_port_forward_ip" | cut -d ' ' -f1)
    if [ -z "$nm2_port_forward_line_number" ]; then
        log -deb "$fn_name - Could not get iptables line number, skipping..."
        return 0
    fi

    wait_for_function_response 0 "iptables -t nat -D $nm2_ip_table_type $nm2_port_forward_line_number" &&
        raise "FAIL: IP port forward forcefully removed from iptables" -l "$fn_name" -tc ||
        raise "FAIL: Could not to remove IP port forward from iptables" -l "$fn_name" -tc
}

###############################################################################
# DESCRIPTION:
# INPUT PARAMETER(S):
# RETURNS:
# USAGE EXAMPLE(S):
#   N/A
###############################################################################
check_upnp_configuration_valid()
{
    fn_name="nm2_lib:check_upnp_configuration_valid"
    local NARGS=2
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    nm2_internal_if=$1
    nm2_external_if=$2

    log "$fn_name - LEVEL2 - Checking if '$nm2_internal_if' set as internal interface"
    $(cat /var/miniupnpd/miniupnpd.conf | grep -q "listening_ip=$nm2_internal_if")
    if [ "$?" -eq 0 ]; then
        log -deb "$fn_name - UPnP configuration VALID for internal interface"
    else
        raise "FAIL: UPnP configuration not valid for internal interface" -l "$fn_name" -tc
    fi

    log -deb "$fn_name - LEVEL2 - Checking if '$nm2_external_if' set as external interface"
    $(cat /var/miniupnpd/miniupnpd.conf | grep -q "ext_ifname=$nm2_external_if")
    if [ "$?" -eq 0 ]; then
        log -deb "$fn_name - UPnP configuration valid for external interface"
    else
        raise "FAIL: UPnP configuration not valid for external interface" -l "$fn_name" -tc
    fi

    return 0
}

###############################################################################
# DESCRIPTION:
#   Function checks if NAT is enabled for interface at system level.
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   None.
# USAGE EXAMPLE(S):
#   check_interface_nat_enabled eth0
###############################################################################
check_interface_nat_enabled()
{
    fn_name="nm2_lib:check_interface_nat_enabled"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    if_name=$1

    iptables -t nat --list -v  | tr -s ' ' / | grep '/MASQUERADE/' | grep -q "$if_name"
    if [ $? -eq 0 ]; then
        log -deb "${fn_name} - interface ${if_name} NAT enabled"
        return 0
    else
        log -deb "${fn_name} - interface ${if_name} NAT disabled"
        return 1
    fi
}

###############################################################################
# DESCRIPTION:
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   None.
# USAGE EXAMPLE(S):
#   ip_port_forward eth0
###############################################################################
ip_port_forward()
{
    fn_name="nm2_lib:ip_port_forward"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    if_name=$1

    iptables -t nat --list -v  | tr -s ' ' / | grep '/DNAT/' | grep -q "$if_name"
    if [ $? -eq 0 ]; then
        log -deb "${fn_name} - IP port forward set for ${if_name}"
        return 0
    else
        log -deb "${fn_name} - IP port forward not set for ${if_name}"
        return 1
    fi
}

###############################################################################
# DESCRIPTION:
#   Function returns broadcast address for interface at system level.
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   Broadcast address of interface.
# USAGE EXAMPLE(S):
#   get_interface_broadcast_from_system eth0
###############################################################################
get_interface_broadcast_from_system()
{
    fn_name="nm2_lib:get_interface_broadcast_from_system"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    if_name=$1

    ifconfig "$if_name" | tr -s ' :' '@' | grep -e '^@inet@' | cut -d '@' -f 6
    if [ $? -eq 0 ]; then
        log -deb "${fn_name} - Broadcast set for ${if_name}"
        return 0
    else
        log -deb "${fn_name} - Broadcast not set for ${if_name}"
        return 1
    fi
}

###############################################################################
# DESCRIPTION:
#   Function returns netmask for interface at system level.
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   Netmask of interface.
# USAGE EXAMPLE(S):
#   get_interface_netmask_from_system eth0
###############################################################################
get_interface_netmask_from_system()
{
    fn_name="nm2_lib:get_interface_netmask_from_system"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    if_name=$1

    ifconfig "$if_name" | tr -s ' :' '@' | grep -e '^@inet@' | cut -d '@' -f 8
    if [ $? -eq 0 ]; then
        log -deb "${fn_name} - Netmask set for ${if_name}"
        return 0
    else
        log -deb "${fn_name} - Netmask not set for ${if_name}"
        return 1
    fi
}

###############################################################################
# DESCRIPTION:
#   Function returns MTU for interface at system level.
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   MTU of interface.
# USAGE EXAMPLE(S):
#   get_interface_mtu_from_system eth0
###############################################################################
get_interface_mtu_from_system()
{
    fn_name="nm2_lib:get_interface_mtu_from_system"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    if_name=$1

    ifconfig "$if_name" | tr -s ' ' | grep "MTU" | cut -d ":" -f2 | awk '{print $1}'
    if [ $? -eq 0 ]; then
        log -deb "${fn_name} - MTU set for ${if_name}"
        return 0
    else
        log -deb "${fn_name} - MTU not set for ${if_name}"
        return 1
    fi
}

###############################################################################
# DESCRIPTION:
# INPUT PARAMETER(S):
#   $1  interface name (required)
#   $2  start pool (required)
#   $3  end pool (required)
# RETURNS:
#   Exit status of last function.
# USAGE EXAMPLE(S):
#   check_dhcp_from_dnsmasq_conf wifi0 10.10.10.16 10.10.10.32
###############################################################################
check_dhcp_from_dnsmasq_conf()
{
    fn_name="nm2_lib:check_dhcp_from_dnsmasq_conf"
    local NARGS=3
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    if_name=$1
    start_pool=$2
    end_pool=$3

    $(grep -q "dhcp-range=$if_name,$start_pool,$end_pool" /var/etc/dnsmasq.conf) &&
        return 0 ||
        return 1
}

###############################################################################
# DESCRIPTION:
# INPUT PARAMETER(S):
#   $1  primary DNS IP (required)
# RETURNS:
#   Exit status of last function.
# USAGE EXAMPLE(S):
#   check_resolv_conf 1.2.3.4
###############################################################################
check_resolv_conf()
{
    fn_name="nm2_lib:check_resolv_conf"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    nm2_primary_dns=$1

    $(cat /tmp/resolv.conf | grep -q "nameserver $nm2_primary_dns") &&
        return 0 ||
        return 1
}

###############################################################################
# DESCRIPTION:
#   Function checks if interface exists on system.
# INPUT PARAMETER(S):
#   $1  interface name (required)
# RETURNS:
#   0   Interface exists.
#   1   Interface does not exists.
# USAGE EXAMPLE(S):
#   check_interface_exists test1
###############################################################################
check_interface_exists()
{
    fn_name="nm2_lib:check_interface_exists"
    local NARGS=1
    [ $# -ne ${NARGS} ] &&
        raise "${fn_name} requires ${NARGS} input argument(s), $# given" -arg
    local if_name=$1

    log -deb "${fn_name} - Checking if interface ${if_name} exists on system"

    ifconfig | grep -qwE "$if_name"
    if [ "$?" -eq 0 ]; then
        log -deb "${fn_name} - interface ${if_name} exists on system"
        return 0
    else
        log -deb "${fn_name} - interface ${if_name} does NOT exist on system"
        return 1
    fi
}
