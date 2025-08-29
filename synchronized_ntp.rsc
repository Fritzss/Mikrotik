if ([/system ntp client get status] != "synchronized") do={
:local ntp0 [resolve ntp0.ntp-servers.net]
:local ntp1 [resolve ntp1.ntp-servers.net]
/system ntp client set primary-ntp=$ntp0
/system ntp client set secondary-ntp=$ntp1
/system ntp client set enabled=no
:delay 5
/system ntp client set enabled=yes
if ([/system ntp client get status] = "synchronized")  do={/log info message="ntp synchronized"}
} else={/log info message="ntp synchronized"}
