/system scheduler add name=upgrade-bios on-event="/system script run update-bios" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive start-time=startup

/system script add dont-require-permissions=no name=update-bios owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive source="{\r\
    \n/system routerboard\r\
    \n:local cur [get current-firmware ]\r\
    \n:local up [get upgrade-firmware  ]\r\
    \n/log info message=\"Current bios \$cur, Upgrade bios \$up\"\r\
    \n:if (\$cur!=\$up) do={/log info message=\"upgrade bios\";upgrade;\r\
    \n/system reboot }\r\
    \n}"
 
