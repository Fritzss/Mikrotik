# MikroTik Ansible Inventory Generator

## Конфигурация через main_hosts.yaml

Все настройки скрипта теперь задаются в файле `main_hosts.yaml`:

### Основные устройства
```yaml
office1:
  name: core1        # Имя устройства в инвентаре
  host: 192.168.1.1  # IP-адрес основного устройства
vars:
  # Обязательные параметры
  user: admin                 # SSH-логин для всех устройств
  password: superpassword     # SSH-пароль для всех устройств
  
  # Настройки скрипта
  output_inventory: '/путь/к/inventory.yaml'  # Основной файл инвентаря
  board_arch_cache_file: './кеш_архитектур.json' # Файл кеша архитектур
  ssh_port: 22                # Порт SSH подключения
  max_workers: 10             # Максимальное количество потоков
  encoding: 'utf-8'           # Кодировка для SSH
  
  # Настройки ролей
  roles:
    - role: root              # Название роли
      tag: r                  # Идентификатор роли (последний символ в identity)
  
  # Группировка по архитектуре
  architectures:
    - arch: "arm"             # Шаблон архитектуры
      arch_group: arm_devices # Группа в Ansible, если шаблон не задан, устройство добавляется в группу главного устройства
        
  # Исключаемые интерфейсы
  exclude_interfaces:
    - <interface name>                    # Игнорировать устройства на этих интерфейсах, поддерживаются wildcards


