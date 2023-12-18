# Copyright 2018 The Prometheus Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

MIBDIR   := mibs
MIB_PATH := 'mibs'

CURL_OPTS ?= -L --no-progress-meter --retry 3 --retry-delay 3 --fail

REPO_TAG ?= $(shell git rev-parse --abbrev-ref HEAD)


IANA_CHARSET_URL  := https://www.iana.org/assignments/ianacharset-mib/ianacharset-mib
IANA_IFTYPE_URL   := https://www.iana.org/assignments/ianaiftype-mib/ianaiftype-mib
MIKROTIK_URL      := 'https://box.mikrotik.com/f/a41daf63d0c14347a088/?dl=1'
NET_SNMP_URL      := https://raw.githubusercontent.com/net-snmp/net-snmp/v5.9/mibs

.DEFAULT: all

.PHONY: all
all: mibs

clean:
        rm -rvf \
                $(MIBDIR)/* \
                $(MIBDIR)/.net-snmp \

generator: *.go
        go build

generate: generator mibs
        MIBDIRS=$(MIB_PATH) ./generator --fail-on-parse-errors generate

parse_errors: generator mibs
        MIBDIRS=$(MIB_PATH) ./generator --fail-on-parse-errors parse_errors


mibs: \
  $(MIBDIR)/IANA-CHARSET-MIB.txt \
  $(MIBDIR)/IANA-IFTYPE-MIB.txt \
  $(MIBDIR)/MIKROTIK-MIB \
  $(MIBDIR)/.net-snmp \



$(MIBDIR)/IANA-CHARSET-MIB.txt:
        @echo ">> Downloading IANA charset MIB"
        @curl $(CURL_OPTS) -o $(MIBDIR)/IANA-CHARSET-MIB.txt $(IANA_CHARSET_URL)

$(MIBDIR)/IANA-IFTYPE-MIB.txt:
        @echo ">> Downloading IANA ifType MIB"
        @curl $(CURL_OPTS) -o $(MIBDIR)/IANA-IFTYPE-MIB.txt $(IANA_IFTYPE_URL)


$(MIBDIR)/MIKROTIK-MIB:
        @echo ">> Downloading MIKROTIK-MIB"
        @curl $(CURL_OPTS) -L -o $(MIBDIR)/MIKROTIK-MIB $(MIKROTIK_URL)

$(MIBDIR)/.net-snmp:
        @echo ">> Downloading NET-SNMP mibs"
        @curl $(CURL_OPTS) -o $(MIBDIR)/HCNUM-TC $(NET_SNMP_URL)/HCNUM-TC.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/HOST-RESOURCES-MIB $(NET_SNMP_URL)/HOST-RESOURCES-MIB.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/IF-MIB $(NET_SNMP_URL)/IF-MIB.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/IP-MIB $(NET_SNMP_URL)/IP-MIB.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/INET-ADDRESS-MIB $(NET_SNMP_URL)/INET-ADDRESS-MIB.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/IPV6-TC $(NET_SNMP_URL)/IPV6-TC.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/NET-SNMP-MIB $(NET_SNMP_URL)/NET-SNMP-MIB.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/NET-SNMP-TC $(NET_SNMP_URL)/NET-SNMP-TC.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/SNMP-FRAMEWORK-MIB $(NET_SNMP_URL)/SNMP-FRAMEWORK-MIB.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/SNMPv2-MIB $(NET_SNMP_URL)/SNMPv2-MIB.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/SNMPv2-SMI $(NET_SNMP_URL)/SNMPv2-SMI.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/SNMPv2-TC $(NET_SNMP_URL)/SNMPv2-TC.txt
        @curl $(CURL_OPTS) -o $(MIBDIR)/UCD-SNMP-MIB $(NET_SNMP_URL)/UCD-SNMP-MIB.txt
        @touch $(MIBDIR)/.net-snmp
