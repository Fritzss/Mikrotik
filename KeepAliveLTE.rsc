# Up LTE if pptp down over LTE

/ppp profile add change-tcp-mss=yes name=pr_PPTP on-down="/log info message=\"script KeepAliveLte started pptp\"\r\
    \n/system script run scr_KeepAliveLTE\r\
    \n\r\
    \n" on-up=":global int [interface get [find .id=\$interface] name]\r\
    \n:global pptpSerAddr [/ip address get [find interface=\$int] network]"


/system script add dont-require-permissions=no name=scr_KeepAliveLTE owner=Fritz policy=ftp,reboot,read,write,policy,test,password,sensitive source=":global pptpSerAddr \$pptpSerAddr\r\
    \n:global int \$int\r\
    \n{\r\
    \n/log info message=\"script KeepAliveLte started 1\"\r\
    \nglobal count 0\r\
    \n:foreach i in=[/system script job find script=scr_KeepAliveLTE] do={:put \$i; set count (\$count +1)}\r\
    \n/log info message=\"script count \$count\"\r\
    \nif (\$count < 2) do={\r\
    \n/log info message=\"script KeepAliveLte started 2\"\r\
    \n/interface lte disable [find]\r\
    \n/log info message=\"script KeepAliveLte disable LTE\"\r\
    \n:delay 2\r\
    \nwhile ([/interface lte get [find] disabled]) do={/interface lte enable [find]; :delay 1}\r\
    \n\r\
    \n/log info message=\"script KeepAliveLte enable LTE\"\r\
    \n/log info message=\"pptpInt \$int\"\r\
    \n:delay 50\r\
    \nif (![/interface pptp-client get [find] running ]) do={\r\
    \n/log info message=\"server ip: \$pptpSerAddr\"\r\
    \n:global ST [/system clock get time]\r\
    \n/log info message=\"StartTime \$ST\"\r\
    \n:while condition= (![/interface lte get [find] running ]) do={\r\
    \n /log info message=\"usb power-reset\";\r\
    \n /system routerboard usb power-reset duration=3;\r\
    \n:delay 300\r\
    \n/interface lte enable [find]\r\
    \n:global ET [/system clock get time]\r\
    \n/log info message=\"end Time \$ET\"\r\
    \nif ((\$ST - \$ET) > 1h) do={/log info message=\"system reboot\" }\r\
    \n}} else={/log info message=\"pptp Ok\" }\r\
    \n}}"
    
