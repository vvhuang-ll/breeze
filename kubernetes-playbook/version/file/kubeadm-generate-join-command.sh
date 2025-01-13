#!/bin/bash
kubeadm token create --print-join-command > /opt/wise2c/tmp/kubernetes/worker-join-command.sh
chmod +x /opt/wise2c/tmp/kubernetes/worker-join-command.sh
