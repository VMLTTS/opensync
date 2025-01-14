#!/bin/sh -axe

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


## DESCRIPTION ##
# This is a series of tests validating DPP based
# onboarding logic. They cover:
#  * different akm handouts
#  * falling back to legacy onboarding
## /DESCRIPTION ##

## PARAMETERS ##
# shell ssh access command, eg. ssh user@host sh -axe
test -n "$dut"
test -n "$dut_phy"
test -n "$dut_vif_ap0"
test -n "$dut_vif_sta"
test -n "$dut_vif_ap0_idx"
test -n "$dut_vif_sta_idx"
test -n "$dut_mac_ap0"
# shell ssh access command, eg. ssh user@host sh -axe
test -n "$ref"
test -n "$ref_phy"
test -n "$ref_vif_sta"
test -n "$ref_vif_sta_idx"
test -n "$ref_mac_sta"
ssid=${ssid:-"test-ssid"}
psk=${psk:-"12345678"}
confhex=${confhex:-"307702010104202d8961acd594a13ce84028f97e5c0d652f784d70b5d6fe216ef06b5aa9ad2132a00a06082a8648ce3d030107a144034200048467341d13849741f9fdb2ce7b843ee72bb8ee284c696a228e00fec9b6ea37c48ca5fe2f021ee73081078a6805477430442c14efb85ae24461cfc3aaafcd6ee2"}
urikeyhex=${urikeyhex:-"30770201010420835bb02c1319ed97efff01a3db2c8da14603becd7b4c08d7423beecb4657f2cea00a06082a8648ce3d030107a144034200041555426691efc4b17688f739cdaa23663a73e875e78aae0e479f8d0e4b4e6b6f01aba682ce0997c0e9242515cb6b4326daa5caccfcd5a629e6641c1c0b1bfa3e"}
urikeypk=${urikeypk:-"95a7c4aa285f8fb0dff4c7de0cb6c7d1a00f9a2300f5a2954c9e8ec591001dbc"}
urikeychirp=${urikeychirp:-"479af679f6e9e14926d0b357be084d3348ff54c23b8d9c28ba75905491c152dc"}
uri=${uri:-"DPP:${dppchan}V:2;K:MDkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDIgACFVVCZpHvxLF2iPc5zaojZjpz6HXniq4OR5+NDktOa28=;;"}
dppconn=${dppconn:-"eyJ0eXAiOiJkcHBDb24iLCJraWQiOiJfNURkaUZVZ3dYZXJWTlktaHlDY2hqZmg3Si1nakN0R0RVZE9PMm1na1lZIiwiYWxnIjoiRVMyNTYifQ.eyJncm91cHMiOlt7Imdyb3VwSWQiOiIqIiwibmV0Um9sZSI6ImFwIn1dLCJuZXRBY2Nlc3NLZXkiOnsia3R5IjoiRUMiLCJjcnYiOiJQLTI1NiIsIngiOiJzOEZOTVJDVi02QWhWTDV6RVRIMlloeklreHUyRFdpelFVWXdnandCMHJjIiwieSI6InBDT0ZvMjllZ3lnSmZNMzBESlFqa3lLMUF2UFdBUGtQLUlvQ284Q3cwaGMifX0._VVcNqEE-GONeAmqrtc-7jsVrVHSZprlLklMJBFb6R7-SOXtleqryCQxQbQkLWZ9sL8qeZvnA2z1NIHQmio5jw"}
dppcsign=${dppcsign:-"3059301306072a8648ce3d020106082a8648ce3d030107034200048467341d13849741f9fdb2ce7b843ee72bb8ee284c696a228e00fec9b6ea37c48ca5fe2f021ee73081078a6805477430442c14efb85ae24461cfc3aaafcd6ee2"}
dppnet=${dppnet:-"3077020101042001444f5f096619c8ba3a47e7d5bfbe237def3908cc278d6b42f65de49d04513ba00a06082a8648ce3d030107a14403420004b3c14d311095fba02154be731131f6621cc8931bb60d68b3414630823c01d2b7a42385a36f5e8328097ccdf40c94239322b502f3d600f90ff88a02a3c0b0d217"}
## /PARAMETERS ##

self=$0
tohex() { od -tx1 -An | tr -d ' \n'; }

setchan() {
	chan=$1
	dppchan="C:81/$chan;"
}

ssidhex=$(echo -n $ssid | tohex)
pskhex=$(echo -n $psk | tohex)

onboard() {
	case "$1" in
	psk) mgmt=psk ;;
	sae) mgmt=sae ;;
	dpp) mgmt=dpp ;;
	dpp-psk-sae) mgmt=dpp ;;
	*) return 1 ;;
	esac

	$dut <<. || return $?
		ovsh d DPP_Config
		ovsh d DPP_Announcement
		ovsh d Wifi_VIF_Config
		ovsh w Wifi_VIF_State -n -w if_name==$dut_vif_ap0 if_name:=$dut_vif_ap0
		ovsh d Wifi_Radio_Config
		ovsh d Wifi_Associated_Clients
.

	$ref <<. || return $?
		ovsh d DPP_Config
		ovsh d DPP_Announcement
		ovsh d Wifi_VIF_Config
		ovsh w Wifi_VIF_State -n -w if_name==$ref_vif if_name:=$ref_vif
		ovsh d Wifi_Radio_Config
		ovsh d Wifi_Associated_Clients
.

	$dut <<. || return $?
		vif=\$(ovsh -Ur i Wifi_VIF_Config \
			enabled:=true \
			if_name:=$dut_vif_ap0 \
			dpp_connector~=$dppconn \
			dpp_csign_hex~=$dppcsign \
			dpp_netaccesskey_hex~=$dppnet \
			ssid:=$ssid \
			wpa:=true \
			dpp_cc:=true \
			mac_list_type:=none \
			'wpa_key_mgmt::["set", ["wpa2-psk", "dpp", "sae"]]' \
			'wpa_oftags::["map", [["key", "home--1"]]]' \
			'wpa_psks::["map", [["key", "'"$psk"'"]]]' \
			vif_radio_idx:=$dut_vif_ap0_idx \
			mode:=ap
		)

		ovsh i Wifi_Radio_Config \
			enabled:=true \
			if_name:=$dut_phy \
			ht_mode:=HT20 \
			hw_mode:=11n \
			freq_band:=2.4G \
			channel:=$chan \
			"vif_configs::[\"set\",[[\"uuid\",\"\$vif\"]]]"
.

	$ref <<. || return $?
		echo 1 > /tmp/target_hwsim_dpp_key
		echo 0 > /tmp/target_hwsim_dpp_curve
		echo "$urikeyhex" > /tmp/target_hwsim_dpp_key_hex

		vif=\$(ovsh -Ur i Wifi_VIF_Config \
			enabled:=true \
			if_name:=$ref_vif_sta \
			ssid:=we.onboard \
			mac_list_type:=none \
			'security::["map",[["key","12345678"],["encryption","WPA-PSK"]]]' \
			vif_radio_idx:=$ref_vif_sta_idx \
			mode:=sta
		)

		ovsh i Wifi_Radio_Config \
			enabled:=true \
			if_name:=$ref_phy \
			ht_mode:=HT20 \
			hw_mode:=11n \
			freq_band:=2.4G \
			"vif_configs::[\"set\",[[\"uuid\",\"\$vif\"]]]"
.

	$dut <<. || return $?
		ovsh w DPP_Announcement -w sta_mac_addr==$ref_mac_sta chirp_sha256_hex:=$urikeychirp
		ovsh i DPP_Config \
			'ifnames::["set", ["$dut_vif_ap0"]]' \
			configurator_key_hex~=$confhex \
			configurator_key_curve~=prime256v1 \
			configurator_conf_role~=sta-$1 \
			configurator_conf_psk_hex~=$pskhex \
			configurator_conf_ssid_hex~=$ssidhex \
			timeout_seconds:=120 \
			auth:=initiate_on_announce \
			status:=requested \
			peer_bi_uri~="$uri"
		ovsh w DPP_Config -t 130000 -w status==succeeded status:=succeeded
		ovsh s DPP_Config -c
.

	$ref <<. || return $?
		ovsh s DPP_Config -c
		ovsh s Wifi_VIF_Config -c
		ovsh w Wifi_VIF_State -w if_name==$ref_vif_sta parent:=$dut_mac_ap0
		ovsh s Wifi_VIF_State -c
		ovsh s Wifi_VIF_State -w if_name==$ref_vif_sta wpa_key_mgmt | grep $mgmt
.
}

onboard_legacy_fallback_pre() {
	# This tests if WM can still fallback and use the
	# legacy PSK onboarding logic.

	$dut <<. || return $?
		ovsh d DPP_Config
		ovsh d DPP_Announcement
		ovsh d Wifi_VIF_Config
		ovsh w Wifi_VIF_State -n -w if_name==$dut_vif_ap0 if_name:=$dut_vif_ap0
		ovsh d Wifi_Radio_Config
		ovsh d Wifi_Associated_Clients
.

	$ref <<. || return $?
		ovsh d DPP_Config
		ovsh d DPP_Announcement
		ovsh d Wifi_VIF_Config
		ovsh w Wifi_VIF_State -n -w if_name==$ref_vif_sta if_name:=$ref_vif_sta
		ovsh d Wifi_Radio_Config
		ovsh d Wifi_Associated_Clients
.

	$dut <<. || return $?
		vif=\$(ovsh -Ur i Wifi_VIF_Config \
			enabled:=true \
			if_name:=$dut_vif_ap0 \
			ssid:=$ssid \
			wpa:=true \
			'wpa_key_mgmt::["set", ["wpa2-psk"]]' \
			'wpa_oftags::["map", [["key", "home--1"]]]' \
			'wpa_psks::["map", [["key", "'"$psk"'"]]]' \
			vif_radio_idx:=$dut_vif_ap0_idx \
			mode:=ap
		)

		ovsh i Wifi_Radio_Config \
			enabled:=true \
			if_name:=$dut_phy \
			ht_mode:=HT20 \
			hw_mode:=11n \
			freq_band:=2.4G \
			channel:=$chan \
			"vif_configs::[\"set\",[[\"uuid\",\"\$vif\"]]]"
.

	$ref <<. || return $?
		echo 1 > /tmp/target_hwsim_dpp_key
		echo 0 > /tmp/target_hwsim_dpp_curve
		echo "$urikeyhex" > /tmp/target_hwsim_dpp_key_hex

		vif=\$(ovsh -Ur i Wifi_VIF_Config \
			enabled:=true \
			if_name:=$ref_vif_sta \
			ssid:=$ssid \
			'security::["map",[["key","$psk"],["encryption","WPA-PSK"]]]' \
			vif_radio_idx:=$ref_vif_sta_idx \
			mode:=sta
		)

		ovsh i Wifi_Radio_Config \
			enabled:=true \
			if_name:=$ref_phy \
			ht_mode:=HT20 \
			hw_mode:=11n \
			freq_band:=2.4G \
			"vif_configs::[\"set\",[[\"uuid\",\"\$vif\"]]]"
.

	$ref <<. || return $?
		ovsh w Wifi_VIF_State -t 200000 -w if_name==$ref_vif_sta parent:=$dut_mac_ap0
.
}

onboard_legacy_fallback_post() {
	# This tests if WM can still fallback and use the
	# legacy PSK onboarding logic.
	#
	# This gives the system some time to do chirping for
	# a bit before starting up parent AP.

	$dut <<. || return $?
		ovsh d DPP_Config
		ovsh d DPP_Announcement
		ovsh d Wifi_VIF_Config
		ovsh w Wifi_VIF_State -n -w if_name==$dut_vif_ap0 if_name:=$dut_vif_ap0
		ovsh d Wifi_Radio_Config
		ovsh d Wifi_Associated_Clients
.

	$ref <<. || return $?
		ovsh d DPP_Config
		ovsh d DPP_Announcement
		ovsh d Wifi_VIF_Config
		ovsh w Wifi_VIF_State -n -w if_name==$ref_vif_sta if_name:=$ref_vif_sta
		ovsh d Wifi_Radio_Config
		ovsh d Wifi_Associated_Clients
.

	$ref <<. || return $?
		echo 1 > /tmp/target_hwsim_dpp_key
		echo 0 > /tmp/target_hwsim_dpp_curve
		echo "$urikeyhex" > /tmp/target_hwsim_dpp_key_hex

		vif=\$(ovsh -Ur i Wifi_VIF_Config \
			enabled:=true \
			if_name:=$ref_vif_sta \
			ssid:=$ssid \
			'security::["map",[["key","$psk"],["encryption","WPA-PSK"]]]' \
			vif_radio_idx:=$ref_vif_sta_idx \
			mode:=sta
		)

		ovsh i Wifi_Radio_Config \
			enabled:=true \
			if_name:=$ref_phy \
			ht_mode:=HT20 \
			hw_mode:=11n \
			freq_band:=2.4G \
			"vif_configs::[\"set\",[[\"uuid\",\"\$vif\"]]]"
.

	sleep $i

	$dut <<. || return $?
		vif=\$(ovsh -Ur i Wifi_VIF_Config \
			enabled:=true \
			if_name:=$dut_vif_ap0 \
			ssid:=$ssid \
			wpa:=true \
			'wpa_key_mgmt::["set", ["wpa2-psk"]]' \
			'wpa_oftags::["map", [["key", "home--1"]]]' \
			'wpa_psks::["map", [["key", "'"$psk"'"]]]' \
			vif_radio_idx:=$dut_vif_ap0_idx \
			mode:=ap
		)

		ovsh i Wifi_Radio_Config \
			enabled:=true \
			if_name:=$dut_phy \
			ht_mode:=HT20 \
			hw_mode:=11n \
			freq_band:=2.4G \
			channel:=$chan \
			"vif_configs::[\"set\",[[\"uuid\",\"\$vif\"]]]"
.

	$ref <<. || return $?
		# This can take more than 60s
		ovsh w Wifi_VIF_State -t 200000 -w if_name==$ref_vif_sta parent:=$dut_mac_ap0 || \
		(
			wpa_cli -p /var/run/wpa_supplicant-phy1 status
			wpa_cli -p /var/run/wpa_supplicant-phy1 scan_r
			wpa_cli -p /var/run/wpa_supplicant-phy1 list_n
			false
		)
.
}

onboard_cleanup() {
	# This checks if STA vif removal does preempt/stop chirping
	# Without this onboarding can take too long
	$dut <<. || return $?
		ovsh d DPP_Config
		ovsh d DPP_Announcement
		ovsh d Wifi_VIF_Config
		ovsh w Wifi_VIF_State -n -w if_name==$dut_vif_sta if_name:=$dut_vif_sta
		ovsh d Wifi_Radio_Config
		ovsh d Wifi_Associated_Clients

		sleep 5

		echo 1 > /tmp/target_hwsim_dpp_key
		echo 0 > /tmp/target_hwsim_dpp_curve
		echo "$urikeyhex" > /tmp/target_hwsim_dpp_key_hex

		vif=\$(ovsh -Ur i Wifi_VIF_Config \
			enabled:=true \
			if_name:=$dut_vif_sta \
			ssid:=$ssid \
			'security::["map",[["key","$psk"],["encryption","WPA-PSK"]]]' \
			vif_radio_idx:=$dut_vif_sta_idx \
			mode:=sta
		)

		ovsh i Wifi_Radio_Config \
			enabled:=true \
			if_name:=$dut_phy \
			ht_mode:=HT20 \
			hw_mode:=11n \
			freq_band:=2.4G \
			"vif_configs::[\"set\",[[\"uuid\",\"\$vif\"]]]"

		ovsh -t 5000 w DPP_Config -w auth==chirp_and_respond status:=in_progress
		ovsh d Wifi_VIF_Config
		ovsh -t 5000 w DPP_Config -w auth==chirp_and_respond status:=requested
.
}

step() {
	name=${self}_$(echo "$*" | tr ' ' '_' | tr -dc a-z0-9_)

	if "$@"
	then
		echo "$name PASS" | tee -a "logs/$self/ret"
	else
		echo "$name FAIL" | tee -a "logs/$self/ret"
	fi
}

rm -f "logs/$self/ret"

base() {
	setchan 6
	step onboard dpp
	step onboard dpp-psk-sae
	step onboard psk
	step onboard sae
	step onboard_legacy_fallback_pre
	step onboard_legacy_fallback_post 10
	step onboard_legacy_fallback_post 30
	step onboard_legacy_fallback_post 60
	step onboard_cleanup
}

nonstdchan() {
	setchan 1
	step onboard psk nonstdchan
}

base
nonstdchan

cat "logs/$self/ret"
