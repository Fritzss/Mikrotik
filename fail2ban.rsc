:global quantity 99
:global rdpport 24567

/ip firewall mangle add action=accept chain=prerouting connection-state=established,related
/ip firewall mangle add action=jump chain=prerouting connection-state=new dst-port=$rdpport jump-target=fail2ban protocol=tcp

/ip firewall mangle add action=add-src-to-address-list address-list=attacker_blacklist address-list-timeout=1d chain=fail2ban comment="Blocked IP address that attacker_blacklist" src-address-list="attack_attempt_$quantity"
 
global fail2ban do={/ip firewall mangle add action=add-src-to-address-list address-list="attack_attempt_$i" address-list-timeout=1m chain=fail2ban comment="IP address that attempted to RDP" connection-state=new src-address-list="attack_attempt_$j"}

for i from=$quantity to=2 step=-1 do={ :local j ($i-1) ; $fail2ban i=$i j=$j}

/ip firewall mangle  add action=add-src-to-address-list address-list=attack_attempt_1 address-list-timeout=1m chain=fail2ban comment="IP address that attempted to create an RDP connections" connection-state=new \
    log-prefix=1 protocol=tcp
/ip firewall raw add action=drop src-address-list=attacker_blacklist chain=prerouting
