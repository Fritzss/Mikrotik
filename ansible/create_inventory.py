#!/bin/python3

from paramiko import SSHClient, AutoAddPolicy
import re
import yaml
import os
import sys
import logging
import concurrent.futures
import threading
import json
from functools import partial
from subprocess import run, PIPE

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

# Глобальные переменные, которые будут установлены из YAML
OUTPUT_INVENTORY = None
BACKUP_INVENTORY = None
BOARD_ARCH_CACHE_FILE = None
SSH_PORT = None
MAX_WORKERS = None
ENCODING = None

# Глобальный кеш архитектур плат
BOARD_ARCH_CACHE = {}
CACHE_LOADED = False
LOCK = threading.Lock()

# SSH-команды
NEIGHBOR_CMD = ':put [ /ip neighbor print detail without-paging where platform="MikroTik" address~".+"]'
RESOURCE_CMD = ':put [/system resource print without-paging]'

class DeviceConnection:
    """Класс для управления SSH-соединением и выполнения команд"""
    def __init__(self, host, username, password):
        self.host = host
        self.username = username
        self.password = password
        self.client = None

    def __enter__(self):
        self.client = SSHClient()
        self.client.load_system_host_keys()
        self.client.set_missing_host_key_policy(AutoAddPolicy())
        try:
            self.client.connect(
                self.host,
                port=SSH_PORT,
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


def parse_device_info(resource_data):
    """Парсинг информации об устройстве из данных ресурсов"""
    try:
        arch_match = re.search(r'architecture-name:\s*(.+?)\s', resource_data)
        board_match = re.search(r'board-name:\s*(.+?)\s', resource_data)
        version_match = re.search(r'version:\s*(\d+(?:\.\d+)+)', resource_data)

        arch = arch_match.group(1).strip() if arch_match else 'unknown'
        board = board_match.group(1).strip() if board_match else 'unknown'
        version = version_match.group(1).strip() if version_match else 'unknown'

        return {'arch': arch, 'board': board, 'version': version}
    except Exception as e:
        logger.error(f"Error parsing resource data: {str(e)}")
        return {'arch': 'unknown', 'board': 'unknown', 'version': 'unknown'}


def get_device_info(host, username, password):
    """Получение информации об устройстве"""
    with DeviceConnection(host, username, password) as conn:
        if conn is None:
            return {'arch': 'unknown', 'board': 'unknown', 'version': 'unknown'}

        resource_data = conn.execute_command(RESOURCE_CMD)

    if not resource_data:
        return {'arch': 'unknown', 'board': 'unknown', 'version': 'unknown'}

    device_info = parse_device_info(resource_data)
    logger.info(f"Device info: {host} | Arch: {device_info['arch']} | Board: {device_info['board']} | Version: {device_info['version']}")

    # Добавляем информацию о платформе в кеш
    if device_info['board'] != 'unknown':
        update_board_arch_cache(device_info['board'], device_info['arch'])

    return device_info


def load_board_arch_cache():
    """Загрузка кеша архитектур плат из файла"""
    global BOARD_ARCH_CACHE, CACHE_LOADED
    if CACHE_LOADED:
        return

    try:
        if os.path.exists(BOARD_ARCH_CACHE_FILE):
            with open(BOARD_ARCH_CACHE_FILE, 'r') as f:
                BOARD_ARCH_CACHE = json.load(f)
                logger.info(f"Loaded board architecture cache with {len(BOARD_ARCH_CACHE)} entries")
        else:
            BOARD_ARCH_CACHE = {}
            logger.info("Board architecture cache file not found, starting with empty cache")
    except Exception as e:
        logger.error(f"Failed to load board architecture cache: {str(e)}")
        BOARD_ARCH_CACHE = {}

    CACHE_LOADED = True


def save_board_arch_cache():
    """Сохранение кеша архитектур плат в файл"""
    try:
        with open(BOARD_ARCH_CACHE_FILE, 'w') as f:
            json.dump(BOARD_ARCH_CACHE, f, indent=2)
        logger.info(f"Saved board architecture cache with {len(BOARD_ARCH_CACHE)} entries")
    except Exception as e:
        logger.error(f"Failed to save board architecture cache: {str(e)}")


def update_board_arch_cache(board, arch):
    """Обновление кеша архитектур плат"""
    global BOARD_ARCH_CACHE

    # Проверяем, нужно ли обновлять кеш
    if board in BOARD_ARCH_CACHE:
        if BOARD_ARCH_CACHE[board] == arch:
            return  # Значение не изменилось
        if BOARD_ARCH_CACHE[board] != 'unknown' and arch == 'unknown':
            return  # Не заменяем известное значение на unknown

    # Обновляем кеш
    BOARD_ARCH_CACHE[board] = arch
    logger.info(f"Updated cache: {board} -> {arch}")

    # Сохраняем кеш на диск
    save_board_arch_cache()


def get_arch_for_board(board, ip, username, password):
    """Получение архитектуры для платы с использованием кеша"""
    global BOARD_ARCH_CACHE

    # Загружаем кеш при первом вызове
    if not CACHE_LOADED:
        load_board_arch_cache()

    # Если плата есть в кеше, возвращаем значение
    if board in BOARD_ARCH_CACHE:
        return BOARD_ARCH_CACHE[board]
    logger.info(f"Board {board} not in cache, querying device {ip}...")

    # Получаем информацию об архитектуре через SSH
    device_info = get_device_info(ip, username, password)
    arch = device_info['arch']

    # Обновляем кеш
    update_board_arch_cache(board, arch)

    return arch


def parse_neighbor_entry(entry):
    """Парсинг записи о соседнем устройстве"""
    try:
        identity_match = re.search(r'identity="(.+?)"', entry)
        ip_match = re.search(r'address=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', entry)
        version_match = re.search(r'version="(\d+(?:\.\d+)+)', entry)
        interface_match = re.search(r'interface=(.+?)\s', entry)
        board_match = re.search(r'board="(.+?)"', entry)

        if not all([identity_match, ip_match, version_match, interface_match, board_match]):
            return None

        identity = identity_match.group(1)
        ip = ip_match.group(1)
        version = version_match.group(1)
        interface = interface_match.group(1)
        board = board_match.group(1)

        return {
            'identity': identity,
            'ip': ip,
            'version': version,
            'interface': interface,
            'board': board
        }
    except Exception as e:
        logger.error(f"Error parsing neighbor entry: {entry} | Error: {str(e)}")
        return None


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

        device = parse_neighbor_entry(entry)
        if device:
            devices.append(device)

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
    if not identity or not roles:
        return 'unknown'

    # Берем последний символ identity для определения роли
    role_char = identity[-1]

    for role_def in roles:
        if role_def.get('tag') == role_char:
            return role_def.get('role', 'unknown')
        else:
            return role_def.get('role_def', 'unknown')

    return 'unknown'


def process_main_device(group_name, group_data, global_vars, inventory):
    """Обработка главного устройства и его соседей"""
    host = group_data.get("host")
    name = group_data.get("name")

    if not host or not name:
        logger.warning(f"Skipping group {group_name} due to missing host or name")
        return inventory

    username = global_vars.get("user", "")
    password = global_vars.get("password", "")

    # Информация о главном устройстве
    device_info = get_device_info(host, username, password)

    # Добавление главного устройства в инвентарь
    group_key = group_name

    with LOCK:
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

    # Получение и обработка соседей
    neighbors = get_neighbors(host, username, password)
    if not neighbors:
        return inventory

    # Обработка соседей
    for neighbor in neighbors:
        # Получаем архитектуру для платы с использованием кеша
        arch = get_arch_for_board(
            neighbor['board'],
            neighbor['ip'],
            username,
            password
        )

        # Определение роли
        role = determine_role(neighbor['identity'], global_vars.get("roles", []))

        # Определение группы по архитектуре
        arch_group = group_key
        for arch_def in global_vars.get("architectures", []):
            if arch_def['arch'] in arch:
                arch_group = arch_def['arch_group']
                break

        # Добавление в инвентарь
        with LOCK:
            inventory['all']['children'].setdefault(arch_group, {'hosts': {}})
            inventory['all']['children'][arch_group]['hosts'][neighbor['identity']] = {
                'ansible_host': neighbor['ip'],
                'version': neighbor['version'],
                'identity': neighbor['identity'],
                'role': role,
                'architecture': arch,
                'board': neighbor['board']
            }

        logger.info(f"Added neighbor: {neighbor['ip']} | Role: {role} | Board: {neighbor['board']} | Arch: {arch}")

    return inventory


def main():
    global OUTPUT_INVENTORY, BACKUP_INVENTORY, BOARD_ARCH_CACHE_FILE, SSH_PORT, MAX_WORKERS, ENCODING

    # Загрузка основного инвентаря
    try:
        with open(INVENTORY_FILE) as f:
            main_inventory = yaml.safe_load(f)
    except Exception as e:
        logger.error(f"Failed to load inventory file: {str(e)}")
        return

    global_vars = main_inventory.get("vars", {})

    # Установка конфигурационных переменных
    OUTPUT_INVENTORY = global_vars.get('output_inventory', '/var/opt/ansible/inventory/dyn_inven.yaml')
    BACKUP_INVENTORY = global_vars.get('backup_inventory', './backup_dyn_inven.yaml')
    BOARD_ARCH_CACHE_FILE = global_vars.get('board_arch_cache_file', './mikrotik_board_arch_cache.json')
    SSH_PORT = global_vars.get('ssh_port', 22)
    MAX_WORKERS = global_vars.get('max_workers', 10)
    ENCODING = global_vars.get('encoding', 'utf-8')

    # Загрузка кеша архитектур плат
    load_board_arch_cache()

    inventory = generate_inventory_structure()

    # Подготовка списка главных устройств для обработки
    main_devices = []
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

        main_devices.append((group_name, group_data))

    # Параллельная обработка главных устройств
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(MAX_WORKERS, len(main_devices))) as executor:
        # Создаем частичную функцию с фиксированными параметрами
        process_fn = partial(
            process_main_device,
            global_vars=global_vars,
            inventory=inventory
        )

        # Запускаем обработку главных устройств
        futures = {executor.submit(process_fn, group_name, group_data): (group_name, group_data)
                   for group_name, group_data in main_devices}

        # Обработка результатов
        for future in concurrent.futures.as_completed(futures):
            group_name, group_data = futures[future]
            try:
                # Обновляем инвентарь из каждого потока
                inventory = future.result()
            except Exception as e:
                logger.error(f"Error processing main device {group_data.get('host')}: {str(e)}")

    # Сохранение кеша архитектур плат
    save_board_arch_cache()

    # Сохранение результатов инвентаризации
    try:
       # Создаем директорию, если она не существует
       os.makedirs(os.path.dirname(OUTPUT_INVENTORY), exist_ok=True)

       with open(file_path, 'w') as f:
            yaml.dump(inventory, f)
       logger.info(f"Inventory saved to {OUTPUT_INVENTORY}")
    except Exception as e:
           logger.error(f"Failed to save inventory to {OUTPUT_INVENTORY}: {str(e)}")


if __name__ == "__main__":
    main()
