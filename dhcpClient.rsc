# multi wan dhcp-client

/ip dhcp-client add add-default-route=no default-route-tables=main interface=br_wan1 script="{\r\
    \n:local leaseip \$\"lease-address\"\r\
    \n:local gate \$\"gateway-address\"\r\
    \n:local rmark \"rule_for_\$interface\"\r\
    \n:local metric 1\r\
    \n:local static \"static_\$interface\"\r\
    \n\r\
    \n:local addMarkRoute do={\r\
    \n    :local routeRule [/routing/rule find comment=\$rmark routing-table=\$rmark]\r\
    \n    if (\$routeRule=\"\") do={\r\
    \n            /log/info message=\"add rule table \$rmark address \$leaseip action lookup\"\r\
    \n            /routing/rule add action=lookup-only-in-table comment=\$rmark disabled=no src-address=\$leaseip table=\$rmark\r\
    \n        } else {\r\
    \n            :local checkRule [/routing/rule get \$routeRule src-address]\r\
    \n            if (\$checkRule!=\$leaseip) do={\r\
    \n            /log/info message=\"set address \$leaseip rule action lookup table \$rmark\"\r\
    \n            /routing/rule set src-address=\$leaseip \$routeRule\r\
    \n            }\r\
    \n        }\r\
    \n        :local markRoute [/ip/route find comment=\$rmark routing-table=\$rmark]\r\
    \n        /log/info message=\"markRoute \$markRoute for \$interface\"\r\
    \n        if (\$markRoute) do={\r\
    \n            :local checkGate [/ip/route get \$markRoute gateway]\r\
    \n            /log/info message=\"current gateway \$checkGate actual gateway \$gate\"\r\
    \n            if (\$checkGate!=\$gate) do={\r\
    \n                /ip/route set gateway=\$gate \$markRoute comment=\"\$rmark\"\r\
    \n                /log/info message=\"set gateway \$gate route table \$rmark\"\r\
    \n               }\r\
    \n        } else {\r\
    \n            /ip/route add gateway=\$gate comment=\"\$rmark\" routing-table=\$rmark;\r\
    \n            /log/info message=\"add route table \$rmark gateway \$gate\"\r\
    \n            }\r\
    \n    }\r\
    \nif (\$bound = 1) do={\r\
    \n# add default route \r\
    \n:local defroute [ /ip/route/find where dynamic=no dst-address=0.0.0.0/0 routing-table=main comment=\"def_route_\$interface\"]\r\
    \n/log/info message=\"default route \$defroute \$interface\"\r\
    \nif (\$defroute) do={\r\
    \n    :local check [/ip/route get \$defroute gateway]\r\
    \n    if (\$check!=\$gate) do={\r\
    \n        /ip/route set \$defroute comment=\"def_route_\$interface\" gateway=\$gate routing-table=main distance=\$metric\r\
    \n       }\r\
    \n} else {\r\
    \n    /log/info message=\"add default route gate \$gate interface \$interface distance \$metric\"\r\
    \n    /ip/route/add dst-address=0.0.0.0/0 gateway=\$gate comment=\"def_route_\$interface\" routing-table=main distance=\$metric\r\
    \n}\r\
    \nif ([/routing/table/find name=\$rmark]) do={\r\
    \n    /log/info message=\"table \$rmark exists\"\r\
    \n    \$addMarkRoute rmark=\$rmark leaseip=\$leaseip gate=\$gate interface=\$interface\r\
    \n} else {\r\
    \n   /log/info message=\"routing table add table \$rmark\"\r\
    \n   /routing table add comment=\$rmark disabled=no fib name=\$rmark\r\
    \n   \$addMarkRoute rmark=\$rmark leaseip=\$leaseip gate=\$gate interface=\$interface\r\
    \n}\r\
    \n:foreach i in=[/ip/route/find where dynamic=no comment=\"\$static\" ] do={\r\
    \n      :local check [/ip/route get \$i gateway]\r\
    \n       if (\$check!=\$gate) do={\r\
    \n             /ip/route/set comment=\"\$static\" gateway=\$gate \$i\r\
    \n         }\r\
    \n      }\r\
    \n}\r\
    \n}" use-peer-dns=no use-peer-ntp=no

# script add default gateway, if default route for interface is missing
# scrip check correct gateway with comment "def_route_$interface", if default route is incorrect, fixes
# script add route table "rule_for_$interface", if route table for interface is missing
# script add route rule "rule_for_$interface", if route rule for interface is missing
# scritp check correct route rule with comment "rule_for_$interface", if rule is incorrect, fixes
# script check static routes routes comment "static_$interface", if gateway is incorrect, fixes

# the script must be added to each wan interface with its own metric
# for static routes you need to add a comment "static_$interface"


