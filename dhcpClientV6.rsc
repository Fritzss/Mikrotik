# multi wan dhcp-client

/ip dhcp-client add default-route-distance=5 disabled=no interface=ether1 script="{:local rmark \"R_ISP1\"\r\
    \n   /log info message=\$rmark\r\
    \n  :local countrule [/ip route rule print count-only where comment=\$rmark]\r\
    \n  :local countroute [/ip route print count-only where routing-mark=\$rmark]\r\
    \n  :if (\$bound=1) do={:if (\$countrule=0) do={ /ip route rule add comment=\$rmark src-address=\$\"lease-address\" action=lookup-only-in-table table=\$rmark }\r\
    \n                    :local ispgw \$\"gateway-address\";\r\
    \n                    :local rulesrcadd [/ip route rule get [find comment=\$rmark] src-address]\r\
    \n\t    :local rulesrcadd [:pick \$rulesrcadd 0 [:find \$rulesrcadd \"/\"]]\r\
    \n                    /log info message=\"rule src add \$rulesrcadd\" \r\
    \n\t   :if (\$rulesrcadd!=\$\"lease-address\") do={/ip route rule set [find comment=\$rmark] src-address=\$\"lease-address\"}\r\
    \n\t   :if (\$countroute=0) do={/ip route add comment=\$rmark gateway=\$\"gateway-address\" routing-mark=\$rmark}\r\
    \n\t   :foreach g in=[/ip route find comment=\$rmark ] do={:local curgw [/ip route get \$g gateway];\r\
    \n                                                         /log info message=\"current GW \$curgw, new GW \$spgw \" ;\r\
    \n                                                                                :if (\$curgw!=\$ispgw) do={/ip route set \$g gateway=\$\"gateway-address\" ; /log info message=\"route change \$curgw for route \$rmark\" }\r\
    \n\t\t\t\t\t}\r\
    \n                        }\r\
    \n}" use-peer-dns=no use-peer-ntp=no
    
# script check and correct gateway with comment R_ISP1

# script is needed for Dual Wan or Multi Wan to fix static routes

# the script must be added to each wan interface with its own comment
