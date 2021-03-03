# Install Ansible

```bash
sudo apt update                                                             
sudo apt upgrade -y                                                         
sudo apt install software-properties-common                                 
sudo apt-add-repository --yes --update ppa:ansible/ansible                  
sudo apt install ansible -y
```

## Generate ssh key
``ssh-keygen``

## Copy ssh key to clients
``ssh-copy-id <client-name>``

