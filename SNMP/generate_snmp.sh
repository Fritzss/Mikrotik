git clone https://github.com/prometheus/snmp_exporter.git
cd snmp_exporter/generator/
make generate mibs
./generator generate -m mibs/ -o ./mik_snmp.yml
