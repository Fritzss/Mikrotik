# Up LTE if pptp down over LTE

/ppp profile add change-tcp-mss=yes name=pr_PPTP on-down=":global int\r\
    \n:set int [/interface get \$interface name]\r\
    \n/log info message=\"script profile pptp interface \$int down\" \r\
    \n/system script run scr_KeepAliveLTE" on-up="foreach i in=[/system script job find script=scr_KeepAliveLTE ] do={/system script job remove \$i} \r\
    \n/system script environment remove [find]" use-compression=yes use-encryption=yes use-mpls=no


add dont-require-permissions=no name=scr_KeepAliveLTE owner=Fritz policy=\
    reboot,read,write,policy,test,sensitive source=":global int \$int\r\
    \n:global UP [system resource get uptime]\r\
    \n\r\
    \n:foreach i in=[/system script job find script=scr_KeepAliveLTE] do={\r\
    \n:set \$count (\$count +1);\r\
    \n}\r\
    \n\r\
    \nif (\$count < 2) do={\r\
    \n/log info message=\"script if Delay 5 \$UP \"; :delay 5;\r\
    \nif (\$UP  >  5m) do={\r\
    \n:global ST [/system clock get time]\r\
    \n/log info message=\"script start keepalive, interface \$int \";\r\
    \nwhile condition=(![/interface get \$int running ]) do={\r\
    \n/log info message=\"script start while\";\r\
    \n:global RebootAfterHour [:parse [/system script get RebootAfterHour sour\
    ce]]\r\
    \n\r\
    \n:global RestartLTE [:parse [/system script get RestartLTE source]]\r\
    \n\r\
    \n:global ResetLTE [:parse [/system script get ResetLTE source]]\r\
    \n\r\
    \n:global RestartVPN [:parse [/system script get RestartVPN source]]\r\
    \n\r\
    \n/log info message=\"script check uptime \$UP start time \$ST \"\r\
    \n\r\
    \n\r\
    \n\$RestartVPN int=\$int\r\
    \n\$RestartLTE\r\
    \n/log info message=\"script Delay 60\"; :delay 60;\r\
    \n\$ResetLTE\r\
    \n/log info message=\"script Delay 60\"; :delay 60;\r\
    \n\$RebootAfterHour ST=\$ST UP=\$UP\r\
    \n}\r\
    \n} else={/log info message=\"script delay 300\"; :delay 300 }\r\
    \n}\r\
    \n"
add dont-require-permissions=no name=RebootAfterHour owner=Fritz policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="{\
    \r\
    \n:local ET [/system clock get time]\r\
    \n:local UP [/system resource get uptime]\r\
    \n/log info message=\"ET \$ET ST \$ST\"\r\
    \nif ((\$ET - \$ST) > 1h and \$UP > 1h) do={\r\
    \n/log info message=\"end \$ET start, \$ST upt \$UP system reboot\";\r\
    \n/system reboot  \r\
    \n} else= {\r\
    \n/log info message=\"job scr_KeepAliveLTE is working\";\r\
    \n}\r\
    \n}"
add dont-require-permissions=no name=RestartLTE owner=Fritz policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="/\
    interface lte disable [find];\r\
    \n/log info message=\"script disable LTE\"\r\
    \n/log info message=\"script delay 1\";:delay 1\r\
    \n\r\
    \nwhile condition=([/interface lte get [find] disabled]) do={\r\
    \n/interface lte enable [find];\r\
    \n/log info message=\"script enable LTE\"\r\
    \n/log info message=\"script delay 20\";\r\
    \n:delay 20\r\
    \n}"
add dont-require-permissions=no name=ResetLTE owner=Fritz policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="{\
    \r\
    \n:local UP [/system resource get uptime]\r\
    \n/log info message=\"usb power-reset\";\r\
    \n/system routerboard usb power-reset duration=5;\r\
    \n/log info message=\"script Delay 200\";\r\
    \n:delay 200\r\
    \n/log info message=\"script Delay 200 END, script working\";\r\
    \n:local lt [/interface lte find]\r\
    \nif ([len \$lt] = 0 and \$UP > 15m) do={\r\
    \n/log info message=\"system reboot\";\r\
    \n/system reboot;\r\
    \n}\r\
    \n}\r\
    \n"
add dont-require-permissions=no name=RestartVPN owner=Fritz policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="{\
    \r\
    \n/log info message=\"script disable VPN \$int\"\r\
    \n/interface disable \$int\r\
    \n:delay 1\r\
    \n/log info message=\"script enable VPN \$int\"\r\
    \n/interface enable \$int\r\
    \n:delay 30\r\
    \n/log info message=\"script delay 30\"\r\
    \n/log info message=\"script delay 30 END, script working\"\r\
    \n}"
