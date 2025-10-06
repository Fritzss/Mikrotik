{
:local certName "SSTP"
:local FQDN "<yuor_FQDN>"
:local COMMENTHTTP "HTTP_for_LetsEncrypt"
/ip/service/enable www
/ip/firewall/filter/enable [/ip/firewall/filter/find where comment=$COMMENTHTTP]
/certificate/enable-ssl-certificate dns-name=$FQDN
:delay 60
/ip/service/disable www
/ip/firewall/filter/disable [/ip/firewall/filter/find where comment=$COMMENTHTTP]
:local CRT [/certificate/find where common-name=$FQDN]
/certificate/set $CRT name=$certName trusted=yes
/interface/sstp-server/server/set certificate=$certName
}
