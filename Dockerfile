FROM busybox:latest

WORKDIR /workspace

COPY callback_plugins /workspace/callback_plugins
COPY crio-playbook /workspace/crio-playbook
COPY etcd-playbook /workspace/etcd-playbook
COPY kubernetes-playbook /workspace/kubernetes-playbook
COPY harbor-playbook /workspace/harbor-playbook
COPY loadbalancer-playbook /workspace/loadbalancer-playbook
COPY components_order.conf /workspace