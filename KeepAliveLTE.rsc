# Up LTE if pptp down over LTE

/ppp profile add change-tcp-mss=yes name=pr_PPTP on-down=":global int\r\
    \n:set int [/interface get \$interface name]\r\
    \n/log info message=\"script profile pptp interface \$int down\" \r\
    \n/system script run scr_KeepAliveLTE" on-up="foreach i in=[/system script job find script=scr_KeepAliveLTE ] do={/system script job remove \$i} \r\
    \n/system script environment remove [find]" use-compression=yes use-encryption=yes use-mpls=no


/system script add dont-require-permissions=no name=scr_KeepAliveLTE owner=Fritz policy=ftp,reboot,read,write,policy,test,password,sensitive source=":global int \$int\r\
    \n:global upt [system resource get uptime]\r\
    \n:local job [/system script job find script=scr_KeepAliveLTE]\r\
    \n/log info message=\"script job \$job\"\r\
    \n:foreach i in=[/system script job find script=scr_KeepAliveLTE] do={:put \$i; set \$count (\$count +1)}\r\
    \n/log info message=\"script count \$count\"\r\
    \nif (\$count < 2) do={\r\
    \n:local checkupt [(\$upt < 5m)]\r\
    \n/log info message=\"script check upttime \$upt \$checkupt\"\r\
    \nif (\$upt < 5m) do={/log info message=\"script delay 300\"; :delay 300 } else={\r\
    \n:local checkpptp [/interface pptp-client get \$int running ]\r\
    \n/log info message=\"script check pptp \$checkpptp \"\r\
    \nif (![/interface pptp-client get \$int running ]) do={\r\
    \n/log info message=\"script KeepAliveLte started\"\r\
    \n/log info message=\"script KeepAliveLte started \$count\"\r\
    \n/interface lte disable [find]\r\
    \n/log info message=\"script KeepAliveLte disable LTE\"\r\
    \n:delay 3\r\
    \nwhile condition=([/interface lte get [find] disabled]) do={/interface lte enable [find]; :delay 1}\r\
    \n/log info message=\"script KeepAliveLte enable LTE\"\r\
    \n/log info message=\"pptpInt \$int\"\r\
    \n:delay 50\r\
    \nif (![/interface pptp-client get \$int running ]) do={\r\
    \n:local pptpSerAddr [/ip address get [find interface=\$int] network ]\r\
    \n/log info message=\"server ip: \$pptpSerAddr\"\r\
    \n:global ST [/system clock get time]\r\
    \n/log info message=\"StartTime \$ST\"\r\
    \n:while condition=(![/interface lte get [find] running ]) do={\r\
    \n /log info message=\"usb power-reset\";\r\
    \n /system routerboard usb power-reset duration=5;\r\
    \n:delay 200\r\
    \n:local lt [/interface lte find]\r\
    \nif ([len \$lt] = 0) do={/system reboot}\r\
    \nwhile condition=([/interface lte get [find] disabled]) do={/interface lte enable [find]; :delay 1}\r\
    \n:global ET [/system clock get time]\r\
    \n/log info message=\"end Time \$ET\"\r\
    \nif ((\$ET - \$ST) > 1h) do={/system reboot }\r\
    \n}\r\
    \n} else={/log info message=\"pptp Ok\" }\r\
    \n} else={/log info message=\"pptp Ok\" }\r\
    \n}\r\
    \n} else={/log info message=\"job scr_KeepAliveLTE is working\"}"
