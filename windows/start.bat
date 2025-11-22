wsl --update
wsl --set-default-version 2

copy .wslconfig %USERPROFILE%\.wslconfig

wsl --install -d Ubuntu-24.04

wsl -d Ubuntu-24.04 -- bash -c "sudo apt update && sudo apt upgrade -y"
wsl --export Ubuntu-24.04 master.tar
wsl --unregister Ubuntu-24.04

wsl --import kube-master %USERPROFILE%\wsl\kube-master master.tar
wsl --set-default kube-master

wsl --import kube-worker1 %USERPROFILE%\wsl\kube-worker1 master.tar
wsl --import kube-worker2 %USERPROFILE%\wsl\kube-worker2 master.tar

del master.tar

wsl -d kube-master -- bash -c "echo -e '[boot]\nsystemd=true\n\n[network]\nhostname=kube-master\ngenerateHosts=false\ngenerateResolvConf=false\n\n[user]\ndefault=root\n\n[automount]\nenabled=false\n\n[interop]\nenabled=false\nappendWindowsPath=false' | sudo tee /etc/wsl.conf"
wsl -d kube-worker1 -- bash -c "echo -e '[boot]\nsystemd=true\n\n[network]\nhostname=kube-worker1\ngenerateHosts=false\ngenerateResolvConf=false\n\n[user]\ndefault=root\n\n[automount]\nenabled=false\n\n[interop]\nenabled=false\nappendWindowsPath=false' | sudo tee /etc/wsl.conf"
wsl -d kube-worker2 -- bash -c "echo -e '[boot]\nsystemd=true\n\n[network]\nhostname=kube-worker2\ngenerateHosts=false\ngenerateResolvConf=false\n\n[user]\ndefault=root\n\n[automount]\nenabled=false\n\n[interop]\nenabled=false\nappendWindowsPath=false' | sudo tee /etc/wsl.conf"
wsl --shutdown
