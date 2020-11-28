$login = "<your_login>"
$pw = "<password>"
$ipadd ="<your_path_file_with_ipadderess_device>"
$command = '/system identity print'
$report = "<your_path_file_success_logs>"
$reportfail = "<your_path_file_fail_logs>"
date | Out-File $report
date | Out-File $reportfail
$file = "<your_path_file_command.rsc>"
function exec ($_ip, $_command, $_login, $_report, $_pw) {
echo yes | plink.exe $_ip -l $_login -pw $_pw $_command | Out-File $_report -Append
}
function upload ($_ip,$_fail, $_report) { echo yes | pscp.exe -l $login -pw $pw $_fail "$_ip"":/<name_file>.rsc" | Out-File $_report -Append }
#for test 
#$ip = "test_IP_address"
#$range = $ip

$range = Get-Content $ipadd | ? {$_ -notlike "#*"}

$range | % {$ip = $_ ;
if (Test-Connection $ip -Count 2 -Quiet) { 
$ip | Out-File $report -Append;
$ip;
upload -_ip $ip -_pw $pw -_fail $file -_login $login -_report $report;
exec -_ip $ip -_pw $pw -_command $command -_login $login -_report $report;
} else {$ip | Out-File $reportfail -Append}
}
#for test
#exec -_ip $ip -_pw $pw -_command $command -_login $login -_re
