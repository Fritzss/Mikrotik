#!/bin/python3

from paramiko import SSHClient, AutoAddPolicy
import re, yaml
from subprocess import run, PIPE


import os
import sys



def cd_script_path():
    # Get the directory where the script is located
    script_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
    # Change the current working directory
    os.chdir(script_dir)

cd_script_path()

encoding = 'utf-8'
inventory = './main_host.yaml'

port = 22
result = ''
com = ':put [ /ip neighbor print detail without-paging where platform="MikroTik" address~".+"]'
log = './ros.log'
logfail = './ros.err.log'


def writeLogSuccess(message,log):
                 f = open(log, 'a')
                 f.write(f'{message}\n')
                 f.close

def writeLogFail(message,log):
             f = open(log, 'a')
             f.write(f'{message}\n')
             f.close


with open(inventory) as h:
   main = yaml.safe_load(h)

vars = main["vars"]


def check(ip_address):
    """
    Ping IP address and return tuple:
    On success:
        * True
        * command output (stdout)
    On failure:
        * False
        * error output (stderr)
    """
    reply = run(['ping', '-c', '3', '-n', ip_address],
                           stdout=PIPE,
                           stderr=PIPE,
                           encoding='utf-8')
    if reply.returncode == 0:
        return True #, reply.stdout
    else:
        return False #, reply.stderr




def execcom(ip, username, port, password, command):
    try:
      client = SSHClient()
      client.load_system_host_keys()
      client.set_missing_host_key_policy(AutoAddPolicy())
      client.connect(ip, port=port, username=username, password=password,timeout=3, banner_timeout=1, auth_timeout=20)
      stdin, stdout, stderr = client.exec_command(command)
      res = stdout.read()
      return res
    except Exception as e:
      return e
    finally:
      client.close()



def exec(ser, com, log, logfail):
        for iphost in ser:
            hostname = iphost.replace('\n', '')
            if check(hostname):
               result = execcom(ip=hostname, username=user, port=port, password=password, command=com)
                 # send(result, hostname)  #if need to email
                 # sendTG(f'{hostname} {result}') #if need to TG
               writeLogSuccess(result, log) #if need to log file
            else:
                  # send(body, hostname) #if need to email
                  # sendTG(f'Fail ping {hostname}') #if need to TG
               writeLogFail(result, logfail) #if write to log file


def get_arh(host,user,password):
   com = ':put [/system resource print without-paging]'
   arh = execcom(ip=host, username=user, port=port, password=password, command=com)
   try:
     arh = arh.decode(encoding)
     board=''.join(map(str, re.findall('.*board-name:\s(.+)[\s]', arh)))
     version = ''.join(map(str, re.findall('.*version:\s(\d+|\d+\.\d+|\d+\.\d+\.\d+)[\s]', arh)))
     arh = ''.join(map(str, re.findall('.*architecture-name:\s(.+)?', arh)))
     arh = arh.strip()
     board = board.strip()
     version = version.strip()
     print(f'host {host} arh {arh} board {board} version {version}')
     return arh, board, version
   except:
     board='unknow'
     version = 'unknow'
     arh = 'unknow'
     print(f'host {host} arh {arh} board {board} version {version}')
     return arh, board, version



def get_version(host,user,password):
   com = ':put [/system resource get version ]'
   ver = execcom(ip=host, username=user, port=port, password=password, command=com)
   print(f'version {ver}')
   ver = ver.decode(encoding)
   ver = ver.split()
   ch = ver[1].strip('(').strip(')')
   ver = ver[0]
   return ver, ch



def make_inventory(group, name, host, user, password):
  inv={}
  resuorce= get_arh(host,user,password)
  inv.update({'clouds': {'hosts': {} } })
  inv.update({ group: {'hosts': {} } })
  inv[group]['hosts'].update({name: {}})
  inv[group]['hosts'][name].update({'ansible_host': host })
  inv[group]['hosts'][name].update({'version': resuorce[2] })
  inv[group]['hosts'][name].update({'identity': name  })
  inv[group]['hosts'][name].update({'role': 'root' })
  inv[group]['hosts'][name].update({'architecture': resuorce[0] })
  inv[group]['hosts'][name].update({'board': resuorce[1] })

  com = ':put [ /ip neighbor print detail without-paging where platform="MikroTik" address~".+" ]'
  result = execcom(ip=host, username=user, port=port, password=password, command=com)
  result = result.decode(encoding)
  group_ = group
  for i in re.split('\s\d{1,3}\s',result):
    if len(i) > 0:
      identity=''.join(map(str, re.findall('identity=\"(.+?)\"', i)))
      ansible_host=''.join(map(str, re.findall('address=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', i)))
      version=''.join(map(str, re.findall('version=\"(\d{1,2}|\d+\.\d{1,2}|\d+\.\d+\.\d{1,2})[\s]', i)))
      role=''.join(map(str, re.findall('identity=\"(.+?)\"', i)))
      resuorce=get_arh(ansible_host, user, password)
      board=''.join(map(str, re.findall('board=\"(.+?)\"', i)))
      interface=''.join(map(str, re.findall('interface=(.+?)\s', i)))
      print(f'host {ansible_host} role {role} int {interface}')
      for role_ in vars["roles"]:
         if role[-1] == role_["role"]:
            role = role["role"]
      for arch in vars["architectures"]:
         if arch["arch"] in resuorce[0]:
            group=arch["arch_group"]
      for interface_ in vars["exclude_interfaces"]:
         if interface_ in interface:
            continue
         inv[group]['hosts'].update({identity: {}})
         inv[group]['hosts'][identity].update({'ansible_host': ansible_host })
         inv[group]['hosts'][identity].update({'version': version })
         inv[group]['hosts'][identity].update({'identity': identity })
         inv[group]['hosts'][identity].update({'role': role })
         inv[group]['hosts'][identity].update({'architecture': resuorce[0]})
         inv[group]['hosts'][identity].update({'board': resuorce[1]})
  return inv


inventory = {'all':{}}
inventory['all'].update({'vars':{}})
inventory['all']['vars'].update({'ansible_connection': 'ansible.netcommon.network_cli'})
inventory['all']['vars'].update({'ansible_network_os': 'community.routeros.routeros'})
inventory['all']['vars'].update({'ansible_user': '{{ user }}'})
inventory['all']['vars'].update({'ansible_ssh_pass': '{{ password }}'})
inventory['all']['vars'].update({'host_key_checking': 'False'})
inventory['all'].update({'children':{}})


for key,value in main.items():
  if key != 'vars':
    inventory_ = make_inventory(group=key,
                    name=value["name"],
                    host=value["host"],
                    user=vars["user"],
                    password=vars["password"]
                     )
  inventory['all']['children'].update(inventory_)


with open('/var/opt/ansible/inventory/dyn_inven.yaml','w') as y:
   yaml.dump(inventory, y)
with open('./dyn_inven.yaml','w') as y:
   yaml.dump(inventory, y)
