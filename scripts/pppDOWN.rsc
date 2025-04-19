{
:local pppuser $"user"
:local remAddr $"remote-address"
:local callerID $"caller-id"
/log/info message="user $pppuser logout address $remAddr RID $callerID"
:local curAddrUser [ /ip/firewall/address-list find comment=$pppuser ]
if ([:len $curAddrUser] > 0) do={
      do {
             /ip/firewall/address-list remove $curAddrUser
             /log/info message="user $pppuser address $callerID remove from address-list"
            } on-error={
             /log/info message="error remove user $pppuser address $callerID from address-list"
            } 
} else {
      /log/info message="error not found comment for $pppuser address $callerID"
   }
}
