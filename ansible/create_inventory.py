#!/bin/python3

from paramiko import SSHClient, AutoAddPolicy
import re
import yaml
from subprocess import run, PIPE
import os
import sys
import logging

# Конфигурация логгера
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("inventory.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Константы
SCRIPT_DIR = os.path.dirname(os.path.abspath(sys.argv[0]))
os.chdir(SCRIPT_DIR)

INVENTORY_FILE = './main_hosts.yaml'
OUTPUT_INVENTORY = '/var/opt/ansible/inventory/dyn_inven.yaml'
BACKUP_INVENTORY = './backup_dyn_inven.yaml'
SSH_PORT = 22
ENCODING = 'utf-8'

# SSH-команды
NEIGHBOR_CMD = ':put [ /ip neighbor print detail without-paging where platform="MikroTik" address~".+"]'
RESOURCE_CMD = ':put [/system resource print without-paging]'


class DeviceConnection:
    """Класс для управления SSH-соединением и выполнения команд"""
    def __init__(self, host, username, password, port=SSH_PORT):
        self.host = host
        self.username = username
        self.password = password
        self.port = port
        self.client = None

    def __enter__(self):
        self.client = SSHClient()
        self.client.load_system_host_keys()
        self.client.set_missing_host_key_policy(AutoAddPolicy())
        try:
            self.client.connect(
                self.host,
                port=self.port,
                username=self.username,
                password=self.password,
                timeout=3,
                banner_timeout=1,
                auth_timeout=20
            )
            return self
        except Exception as e:
            logger.error(f"SSH connection failed to {self.host}: {str(e)}")
            return None

    def __exit__(self, exc_type, exc_value, traceback):
        if self.client:
            self.client.close()

    def execute_command(self, command):
        """Выполнение команды на устройстве"""
        try:
            if not self.client:
                return ""
            _, stdout, _ = self.client.exec_command(command)
            return stdout.read().decode(ENCODING)
        except Exception as e:
            logger.error(f"SSH command error on {self.host}: {str(e)}")
            return ""


def check_host(ip_address):
    """Проверка доступности хоста через ping"""
    result = run(['ping', '-c', '3', '-n', ip_address],
                 stdout=PIPE,
                 stderr=PIPE,
                 encoding=ENCODING)
    return result.returncode == 0


def get_device_info(host, username, password):
    """Получение информации о устройстве"""
    with DeviceConnection(host, username, password) as conn:
        if conn is None:
            return {'arch': 'unknown', 'board': 'unknown', 'version': 'unknown'}

        resource_data = conn.execute_command(RESOURCE_CMD)

    if not resource_data:
        return {'arch': 'unknown', 'board': 'unknown', 'version': 'unknown'}

    try:
        arch_match = re.search(r'architecture-name:\s*(.+?)\s', resource_data)
        board_match = re.search(r'board-name:\s*(.+?)\s', resource_data)
        version_match = re.search(r'version:\s*(\d+(?:\.\d+)+)', resource_data)

        arch = arch_match.group(1).strip() if arch_match else 'unknown'
        board = board_match.group(1).strip() if board_match else 'unknown'
        version = version_match.group(1).strip() if version_match else 'unknown'

        logger.info(f"Device info: {host} | Arch: {arch} | Board: {board} | Version: {version}")
        return {'arch': arch, 'board': board, 'version': version}
    except Exception as e:
        logger.error(f"Error parsing resource data for {host}: {str(e)}")
        return {'arch': 'unknown', 'board': 'unknown', 'version': 'unknown'}


def get_neighbors(host, username, password):
    """Получение списка соседних MikroTik устройств"""
    with DeviceConnection(host, username, password) as conn:
        if conn is None:
            return []
        neighbor_data = conn.execute_command(NEIGHBOR_CMD)

    if not neighbor_data:
        return []

    devices = []
    entries = re.split(r'\s\d+\s', neighbor_data)

    for entry in entries:
        if not entry.strip():
            continue

        try:
            identity_match = re.search(r'identity="(.+?)"', entry)
            ip_match = re.search(r'address=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', entry)
            version_match = re.search(r'version="(\d+(?:\.\d+)+)', entry)
            interface_match = re.search(r'interface=(.+?)\s', entry)

            if not all([identity_match, ip_match, version_match, interface_match]):
                logger.warning(f"Incomplete neighbor entry: {entry}")
                continue

            identity = identity_match.group(1)
            ip = ip_match.group(1)
            version = version_match.group(1)
            interface = interface_match.group(1)

            devices.append({
                'identity': identity,
                'ip': ip,
                'version': version,
                'interface': interface,
            })
        except Exception as e:
            logger.error(f"Error parsing neighbor entry: {entry} | Error: {str(e)}")

    return devices


def generate_inventory_structure():
    """Базовая структура инвентаря Ansible"""
    return {
        'all': {
            'vars': {
                'ansible_connection': 'ansible.netcommon.network_cli',
                'ansible_network_os': 'community.routeros.routeros',
                'ansible_user': '{{ user }}',
                'ansible_ssh_pass': '{{ password }}',
                'host_key_checking': 'False'
            },
            'children': {}
        }
    }


def determine_role(identity, roles):
    """Определение роли устройства на основе identity и списка ролей"""
    if not identity:
        return 'unknown'

    # Берем последний символ identity для определения роли
    role_char = identity[-1]

    for role_def in roles:
        if role_def['tag'] == role_char:
            return role_def['role']
        else:
            return role_def['role_def']

    return 'unknown'


def main():
    # Загрузка основного инвентаря
    try:
        with open(INVENTORY_FILE) as f:
            main_inventory = yaml.safe_load(f)
    except Exception as e:
        logger.error(f"Failed to load inventory file: {str(e)}")
        return

    global_vars = main_inventory.get("vars", {})
    inventory = generate_inventory_structure()

    # Обработка устройств из main_host.yaml
    for group_name, group_data in main_inventory.items():
        if group_name == "vars":
            continue

        if not isinstance(group_data, dict):
            logger.warning(f"Skipping invalid group entry: {group_name}")
            continue

        host = group_data.get("host")
        name = group_data.get("name")

        if not host or not name:
            logger.warning(f"Skipping group {group_name} due to missing host or name")
            continue

        username = global_vars.get("user", "")
        password = global_vars.get("password", "")

        # Информация о главном устройстве
        device_info = get_device_info(host, username, password)

        # Добавление главного устройства
        group_key = f"group_{group_name}"
        inventory['all']['children'].setdefault(group_key, {'hosts': {}})
        inventory['all']['children'][group_key]['hosts'][name] = {
            'ansible_host': host,
            'version': device_info['version'],
            'identity': name,
            'role': 'root',
            'architecture': device_info['arch'],
            'board': device_info['board']
        }
        logger.info(f"Added main device: {name} ({host}) to group {group_key}")

        # Обработка соседних устройств
        neighbors = get_neighbors(host, username, password)
        exclude_interfaces = global_vars.get("exclude_interfaces", [])
        roles = global_vars.get("roles", [])
        architectures = global_vars.get("architectures", [])

        for neighbor in neighbors:
            if neighbor['interface'] in exclude_interfaces:
                logger.info(f"Skipping neighbor {neighbor['ip']} on excluded interface {neighbor['interface']}")
                continue

            # Определение роли по последнему символу identity
            role = determine_role(neighbor['identity'], roles)

            # Получаем информацию о железе соседнего устройства
            neighbor_info = get_device_info(neighbor['ip'], username, password)

            # Определение группы по архитектуре
            arch_group = 'default'
            for arch in architectures:
                if arch['arch'] in neighbor_info['arch']:
                    arch_group = arch['arch_group']
                    break

            # Добавление в инвентарь
            inventory['all']['children'].setdefault(arch_group, {'hosts': {}})
            inventory['all']['children'][arch_group]['hosts'][neighbor['identity']] = {
                'ansible_host': neighbor['ip'],
                'version': neighbor['version'],
                'identity': neighbor['identity'],
                'role': role,
                'architecture': neighbor_info['arch'],
                'board': neighbor_info['board']
            }
            logger.info(f"Added neighbor: {neighbor['ip']} | Role: {role} | Interface: {neighbor['interface']}")

    # Сохранение результатов
    for file_path in [OUTPUT_INVENTORY, BACKUP_INVENTORY]:
        try:
            with open(file_path, 'w') as f:
                yaml.dump(inventory, f)
            logger.info(f"Inventory saved to {file_path}")
        except Exception as e:
            logger.error(f"Failed to save inventory to {file_path}: {str(e)}")


if __name__ == "__main__":
    main()
