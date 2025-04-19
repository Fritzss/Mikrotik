{
:local pppuser $"user"
:local remAddr $"caller-id"
/log/info message="connect $pppuser from $remAddr"
:local comment [/ip/firewall/address-list find comment=$pppuser]
:if ([:len $comment] <= 0) do={
     do { 
           /ip/firewall/address-list add list=vpn_connection_users address=$remAddr comment=$user ; 
           /log/info message="add address $remAddr to allow for $pppuser"
        } on-error={/log/info message="address $remAddr for $pppuser exists"}
    } else {
    /log/info message="$pppuser exists"
   :local curAddr [/ip/firewall/address-list/get $comment address ]
   if ($curAddr!=$remAddr) do= {
        do {
           /ip/firewall/address-list set $comment list=vpn_connection_users address=$remAddr comment=$user ;
           :log info message="set address $remaddr to allow for $pppuser"
           } on-error={/log/info message="error set address $remaddr to allow for $pppuser"}
        } 
    }
}
