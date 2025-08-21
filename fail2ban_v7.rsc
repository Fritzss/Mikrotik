{
:local quantity 50;
:local dstport 443;
:local proto "tcp";
:local ISPinterfaceList "ISP";

:local fail2ban do={/ip/firewall/mangle/add action=add-src-to-address-list address-list="attack_attempt_$dstport_$i" 
                        address-list-timeout=1m chain="fail2ban_$dstport" 
                        comment="IP address that attempted to $dstport" connection-state=new src-address-list="attack_attempt_$dstport_$j"
                    };
:local est [/ip/firewall/mangle/ find connection-state="established,related" chain=prerouting];
:local jmprule [/ip/firewall/mangle/ find action=jump chain=prerouting connection-state="new" dst-port=$dstport jump-target="fail2ban_$dstport"];
:local fail2banchain [/ip/firewall/mangle/ find chain="fail2ban_$dstport"];
:local rawfail2banchain [/ip/firewall/raw/ find chain=prerouting dst-port=$dstport];

:if ([:len $fail2banchain] >= $quantity) do={:local chainlen [:len $fail2banchain]; :put "chain fail2ban_$dstport is exist, count rule $chainlen"} else={

:if $est do={/ip/firewall/mangle/ set comment="EST,REL" $est} else={/ip/firewall/mangle/ add action=accept chain=prerouting connection-state=established,related comment="EST,REL"};

:if $jmprule do={/ip/firewall/mangle/ set comment="jmprule for fail2ban $dstport" $jmprule} else={
/ip/firewall/mangle/ add action=jump chain=prerouting connection-state=new protocol=$proto dst-port=$dstport in-interface-list=$ISPinterfaceList 
                     jump-target="fail2ban_$dstport" comment="jmprule for fail2ban $dstport"
};

/ip/firewall/mangle/ add action=add-src-to-address-list address-list="attacker_blacklist_$dstport"
             address-list-timeout=1d chain="fail2ban_$dstport" comment="Blocked IP address that attacker_blacklist_$dstport" src-address-list="attack_attempt_$dstport_$quantity";
 
:for i from=$quantity to=2 step=-1 do={ :local j ($i-1) ; $fail2ban i=$i dstport=$dstport j=$j};

/ip/firewall/mangle/  add action=add-src-to-address-list address-list="attack_attempt_$dstport_1" 
             address-list-timeout=1m chain="fail2ban_$dstport" comment="IP address that attempted to create an $dstport connections" connection-state=new;
:if $rawfail2banchain do={/ip/firewall/raw/ set comment="drop_attacker_blacklist_$dstport"} else={   
/ip/firewall/raw/ add action=drop dst-port=$dstport protocol=$proto src-address-list="attacker_blacklist_$dstport" chain=prerouting
             comment="drop_attacker_blacklist_$dstport" log=yes log-prefix="attacker_blacklist_$dstport";
     }
};
}
