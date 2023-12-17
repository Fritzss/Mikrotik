git clone https://github.com/prometheus/snmp_exporter.git
cd snmp_exporter/generator/
cat <<EOF> ./Makefile 
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

DOCKER_IMAGE_NAME ?= snmp-generator
DOCKER_IMAGE_TAG  ?= $(subst /,-,$(REPO_TAG))
DOCKER_REPO       ?= prom

SANITIZED_DOCKER_IMAGE_TAG := $(subst +,-,$(DOCKER_IMAGE_TAG))

SELINUX_ENABLED := $(shell cat /sys/fs/selinux/enforce 2> /dev/null || echo 0)

ifeq ($(SELINUX_ENABLED),1)
  DOCKER_VOL_OPTS ?= :z
endif

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

.PHONY: docker
docker:
        docker build --build-arg REPO_TAG="$(REPO_TAG)" -t "$(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):$(SANITIZED_DOCKER_IMAGE_TAG)" .

.PHONY: docker-generate
docker-generate: docker mibs
        docker run -ti -v "${PWD}:/opt$(DOCKER_VOL_OPTS)" "$(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):$(SANITIZED_DOCKER_IMAGE_TAG)" generate

.PHONY: docker-publish
docker-publish:
        docker push "$(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):$(SANITIZED_DOCKER_IMAGE_TAG)"

.PHONY: docker-tag-latest
docker-tag-latest:
        docker tag "$(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):$(SANITIZED_DOCKER_IMAGE_TAG)" "$(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):latest"

mibs: \
  $(MIBDIR)/MIKROTIK-MIB \
  $(MIBDIR)/.net-snmp \


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
EOF

cat <<EOF> ./generator.yml
---
auths:
  public_v1:
    version: 1
  public_v2:
    version: 2

modules:
  # Default IF-MIB interfaces table with ifIndex.
  if_mib:
    walk: [sysUpTime, interfaces, ifXTable]
    lookups:
      - source_indexes: [ifIndex]
        lookup: ifAlias
      - source_indexes: [ifIndex]
        # Uis OID to avoid conflict with PaloAlto PAN-COMMON-MIB.
        lookup: 1.3.6.1.2.1.2.2.1.2 # ifDescr
      - source_indexes: [ifIndex]
        # Use OID to avoid conflict with Netscaler NS-ROOT-MIB.
        lookup: 1.3.6.1.2.1.31.1.1.1.1 # ifName
    overrides:
      ifAlias:
        ignore: true # Lookup metric
      ifDescr:
        ignore: true # Lookup metric
      ifName:
        ignore: true # Lookup metric
      ifType:
        type: EnumAsInfo
  # Default IP-MIB with ipv4InterfaceTable for example.
  ip_mib:
    walk: [ipv4InterfaceTable]

# Mikrotik Router
#
# http://download2.mikrotik.com/Mikrotik.mib
  mikrotik:
    walk:
      - laIndex
      - sysDescr
      - mikrotik
    lookups:
      - source_indexes: [ifIndex]
        lookup: ifName
      - source_indexes: [mtxrInterfaceStatsIndex]
        lookup: ifName
      - source_indexes: [laIndex]
        lookup: laNames
        drop_source_indexes: true
      - source_indexes: [mtxrGaugeIndex]
        lookup: mtxrGaugeName
        drop_source_indexes: true
      - source_indexes: [mtxrNeighborIndex]
        lookup: mtxrNeighborMacAddress
        drop_source_indexes: true
      - source_indexes: [mtxrNeighborIndex]
        lookup: mtxrNeighborInterfaceID
      - source_indexes: [mtxrNeighborInterfaceID]
        lookup: ifName
        drop_source_indexes: true
      - source_indexes: [mtxrOpticalIndex]
        lookup: mtxrOpticalName
      - source_indexes: [mtxrPOEInterfaceIndex]
        lookup: mtxrPOEName
      - source_indexes: [mtxrPartitionIndex]
        lookup: mtxrPartitionName
    overrides:
      ifName:
        ignore: true # Lookup metric
      ifType:
        type: EnumAsInfo
      # Remap enums where 1==true, 2==false to become 0==false, 1==true.
      hrDiskStorageRemoveble:
        scale: -1.0
        offset: 2.0


#
# HOST-RESOURCES-MIB
#
# http://www.net-snmp.org/docs/mibs/host.html
  hrSystem:
    walk:
      - hrSystem
  hrStorage:
    walk:
      - hrStorage
    lookups:
      - source_indexes: [hrStorageIndex]
        lookup: hrStorageDescr
        drop_source_indexes: true
  hrDevice:
    walk:
      - hrDevice
    overrides:
      hrPrinterStatus:
        type: EnumAsStateSet
  hrSWRun:
    walk:
      - hrSWRun
  hrSWRunPerf:
    walk:
      - hrSWRunPerf
  hrSWInstalled:
    walk:
      - hrSWInstalled
EOF

make generate mibs
./generator generate -m mibs/ -o ./snmp.yml
