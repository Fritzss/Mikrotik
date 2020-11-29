#!/bin/python3

from paramiko import SSHClient
from smtplib import SMTP_SSL
from requests import get 


ipf = '<your_ip_device_fail>'
ser = []

user = '<ROS_user>'
port = 22
result = [str]
password = '<password>'
com = '<EXAMPLE: /system identity print>'
log = '<path_logs>'
logfail = '<path_logs>'

def sendTG(bot_message):
   bot_token = '<your_bot_token>'
   bot_chatID = '<your_chatID>'
   send_text = f'https://api.telegram.org/bot{bot_token}/sendMessage?chat_id={bot_chatID}&parse_mode=Markdown&text={bot_message}'
   try:
       get(send_text)
   except:
       pass


def writeLogSuccess(message,log):
	         f = open(log, 'a')
	         f.write(f'{message}\n')
	         f.close
def writeLogFail(message,log)
             f = open(log, 'a')
             f.write(f'{message}\n')
             f.close


def send(text, sub):
    HOST = "<your_email_SMTPserver>"
    mypass = '<your_pass>'
    SUBJECT = sub
    recip = ['<your_email>']
    TO = '. '.join(recip)
    FROM = "<your_email>"
    text = text
    BODY = "\r\n".join((
        "From: %s" % FROM,
        "To: %s" % TO,
        "Subject: %s" % SUBJECT,
        "",
        text
    ))
    try:
       server = SMTP_SSL(HOST, port=465)
       server.login(user=FROM, password=mypass)
	   server.sendmail(FROM, [TO], BODY)
       server.quit()
    except:
	    pass

with open(ipf) as hip:
    for l in hip:
        ser.append(l)

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
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(ip, port=port, username=username, password=password,timeout=3, banner_timeout=1, auth_timeout=5)
        stdin, stdout, stderr = client.exec_command(command)
        res = stdout.read()
        return res
    except Exception as e:
        res = 'fail ' + str(e)
        return res
    finally:
        client.close()


def exec(ser, com, log, logfail):
        for iphost in ser:
            hostname = iphost.replace('\n', '')
			if check(hostname):
                  result = execcom(ip=hostname, username=user, port=port, password=password, command=com)
                  send(result, hostname)  #if need to email
                  sendTG(f'{hostname} {result}') #if need to TG
                  writeLogSuccess(result, log) #if need to log file				  
            else:
                  send(body, hostname) #if need to email
                  sendTG(f'Fail ping {hostname}') #if need to TG
				  writeLogFail(result, logfail) #if write to log file 
			
if __name__ = '__main__':
       exec(ser, com, log, logfail)
